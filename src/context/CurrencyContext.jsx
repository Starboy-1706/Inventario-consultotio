import { createContext, useContext, useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import toast from 'react-hot-toast'

const CurrencyContext = createContext()

export function CurrencyProvider({ children }) {
  const [rates, setRates] = useState({ VES: 65, COP: 4200 })
  const [taxes, setTaxes] = useState([])

  const loadData = async () => {
    const [tRes, iRes] = await Promise.all([
      supabase.from('tasas_cambio').select('*'),
      supabase.from('impuestos').select('*').eq('activo', true)
    ])
    
    if (tRes.data) {
      const nr = { ...rates }
      tRes.data.forEach(t => { if (t.moneda === 'VES') nr.VES = Number(t.tasa); if (t.moneda === 'COP') nr.COP = Number(t.tasa) })
      setRates(nr)
    }
    if (iRes.data) setTaxes(iRes.data)
  }

  const fetchBCV = async () => {
    try {
      const res = await fetch('https://pydolarve.org/api/v1/dollar?page=bcv')
      const data = await res.json()
      if (data?.monitors?.usd?.price) {
        const p = data.monitors.usd.price
        await supabase.from('tasas_cambio').upsert({ moneda: 'VES', tasa: p, fuente: 'BCV Oficial' })
        setRates(prev => ({ ...prev, VES: p }))
        toast.success(`Tasa BCV actualizada: Bs. ${p}`)
      }
    } catch {
      toast.error('Error al consultar BCV oficial')
    }
  }

  useEffect(() => { loadData() }, [])

  return (
    <CurrencyContext.Provider value={{ rates, setRates, taxes, fetchBCV, loadData }}>
      {children}
    </CurrencyContext.Provider>
  )
}
export const useCurrency = () => useContext(CurrencyContext)
