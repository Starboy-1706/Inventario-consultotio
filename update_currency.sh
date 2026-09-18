#!/bin/bash
set -e

echo "🔄 Actualizando APIs de Tasas Oficiales (BCV y TRM Colombia)..."

# CurrencyContext con APIs oficiales en vivo
cat > src/context/CurrencyContext.jsx << 'EOF'
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
EOF

# Header actualizado con botón de refresco directo
cat > src/components/Layout/Shell.jsx << 'EOF'
import { Outlet, NavLink } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import { useCurrency } from '../../context/CurrencyContext'
import { Users, Calendar, FileText, Activity, ShoppingBag, Package, Settings, LogOut, RefreshCw, LayoutDashboard, Receipt } from 'lucide-react'

export default function Shell() {
  const { logout } = useAuth()
  const { rates, activeCur, setActiveCur, syncOfficialRates, loadingRates } = useCurrency()

  const nav = ({ isActive }) =>
    `flex items-center gap-2.5 px-3.5 py-2.5 rounded-xl text-xs font-semibold transition-all ${
      isActive ? 'bg-teal-600 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-100'
    }`

  return (
    <div className="min-h-screen flex flex-col md:flex-row bg-slate-50">
      {/* Sidebar */}
      <aside className="w-full md:w-64 bg-white border-r border-slate-100 p-4 flex flex-col justify-between shrink-0">
        <div className="space-y-6">
          <div className="flex items-center gap-3 px-2">
            <div className="w-10 h-10 bg-teal-50 text-teal-600 rounded-xl flex items-center justify-center text-xl font-bold shadow-inner">🦷</div>
            <div>
              <h2 className="font-bold text-sm leading-tight text-slate-800">OdontoCare</h2>
              <span className="text-[10px] font-semibold text-slate-400">Consultorio + Tienda</span>
            </div>
          </div>

          <nav className="space-y-1">
            <NavLink to="/" className={nav}><LayoutDashboard className="w-4 h-4" /> Panel General</NavLink>

            <p className="text-[10px] uppercase font-bold text-slate-400 px-3 pt-4 py-1 tracking-wider">1. Consultorio Clínico</p>
            <NavLink to="/pacientes" className={nav}><Users className="w-4 h-4" /> Pacientes</NavLink>
            <NavLink to="/citas" className={nav}><Calendar className="w-4 h-4" /> Agenda de Citas</NavLink>
            <NavLink to="/historial" className={nav}><FileText className="w-4 h-4" /> Historial Clínico</NavLink>
            <NavLink to="/tratamientos" className={nav}><Activity className="w-4 h-4" /> Tratamientos</NavLink>

            <p className="text-[10px] uppercase font-bold text-slate-400 px-3 pt-4 py-1 tracking-wider">2. Insumos & Ventas</p>
            <NavLink to="/pos" className={nav}><ShoppingBag className="w-4 h-4" /> Punto de Venta (POS)</NavLink>
            <NavLink to="/ventas" className={nav}><Receipt className="w-4 h-4" /> Historial de Ventas</NavLink>
            <NavLink to="/inventario" className={nav}><Package className="w-4 h-4" /> Stock de Insumos</NavLink>
            <NavLink to="/config" className={nav}><Settings className="w-4 h-4" /> Tasas & Impuestos</NavLink>
          </nav>
        </div>

        <button onClick={logout} className="flex items-center gap-2.5 text-xs font-semibold text-rose-600 hover:bg-rose-50 p-3 rounded-xl transition-all">
          <LogOut className="w-4 h-4" /> Cerrar Sesión
        </button>
      </aside>

      {/* Contenido Principal */}
      <main className="flex-1 flex flex-col min-w-0">
        <header className="bg-white border-b border-slate-100 px-6 py-3 flex items-center justify-between flex-wrap gap-3">
          <div className="flex items-center gap-2">
            <span className="text-xs font-semibold text-slate-500 mr-1">Ver Precios en:</span>
            {['USD', 'VES', 'COP'].map(c => (
              <button
                key={c}
                onClick={() => setActiveCur(c)}
                className={`px-3 py-1 rounded-lg text-xs font-bold transition-all ${
                  activeCur === c ? 'bg-slate-900 text-white shadow-sm' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                }`}
              >
                {c}
              </button>
            ))}
          </div>

          <div className="flex items-center gap-3">
            <span className="bg-teal-50 text-teal-800 font-bold px-2.5 py-1 rounded-lg text-xs border border-teal-100">
              BCV Oficial: Bs. {rates.VES > 0 ? rates.VES.toFixed(2) : 'Cargando...'}
            </span>
            <span className="bg-amber-50 text-amber-800 font-bold px-2.5 py-1 rounded-lg text-xs border border-amber-100">
              TRM Colombia: ${rates.COP > 0 ? rates.COP.toLocaleString('es-CO') : 'Cargando...'}
            </span>
            <button
              onClick={() => syncOfficialRates(true)}
              disabled={loadingRates}
              title="Actualizar Tasas Oficiales de Hoy"
              className="p-1.5 hover:bg-slate-100 rounded-lg text-slate-600 disabled:opacity-50"
            >
              <RefreshCw className={`w-4 h-4 ${loadingRates ? 'animate-spin text-teal-600' : ''}`} />
            </button>
          </div>
        </header>

        <div className="p-6 overflow-y-auto flex-1">
          <Outlet />
        </div>
      </main>
    </div>
  )
}
EOF

echo "✅ Tasas Oficiales actualizadas y conectadas en tiempo real!"
