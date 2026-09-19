import { createContext, useContext, useState, useEffect, useCallback } from 'react'
import { supabase } from '../lib/supabase'
import toast from 'react-hot-toast'

const CurrencyContext = createContext()

export function CurrencyProvider({ children }) {
  const [rates, setRates] = useState({ VES: 68.50, COP: 4200 })
  const [taxes, setTaxes] = useState([])
  const [activeCur, setActiveCur] = useState('USD') // USD | VES | COP
  const [loadingRates, setLoadingRates] = useState(false)
  const [lastUpdate, setLastUpdate] = useState('')

  // 1. Obtener tasas desde múltiples capas (Servidor Vercel -> DolarAPI -> Respaldo)
  const fetchLiveRates = async () => {
    // Intento 1: API Serverless en Vercel (/api/rates)
    try {
      const res = await fetch('/api/rates')
      if (res.ok) {
        const data = await res.json()
        if (data.VES && data.COP) {
          return {
            VES: Number(data.VES),
            COP: Number(data.COP),
            fecha: data.bcvDate || new Date().toISOString(),
            fuente: 'BCV Oficial (Servidor)'
          }
        }
      }
    } catch (e) {
      // Ignorar si estamos en local dev y la ruta /api no está montada por Vercel CLI
    }

    // Intento 2: DolarAPI Venezuela Directo
    let ves = null
    let cop = null

    try {
      const res = await fetch('https://ve.dolarapi.com/v1/dolares/oficial')
      if (res.ok) {
        const d = await res.json()
        const p = Number(d.promedio || d.precio)
        if (p > 10 && p < 1000) ves = p
      }
    } catch (e) {}

    // Intento 3: PyDolarVe Directo
    if (!ves) {
      try {
        const res = await fetch('https://pydolarve.org/api/v1/dollar?page=bcv')
        if (res.ok) {
          const d = await res.json()
          const p = Number(d?.monitors?.usd?.price)
          if (p > 10 && p < 1000) ves = p
        }
      } catch (e) {}
    }

    // TRM Colombia Directo
    try {
      const res = await fetch('https://co.dolarapi.com/v1/dolares/oficial')
      if (res.ok) {
        const d = await res.json()
        const p = Number(d.promedio || d.precio)
        if (p > 2000 && p < 10000) cop = p
      }
    } catch (e) {}

    if (!cop) {
      try {
        const res = await fetch('https://open.er-api.com/v6/latest/USD')
        if (res.ok) {
          const d = await res.json()
          if (d?.rates?.COP) cop = Number(d.rates.COP)
        }
      } catch (e) {}
    }

    if (ves || cop) {
      return {
        VES: ves,
        COP: cop,
        fecha: new Date().toISOString(),
        fuente: 'BCV Oficial Directo'
      }
    }

    return null
  }

  // 2. Sincronizar y guardar en Supabase
  const syncOfficialRates = useCallback(async (notify = false) => {
    setLoadingRates(true)
    try {
      const result = await fetchLiveRates()
      const updates = {}

      if (result?.VES) {
        updates.VES = result.VES
        await supabase.from('tasas_cambio').upsert(
          { moneda: 'VES', tasa: result.VES, fuente: 'BCV Oficial' },
          { onConflict: 'moneda' }
        )
      }

      if (result?.COP) {
        updates.COP = result.COP
        await supabase.from('tasas_cambio').upsert(
          { moneda: 'COP', tasa: result.COP, fuente: 'TRM Colombia' },
          { onConflict: 'moneda' }
        )
      }

      if (Object.keys(updates).length > 0) {
        setRates(prev => ({ ...prev, ...updates }))
        setLastUpdate(new Date().toLocaleTimeString('es-VE'))
        if (notify) {
          toast.success(`Tasas Oficiales Actualizadas:\n• BCV: Bs. ${updates.VES || rates.VES}\n• COP: $${updates.COP || rates.COP}`)
        }
      } else {
        if (notify) toast('Tasas oficiales vigentes verificadas')
      }
    } catch (e) {
      if (notify) toast.error('Error sincronizando tasas oficiales')
    } finally {
      setLoadingRates(false)
    }
  }, [rates])

  // 3. Cargar datos iniciales
  const loadData = useCallback(async () => {
    try {
      const [tRes, iRes] = await Promise.all([
        supabase.from('tasas_cambio').select('*'),
        supabase.from('impuestos').select('*').eq('activo', true)
      ])

      const r = {}
      if (tRes.data?.length > 0) {
        tRes.data.forEach(t => {
          if (t.moneda === 'VES') r.VES = Number(t.tasa)
          if (t.moneda === 'COP') r.COP = Number(t.tasa)
        })
        setRates(prev => ({ ...prev, ...r }))
      }

      if (iRes.data) setTaxes(iRes.data)

      // Consultar tasas oficiales de hoy en segundo plano
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
      syncOfficialRates,
      loadingRates,
      lastUpdate,
      loadData
    }}>
      {children}
    </CurrencyContext.Provider>
  )
}

export const useCurrency = () => useContext(CurrencyContext)
