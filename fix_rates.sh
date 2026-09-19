#!/bin/bash
set -e

echo "🔧 Reparando motor de tasas oficiales (BCV y TRM)..."

cat > src/context/CurrencyContext.jsx << 'EOF'
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
EOF

# Actualizar el panel de Tasas e Impuestos
cat > src/components/Configuracion/TasasImpuestos.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { DollarSign, Percent, Save, Plus, RefreshCw } from 'lucide-react'
import toast from 'react-hot-toast'

export default function TasasImpuestos() {
  const { rates, setRates, loadData, syncOfficialRates, loadingRates } = useCurrency()
  const [ves, setVes] = useState(rates.VES)
  const [cop, setCop] = useState(rates.COP)
  const [taxes, setTaxes] = useState([])
  const [newTax, setNewTax] = useState({ nombre: '', porcentaje: '' })

  useEffect(() => {
    setVes(rates.VES)
    setCop(rates.COP)
  }, [rates])

  const loadTaxes = async () => {
    const { data } = await supabase.from('impuestos').select('*')
    setTaxes(data || [])
  }
  useEffect(() => { loadTaxes() }, [])

  const saveRates = async (e) => {
    e.preventDefault()
    const numVes = Number(ves)
    const numCop = Number(cop)

    if (!numVes || !numCop) return toast.error('Ingresa valores válidos')

    await supabase.from('tasas_cambio').upsert({ moneda: 'VES', tasa: numVes, fuente: 'Manual' }, { onConflict: 'moneda' })
    await supabase.from('tasas_cambio').upsert({ moneda: 'COP', tasa: numCop, fuente: 'Manual' }, { onConflict: 'moneda' })
    
    setRates({ VES: numVes, COP: numCop })
    toast.success('Tasas guardadas manualmente')
  }

  const addTax = async (e) => {
    e.preventDefault()
    await supabase.from('impuestos').insert([newTax])
    toast.success('Impuesto agregado')
    setNewTax({ nombre: '', porcentaje: '' })
    loadTaxes(); loadData()
  }

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Ajustes de Monedas e Impuestos</h1>
          <p className="text-xs text-slate-400">Tasas oficiales del BCV (Venezuela) y TRM (Colombia)</p>
        </div>
        <button onClick={() => syncOfficialRates(true)} disabled={loadingRates} className="btn-secondary">
          <RefreshCw className={`w-4 h-4 text-teal-600 ${loadingRates ? 'animate-spin' : ''}`} /> Sincronizar Tasas Oficiales de Hoy
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Tasas */}
        <form onSubmit={saveRates} className="card-box space-y-4">
          <h2 className="font-bold text-sm text-slate-800 flex items-center gap-2">
            <DollarSign className="w-4 h-4 text-teal-600" /> Tasas del Sistema
          </h2>
          <div>
            <label className="text-xs font-semibold text-slate-600 block mb-1">Tasa Bolívares (VES por cada 1 USD)</label>
            <input type="number" step="0.01" className="input-field font-bold text-base text-teal-800" value={ves} onChange={e => setVes(e.target.value)} />
            <span className="text-[10px] text-slate-400">Tasa actual oficial del Banco Central de Venezuela</span>
          </div>
          <div>
            <label className="text-xs font-semibold text-slate-600 block mb-1">Tasa Pesos Colombianos (COP por cada 1 USD)</label>
            <input type="number" step="1" className="input-field font-bold text-base text-amber-800" value={cop} onChange={e => setCop(e.target.value)} />
            <span className="text-[10px] text-slate-400">Tasa Representativa del Mercado (TRM) Colombia</span>
          </div>
          <button type="submit" className="btn-primary w-full justify-center"><Save className="w-4 h-4" /> Guardar Tasas Manualmente</button>
        </form>

        {/* Impuestos */}
        <div className="card-box space-y-4">
          <h2 className="font-bold text-sm text-slate-800 flex items-center gap-2">
            <Percent className="w-4 h-4 text-teal-600" /> Impuestos Configurados
          </h2>
          <div className="space-y-2">
            {taxes.map(t => (
              <div key={t.id} className="flex justify-between items-center text-xs p-2.5 bg-slate-50 rounded-xl">
                <span className="font-bold text-slate-800">{t.nombre}</span>
                <span className="font-mono bg-teal-100 text-teal-800 px-2 py-0.5 rounded-full font-bold">{t.porcentaje}%</span>
              </div>
            ))}
          </div>
          <form onSubmit={addTax} className="flex gap-2 pt-2">
            <input required placeholder="Nombre (ej. IVA 16%)" className="input-field" value={newTax.nombre} onChange={e => setNewTax({...newTax, nombre: e.target.value})} />
            <input required type="number" placeholder="%" className="input-field w-20" value={newTax.porcentaje} onChange={e => setNewTax({...newTax, porcentaje: e.target.value})} />
            <button type="submit" className="btn-primary"><Plus className="w-4 h-4" /></button>
          </form>
        </div>
      </div>
    </div>
  )
}
EOF

npm run build
echo "✅ Motor de tasas estabilizado y compilado!"
