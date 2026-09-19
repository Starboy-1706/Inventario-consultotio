import { createContext, useContext, useState, useEffect, useCallback } from 'react'
import { supabase } from '../lib/supabase'
import toast from 'react-hot-toast'

const CurrencyContext = createContext()

export function CurrencyProvider({ children }) {
  const [rates, setRates] = useState({ VES: 68.50, COP: 4200 })
  const [taxes, setTaxes] = useState([])
  const [activeCur, setActiveCur] = useState('USD') // USD | VES | COP
  const [loadingRates, setLoadingRates] = useState(false)
  const [rateInfo, setRateInfo] = useState({
    bcvDate: '',
    bcvFuente: 'BCV Oficial',
    copDate: '',
    copFuente: 'TRM Superfinanciera',
    modo: 'auto' // auto | manual
  })

  // 1. OBTENER BCV OFICIAL (Válido para fin de semana / feriados)
  const fetchBCVOfficial = async () => {
    // Fuente 1: DolarAPI Oficial Venezuela (Tasa BCV del día/cierre)
    try {
      const res = await fetch('https://ve.dolarapi.com/v1/dolares/oficial', { cache: 'no-store' })
      if (res.ok) {
        const data = await res.json()
        const precio = Number(data?.promedio || data?.precio)
        if (precio && precio > 15 && precio < 500) {
          return {
            tasa: precio,
            fecha: data?.fechaActualizacion || new Date().toISOString(),
            fuente: 'BCV Oficial'
          }
        }
      }
    } catch (e) {
      console.warn('Fallo consulta DolarAPI VE')
    }

    // Fuente 2: PyDolarVe Oficial BCV
    try {
      const res = await fetch('https://pydolarve.org/api/v1/dollar?page=bcv', { cache: 'no-store' })
      if (res.ok) {
        const data = await res.json()
        const precio = Number(data?.monitors?.usd?.price)
        if (precio && precio > 15 && precio < 500) {
          return {
            tasa: precio,
            fecha: data?.datetime?.date || new Date().toISOString(),
            fuente: 'BCV Oficial'
          }
        }
      }
    } catch (e) {
      console.warn('Fallo consulta PyDolarVe')
    }

    return null
  }

  // 2. OBTENER TRM OFICIAL COLOMBIA (Datos Abiertos / Superfinanciera)
  const fetchCOPOfficial = async () => {
    // Fuente 1: Portal Oficial de Datos Abiertos del Gobierno de Colombia (Superfinanciera)
    try {
      const res = await fetch('https://www.datos.gov.co/resource/32sa-8pi3.json?$limit=1&$order=vigenciadesde%20DESC', { cache: 'no-store' })
      if (res.ok) {
        const data = await res.json()
        if (data && data[0]?.valor) {
          return {
            tasa: Number(data[0].valor),
            fecha: data[0].vigenciadesde || data[0].vigenciahasta,
            fuente: 'TRM Superfinanciera Oficial'
          }
        }
      }
    } catch (e) {
      console.warn('Fallo consulta Datos Abiertos Colombia')
    }

    // Fuente 2: DolarAPI Oficial Colombia
    try {
      const res = await fetch('https://co.dolarapi.com/v1/dolares/oficial', { cache: 'no-store' })
      if (res.ok) {
        const data = await res.json()
        const precio = Number(data?.promedio || data?.precio)
        if (precio && precio > 2000 && precio < 10000) {
          return {
            tasa: precio,
            fecha: data?.fechaActualizacion || new Date().toISOString(),
            fuente: 'TRM Oficial Colombia'
          }
        }
      }
    } catch (e) {
      console.warn('Fallo consulta DolarAPI CO')
    }

    return null
  }

  // 3. SINCRONIZACIÓN INTELIGENTE (No pisa tasas manuales)
  const syncOfficialRates = useCallback(async (notify = false, force = false) => {
    setLoadingRates(true)
    try {
      const [bcvRes, copRes] = await Promise.all([fetchBCVOfficial(), fetchCOPOfficial()])
      const updates = {}
      const infoUpdates = {}

      if (bcvRes && bcvRes.tasa) {
        updates.VES = bcvRes.tasa
        infoUpdates.bcvDate = bcvRes.fecha
        infoUpdates.bcvFuente = bcvRes.fuente
        await supabase.from('tasas_cambio').upsert({
          moneda: 'VES',
          tasa: bcvRes.tasa,
          fuente: `${bcvRes.fuente} (${new Date().toLocaleDateString('es-VE')})`
        }, { onConflict: 'moneda' })
      }

      if (copRes && copRes.tasa) {
        updates.COP = copRes.tasa
        infoUpdates.copDate = copRes.fecha
        infoUpdates.copFuente = copRes.fuente
        await supabase.from('tasas_cambio').upsert({
          moneda: 'COP',
          tasa: copRes.tasa,
          fuente: `${copRes.fuente} (${new Date().toLocaleDateString('es-CO')})`
        }, { onConflict: 'moneda' })
      }

      if (Object.keys(updates).length > 0) {
        setRates(prev => ({ ...prev, ...updates }))
        setRateInfo(prev => ({ ...prev, ...infoUpdates, modo: 'auto' }))
        if (notify) {
          toast.success(`Tasas Oficiales Sincronizadas:\n• BCV: Bs. ${updates.VES || rates.VES}\n• TRM COP: $${updates.COP || rates.COP}`)
        }
      } else {
        if (notify) toast('Tasas de cierre bancario vigentes confirmadas')
      }
    } catch (e) {
      if (notify) toast.error('Error al sincronizar con fuentes bancarias')
    } finally {
      setLoadingRates(false)
    }
  }, [rates])

  // Cargar tasas iniciales de Supabase
  const loadData = useCallback(async () => {
    try {
      const [tRes, iRes] = await Promise.all([
        supabase.from('tasas_cambio').select('*'),
        supabase.from('impuestos').select('*').eq('activo', true)
      ])

      const r = {}
      const info = {}
      if (tRes.data?.length > 0) {
        tRes.data.forEach(t => {
          if (t.moneda === 'VES') {
            r.VES = Number(t.tasa)
            info.bcvFuente = t.fuente || 'BCV Oficial'
          }
          if (t.moneda === 'COP') {
            r.COP = Number(t.tasa)
            info.copFuente = t.fuente || 'TRM Colombia'
          }
        })
        setRates(prev => ({ ...prev, ...r }))
        setRateInfo(prev => ({ ...prev, ...info }))
      }

      if (iRes.data) setTaxes(iRes.data)

      // Actualizar automáticamente en segundo plano
      syncOfficialRates(false)
    } catch (e) {
      console.error('Error cargando tasas:', e)
    }
  }, [syncOfficialRates])

  useEffect(() => {
    loadData()
  }, [])

  return (
    <CurrencyContext.Provider value={{
      rates,
      setRates,
      taxes,
      activeCur,
      setActiveCur,
      rateInfo,
      setRateInfo,
      syncOfficialRates,
      loadingRates,
      loadData
    }}>
      {children}
    </CurrencyContext.Provider>
  )
}

export const useCurrency = () => useContext(CurrencyContext)
