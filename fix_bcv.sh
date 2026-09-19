#!/bin/bash
set -e

echo "🏦 Configurando conexión oficial y robusta para BCV y TRM..."

# 1. Crear API Serverless para Vercel (Sin problemas de CORS)
mkdir -p api

cat > api/rates.js << 'EOF'
export default async function handler(req, res) {
  // Permitir CORS por si se consulta externamente
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Methods', 'GET')
  res.setHeader('Cache-Control', 's-maxage=300, stale-while-revalidate')

  let ves = null
  let cop = null
  let bcvDate = new Date().toISOString()
  let copDate = new Date().toISOString()

  // 1. Obtener BCV Oficial
  try {
    const r = await fetch('https://ve.dolarapi.com/v1/dolares/oficial', { headers: { 'User-Agent': 'Mozilla/5.0' } })
    if (r.ok) {
      const d = await r.json()
      const val = Number(d.promedio || d.precio)
      if (val > 10 && val < 1000) {
        ves = val
        bcvDate = d.fechaActualizacion || bcvDate
      }
    }
  } catch (e) {
    console.warn('Fallo DolarAPI VE en servidor')
  }

  if (!ves) {
    try {
      const r = await fetch('https://pydolarve.org/api/v1/dollar?page=bcv', { headers: { 'User-Agent': 'Mozilla/5.0' } })
      if (r.ok) {
        const d = await r.json()
        const val = Number(d?.monitors?.usd?.price)
        if (val > 10 && val < 1000) {
          ves = val
          bcvDate = d?.datetime?.date || bcvDate
        }
      }
    } catch (e) {}
  }

  // 2. Obtener TRM Oficial Colombia
  try {
    const r = await fetch('https://co.dolarapi.com/v1/dolares/oficial', { headers: { 'User-Agent': 'Mozilla/5.0' } })
    if (r.ok) {
      const d = await r.json()
      const val = Number(d.promedio || d.precio)
      if (val > 2000 && val < 10000) {
        cop = val
        copDate = d.fechaActualizacion || copDate
      }
    }
  } catch (e) {}

  if (!cop) {
    try {
      const r = await fetch('https://open.er-api.com/v6/latest/USD')
      if (r.ok) {
        const d = await r.json()
        if (d?.rates?.COP) cop = Number(d.rates.COP)
      }
    } catch (e) {}
  }

  return res.status(200).json({
    VES: ves || 68.50,
    COP: cop || 4200.00,
    bcvDate,
    copDate,
    fuente: 'BCV Oficial / TRM Colombia'
  })
}
EOF

# 2. Contexto de Monedas en React con tolerancia a fallos
cat > src/context/CurrencyContext.jsx << 'EOF'
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
EOF

# 3. Vista de Configuración de Tasas e Impuestos
cat > src/components/Configuracion/TasasImpuestos.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { DollarSign, Percent, Save, Plus, RefreshCw, CheckCircle2 } from 'lucide-react'
import toast from 'react-hot-toast'

export default function TasasImpuestos() {
  const { rates, setRates, loadData, syncOfficialRates, loadingRates, lastUpdate } = useCurrency()
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
    toast.success('Tasas fijadas manualmente')
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
          <p className="text-xs text-slate-400">Tasas oficiales del Banco Central de Venezuela (BCV) y TRM Colombia</p>
        </div>
        <button onClick={() => syncOfficialRates(true)} disabled={loadingRates} className="btn-primary">
          <RefreshCw className={`w-4 h-4 ${loadingRates ? 'animate-spin' : ''}`} /> Sincronizar Tasas Oficiales de Hoy
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Tasas */}
        <form onSubmit={saveRates} className="card-box space-y-4">
          <div className="flex justify-between items-center">
            <h2 className="font-bold text-sm text-slate-800 flex items-center gap-2">
              <DollarSign className="w-4 h-4 text-teal-600" /> Tasas Oficiales del Sistema
            </h2>
            {lastUpdate && (
              <span className="text-[10px] text-teal-700 bg-teal-50 px-2 py-0.5 rounded-full font-semibold flex items-center gap-1">
                <CheckCircle2 className="w-3 h-3" /> Actualizado: {lastUpdate}
              </span>
            )}
          </div>

          <div>
            <label className="text-xs font-semibold text-slate-600 block mb-1">Tasa Bolívares (VES por cada 1 USD)</label>
            <input type="number" step="0.01" className="input-field font-bold text-base text-teal-800" value={ves} onChange={e => setVes(e.target.value)} />
            <span className="text-[10px] text-slate-400">Oficial Banco Central de Venezuela (BCV) con cierre de fin de semana</span>
          </div>

          <div>
            <label className="text-xs font-semibold text-slate-600 block mb-1">Tasa Pesos Colombianos (COP por cada 1 USD)</label>
            <input type="number" step="1" className="input-field font-bold text-base text-amber-800" value={cop} onChange={e => setCop(e.target.value)} />
            <span className="text-[10px] text-slate-400">Tasa Representativa del Mercado (TRM) Colombia</span>
          </div>

          <button type="submit" className="btn-secondary w-full justify-center text-xs font-bold py-2.5">
            <Save className="w-4 h-4" /> Guardar / Forzar Tasas Manualmente
          </button>
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
                <span className="font-mono bg-teal-100 text-teal-800 px-2.5 py-0.5 rounded-full font-bold">{t.porcentaje}%</span>
              </div>
            ))}
          </div>
          <form onSubmit={addTax} className="flex gap-2 pt-2">
            <input required placeholder="Nombre (ej. IVA 16%)" className="input-field text-xs" value={newTax.nombre} onChange={e => setNewTax({...newTax, nombre: e.target.value})} />
            <input required type="number" placeholder="%" className="input-field w-20 text-xs" value={newTax.porcentaje} onChange={e => setNewTax({...newTax, porcentaje: e.target.value})} />
            <button type="submit" className="btn-primary"><Plus className="w-4 h-4" /></button>
          </form>
        </div>
      </div>
    </div>
  )
}
EOF

npm run build
echo "✅ Backend y Frontend sincronizados con BCV Oficial."
