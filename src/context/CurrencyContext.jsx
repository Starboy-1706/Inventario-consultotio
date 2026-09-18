import { createContext, useContext, useState, useEffect, useCallback } from 'react'
import { supabase } from '../lib/supabase'
import toast from 'react-hot-toast'

const CurrencyContext = createContext()

export function CurrencyProvider({ children }) {
  const [rates, setRates] = useState({ VES: 65, COP: 4200 })
  const [taxes, setTaxes] = useState([])
  const [activeCur, setActiveCur] = useState('USD') // USD | VES | COP
  const [loadingRates, setLoadingRates] = useState(false)

  const fetchBCVReal = async () => {
    try {
      const res = await fetch('https://ve.dolarapi.com/v1/dolares/oficial')
      if (res.ok) {
        const data = await res.json()
        if (data?.promedio) return Number(data.promedio)
      }
    } catch {}
    return null
  }

  const fetchCOPReal = async () => {
    try {
      const res = await fetch('https://co.dolarapi.com/v1/dolares/oficial')
      if (res.ok) {
        const data = await res.json()
        if (data?.promedio) return Number(data.promedio)
      }
    } catch {}
    return null
  }

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
        await supabase.from('tasas_cambio').upsert({ moneda: 'COP', tasa: copRate, fuente: 'TRM Colombia' })
      }

      setRates(prev => ({ ...prev, ...updated }))
      if (notify) toast.success(`Tasas actualizadas: BCV Bs. ${updated.VES || rates.VES} | COP $${updated.COP || rates.COP}`)
    } catch {
      if (notify) toast.error('Error al sincronizar tasas oficiales')
    } finally {
      setLoadingRates(false)
    }
  }, [rates])

  const loadData = useCallback(async () => {
    const [tRes, iRes] = await Promise.all([
      supabase.from('tasas_cambio').select('*'),
      supabase.from('impuestos').select('*').eq('activo', true)
    ])

    const r = { VES: 65, COP: 4200 }
    if (tRes.data?.length > 0) {
      tRes.data.forEach(t => {
        if (t.moneda === 'VES') r.VES = Number(t.tasa)
        if (t.moneda === 'COP') r.COP = Number(t.tasa)
      })
      setRates(r)
    }
    if (iRes.data) setTaxes(iRes.data)
    syncOfficialRates(false)
  }, [syncOfficialRates])

  useEffect(() => { loadData() }, [loadData])

  return (
    <CurrencyContext.Provider value={{ rates, setRates, taxes, activeCur, setActiveCur, syncOfficialRates, loadingRates, loadData }}>
      {children}
    </CurrencyContext.Provider>
  )
}

export const useCurrency = () => useContext(CurrencyContext)
