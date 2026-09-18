import { createContext, useContext, useState, useEffect, useCallback } from 'react'
import { supabase } from '../lib/supabase'
import toast from 'react-hot-toast'

const CurrencyContext = createContext()

export function CurrencyProvider({ children }) {
  const [rates, setRates] = useState({ VES: 0, COP: 0 })
  const [taxes, setTaxes] = useState([])
  const [activeCur, setActiveCur] = useState('USD') // USD | VES | COP
  const [loadingRates, setLoadingRates] = useState(false)
  const [lastSync, setLastSync] = useState(null)

  // 1. Obtener BCV Oficial en Tiempo Real
  const fetchBCVReal = async () => {
    try {
      const res = await fetch('https://ve.dolarapi.com/v1/dolares/oficial')
      if (res.ok) {
        const data = await res.json()
        if (data?.promedio) return Number(data.promedio)
      }
    } catch (e) {
      console.warn('Fallo DolarAPI VE, intentando respaldo...', e)
    }

    try {
      const res = await fetch('https://pydolarve.org/api/v1/dollar?page=bcv')
      if (res.ok) {
        const data = await res.json()
        if (data?.monitors?.usd?.price) return Number(data.monitors.usd.price)
      }
    } catch (e) {
      console.warn('Fallo PyDolarVe', e)
    }
    return null
  }

  // 2. Obtener COP Oficial (TRM Colombia) en Tiempo Real
  const fetchCOPReal = async () => {
    try {
      const res = await fetch('https://co.dolarapi.com/v1/dolares/oficial')
      if (res.ok) {
        const data = await res.json()
        if (data?.promedio) return Number(data.promedio)
      }
    } catch (e) {
      console.warn('Fallo DolarAPI CO, intentando respaldo...', e)
    }

    try {
      const res = await fetch('https://open.er-api.com/v6/latest/USD')
      if (res.ok) {
        const data = await res.json()
        if (data?.rates?.COP) return Number(data.rates.COP)
      }
    } catch (e) {
      console.warn('Fallo OpenER API', e)
    }
    return null
  }

  // 3. Sincronizar ambas tasas y guardar en Supabase
  const syncOfficialRates = useCallback(async (notify = false) => {
    setLoadingRates(true)
    try {
      const [vesRate, copRate] = await Promise.all([fetchBCVReal(), fetchCOPReal()])
      const updated = {}

      if (vesRate && vesRate > 0) {
        updated.VES = vesRate
        await supabase.from('tasas_cambio').upsert({ moneda: 'VES', tasa: vesRate, fuente: 'BCV Oficial' })
      }

      if (copRate && copRate > 0) {
        updated.COP = copRate
        await supabase.from('tasas_cambio').upsert({ moneda: 'COP', tasa: copRate, fuente: 'TRM Colombia Oficial' })
      }

      setRates(prev => ({ ...prev, ...updated }))
      setLastSync(new Date())

      if (notify) {
        toast.success(`Tasas Oficiales Actualizadas:\nBCV: Bs. ${updated.VES || rates.VES} | COP: $${updated.COP || rates.COP}`)
      }
    } catch (err) {
      console.error(err)
      if (notify) toast.error('Error al sincronizar tasas oficiales')
    } finally {
      setLoadingRates(false)
    }
  }, [rates])

  // Cargar datos iniciales
  const loadInitialData = useCallback(async () => {
    // Cargar de base de datos primero
    const [tRes, iRes] = await Promise.all([
      supabase.from('tasas_cambio').select('*'),
      supabase.from('impuestos').select('*').eq('activo', true)
    ])

    const currentRates = { VES: 65, COP: 4200 }
    if (tRes.data && tRes.data.length > 0) {
      tRes.data.forEach(t => {
        if (t.moneda === 'VES') currentRates.VES = Number(t.tasa)
        if (t.moneda === 'COP') currentRates.COP = Number(t.tasa)
      })
      setRates(currentRates)
    }
    if (iRes.data) setTaxes(iRes.data)

    // Auto-sincronizar con APIs oficiales en vivo al arrancar
    syncOfficialRates(false)
  }, [syncOfficialRates])

  useEffect(() => {
    loadInitialData()
  }, [])

  return (
    <CurrencyContext.Provider value={{
      rates,
      setRates,
      taxes,
      activeCur,
      setActiveCur,
      loadingRates,
      lastSync,
      syncOfficialRates,
      loadInitialData
    }}>
      {children}
    </CurrencyContext.Provider>
  )
}

export const useCurrency = () => useContext(CurrencyContext)
