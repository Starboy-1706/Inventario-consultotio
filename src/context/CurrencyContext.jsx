import { createContext, useContext, useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import toast from 'react-hot-toast'

const CurrencyContext = createContext()

export function CurrencyProvider({ children }) {
  const [rates, setRates] = useState({ VES: 65, COP: 4200 })
  const [taxes, setTaxes] = useState([])
  const [activeCur, setActiveCur] = useState('USD') // USD, VES, COP

  const loadData = async () => {
    const [tRes, iRes] = await Promise.all([
      supabase.from('tasas_cambio').select('*'),
      supabase.from('impuestos').select('*').eq('activo', true)
    ])

    if (tRes.data) {
      const nr = { ...rates }
      tRes.data.forEach(t => {
        if (t.moneda === 'VES') nr.VES = Number(t.tasa)
        if (t.moneda === 'COP') nr.COP = Number(t.tasa)
      })
      setRates(nr)
    }
    if (iRes.data) setTaxes(iRes.data)
  }

  const syncBCV = async () => {
    try {
      const res = await fetch('https://pydolarve.org/api/v1/dollar?page=bcv')
      const json = await res.json()
      if (json?.monitors?.usd?.price) {
        const val = Number(json.monitors.usd.price)
        await supabase.from('tasas_cambio').upsert({ moneda: 'VES', tasa: val, fuente: 'BCV Oficial' })
        setRates(prev => ({ ...prev, VES: val }))
        toast.success(`Tasa BCV actualizada: Bs. ${val}`)
      }
    } catch {
      toast.error('No se pudo conectar a la API del BCV')
    }
  }

  useEffect(() => { loadData() }, [])

  return (
    <CurrencyContext.Provider value={{ rates, setRates, taxes, activeCur, setActiveCur, syncBCV, loadData }}>
      {children}
    </CurrencyContext.Provider>
  )
}

export const useCurrency = () => useContext(CurrencyContext)
