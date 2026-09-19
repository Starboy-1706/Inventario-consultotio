import { createContext, useContext, useState, useEffect, useCallback } from 'react'
import { supabase } from '../lib/supabase'
import toast from 'react-hot-toast'

const CurrencyContext = createContext()

export function CurrencyProvider({ children }) {
  // Valores por defecto seguros si no hay internet o falla la API
  const [rates, setRates] = useState({ VES: 68.50, COP: 4200 })
  const [taxes, setTaxes] = useState([])
  const [activeCur, setActiveCur] = useState('USD') // USD | VES | COP
  const [loadingRates, setLoadingRates] = useState(false)

  // 1. Obtener BCV Oficial con múltiples respaldos y validación
  const fetchBCV = async () => {
    try {
      const res = await fetch('https://ve.dolarapi.com/v1/dolares/oficial')
      if (res.ok) {
        const data = await res.json()
        const val = Number(data?.promedio || data?.precio)
        if (val && val > 10 && val < 500) return val // Validación de rango real
      }
    } catch {}

    try {
      const res = await fetch('https://pydolarve.org/api/v1/dollar?page=bcv')
      if (res.ok) {
        const data = await res.json()
        const val = Number(data?.monitors?.usd?.price)
        if (val && val > 10 && val < 500) return val
      }
    } catch {}

    return null
  }

  // 2. Obtener TRM Oficial de Colombia con validación
  const fetchCOP = async () => {
    try {
      const res = await fetch('https://co.dolarapi.com/v1/dolares/oficial')
      if (res.ok) {
        const data = await res.json()
        const val = Number(data?.promedio || data?.precio)
        if (val && val > 2000 && val < 10000) return val
      }
    } catch {}

    try {
      const res = await fetch('https://open.er-api.com/v6/latest/USD')
      if (res.ok) {
        const data = await res.json()
        const val = Number(data?.rates?.COP)
        if (val && val > 2000 && val < 10000) return val
      }
    } catch {}

    return null
  }

  // 3. Sincronización limpia sin bucles
  const syncOfficialRates = useCallback(async (notify = false) => {
    setLoadingRates(true)
    try {
      const [vesVal, copVal] = await Promise.all([fetchBCV(), fetchCOP()])
      const updates = {}

      if (vesVal) {
        updates.VES = vesVal
        await supabase.from('tasas_cambio').upsert({ moneda: 'VES', tasa: vesVal, fuente: 'BCV Oficial' }, { onConflict: 'moneda' })
      }

      if (copVal) {
        updates.COP = copVal
        await supabase.from('tasas_cambio').upsert({ moneda: 'COP', tasa: copVal, fuente: 'TRM Colombia' }, { onConflict: 'moneda' })
      }

      if (Object.keys(updates).length > 0) {
        setRates(prev => ({ ...prev, ...updates }))
        if (notify) {
          toast.success(`Tasas de hoy:\nBCV: Bs. ${updates.VES || rates.VES} | COP: $${updates.COP || rates.COP}`)
        }
      } else {
        if (notify) toast('Tasas verificadas con el servidor')
      }
    } catch (e) {
      if (notify) toast.error('Error al consultar tasas en vivo')
    } finally {
      setLoadingRates(false)
    }
  }, [])

  // Cargar datos de Supabase SOLO 1 vez al iniciar
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

      // Actualizar en segundo plano sin reiniciar el estado
      syncOfficialRates(false)
    } catch (e) {
      console.error('Error cargando tasas:', e)
    }
  }, [syncOfficialRates])

  useEffect(() => {
    loadData()
  }, []) // Solo se ejecuta 1 vez al cargar la app

  return (
    <CurrencyContext.Provider value={{
      rates,
      setRates,
      taxes,
      activeCur,
      setActiveCur,
      syncOfficialRates,
      loadingRates,
      loadData
    }}>
      {children}
    </CurrencyContext.Provider>
  )
}

export const useCurrency = () => useContext(CurrencyContext)
