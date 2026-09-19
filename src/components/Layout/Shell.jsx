import { useState, useEffect } from 'react'
import { Outlet, NavLink } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import { useCurrency } from '../../context/CurrencyContext'
import { testSupabaseConnection } from '../../lib/supabase'
import {
  Users, Calendar, FileText, Activity, ShoppingBag, Package,
  Settings, LogOut, RefreshCw, LayoutDashboard, Receipt,
  CheckCircle2, AlertCircle
} from 'lucide-react'

export default function Shell() {
  const { logout } = useAuth()
  const { rates, activeCur, setActiveCur, syncOfficialRates, loadingRates } = useCurrency()
  const [dbStatus, setDbStatus] = useState({ loading: true, ok: false })

  const checkDb = async () => {
    setDbStatus({ loading: true, ok: false })
    const res = await testSupabaseConnection()
    setDbStatus({ loading: false, ...res })
  }

  useEffect(() => {
    checkDb()
  }, [])

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

        <div className="space-y-3">
          {/* Indicador de estado de base de datos */}
          <div className={`p-2.5 rounded-xl text-[11px] font-semibold flex items-center justify-between ${
            dbStatus.loading ? 'bg-slate-100 text-slate-500' :
            dbStatus.ok ? 'bg-emerald-50 text-emerald-700 border border-emerald-200' :
            'bg-rose-50 text-rose-700 border border-rose-200'
          }`}>
            <span className="flex items-center gap-1.5">
              {dbStatus.loading ? <RefreshCw className="w-3.5 h-3.5 animate-spin" /> :
               dbStatus.ok ? <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" /> :
               <AlertCircle className="w-3.5 h-3.5 text-rose-600" />}
              {dbStatus.loading ? 'Verificando BD...' : dbStatus.ok ? 'Supabase Conectado' : 'Sin conexión a BD'}
            </span>
            <button onClick={checkDb} title="Re-probar conexión" className="p-1 hover:bg-white rounded">
              <RefreshCw className="w-3 h-3" />
            </button>
          </div>

          <button onClick={logout} className="flex items-center gap-2.5 text-xs font-semibold text-rose-600 hover:bg-rose-50 p-3 rounded-xl transition-all w-full">
            <LogOut className="w-4 h-4" /> Cerrar Sesión
          </button>
        </div>
      </aside>

      {/* Header y contenido */}
      <main className="flex-1 flex flex-col min-w-0">
        <header className="bg-white border-b border-slate-100 px-6 py-3 flex items-center justify-between flex-wrap gap-3">
          <div className="flex items-center gap-2">
            <span className="text-xs font-semibold text-slate-500 mr-1">Moneda:</span>
            {['USD', 'VES', 'COP'].map(c => (
              <button key={c} onClick={() => setActiveCur(c)}
                className={`px-3 py-1 rounded-lg text-xs font-bold transition-all ${
                  activeCur === c ? 'bg-slate-900 text-white shadow-sm' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                }`}>
                {c}
              </button>
            ))}
          </div>

          <div className="flex items-center gap-3">
            <span className="bg-teal-50 text-teal-800 font-bold px-2.5 py-1 rounded-lg text-xs border border-teal-100">
              BCV: Bs. {rates.VES > 0 ? rates.VES.toFixed(2) : '—'}
            </span>
            <span className="bg-amber-50 text-amber-800 font-bold px-2.5 py-1 rounded-lg text-xs border border-amber-100">
              COP: ${rates.COP > 0 ? rates.COP.toLocaleString('es-CO') : '—'}
            </span>
            <button onClick={() => syncOfficialRates(true)} disabled={loadingRates} title="Actualizar BCV" className="p-1.5 hover:bg-slate-100 rounded-lg text-slate-600">
              <RefreshCw className={`w-4 h-4 ${loadingRates ? 'animate-spin text-teal-600' : ''}`} />
            </button>
          </div>
        </header>

        {/* Banner de alerta si Supabase no está conectado */}
        {!dbStatus.loading && !dbStatus.ok && (
          <div className="bg-rose-500 text-white px-6 py-2.5 text-xs font-bold flex items-center justify-between">
            <span className="flex items-center gap-2">
              <AlertCircle className="w-4 h-4 shrink-0" />
              Atención: La aplicación no está conectada con Supabase ({dbStatus.message}).
            </span>
            <NavLink to="/config" className="underline hover:text-rose-100 ml-4">
              Ver Diagnóstico →
            </NavLink>
          </div>
        )}

        <div className="p-6 overflow-y-auto flex-1">
          <Outlet />
        </div>
      </main>
    </div>
  )
}
