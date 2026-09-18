import { Outlet, NavLink } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import { useCurrency } from '../../context/CurrencyContext'
import { Users, Calendar, FileText, Activity, ShoppingBag, Package, Settings, LogOut, RefreshCw } from 'lucide-react'

export default function Shell() {
  const { logout } = useAuth()
  const { rates, fetchBCV } = useCurrency()

  const nav = ({ isActive }) => `flex items-center gap-2.5 px-3 py-2 rounded-xl text-xs font-semibold transition-all ${isActive ? 'bg-teal-600 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-100'}`

  return (
    <div className="min-h-screen flex flex-col md:flex-row bg-slate-50">
      {/* Sidebar */}
      <aside className="w-full md:w-64 bg-white border-r border-slate-100 p-4 flex flex-col justify-between">
        <div className="space-y-6">
          <div className="flex items-center gap-3 px-2">
            <span className="text-2xl">🦷</span>
            <div>
              <h2 className="font-bold text-sm leading-none">OdontoSys</h2>
              <span className="text-[10px] text-slate-400">Consultorio + Insumos</span>
            </div>
          </div>

          <nav className="space-y-1">
            <p className="text-[10px] uppercase font-bold text-slate-400 px-3 py-1">1. Consultorio</p>
            <NavLink to="/pacientes" className={nav}><Users className="w-4 h-4" /> Pacientes</NavLink>
            <NavLink to="/citas" className={nav}><Calendar className="w-4 h-4" /> Agenda de Citas</NavLink>
            <NavLink to="/historial" className={nav}><FileText className="w-4 h-4" /> Historial Clínico</NavLink>
            <NavLink to="/tratamientos" className={nav}><Activity className="w-4 h-4" /> Tratamientos</NavLink>

            <p className="text-[10px] uppercase font-bold text-slate-400 px-3 pt-4 py-1">2. Insumos & Ventas</p>
            <NavLink to="/pos" className={nav}><ShoppingBag className="w-4 h-4" /> Punto de Venta (POS)</NavLink>
            <NavLink to="/inventario" className={nav}><Package className="w-4 h-4" /> Stock de Insumos</NavLink>
            <NavLink to="/config" className={nav}><Settings className="w-4 h-4" /> Tasas & Impuestos</NavLink>
          </nav>
        </div>

        <button onClick={logout} className="flex items-center gap-2 text-xs font-semibold text-rose-600 hover:bg-rose-50 p-3 rounded-xl transition-all">
          <LogOut className="w-4 h-4" /> Salir del Sistema
        </button>
      </aside>

      {/* Main Content */}
      <main className="flex-1 flex flex-col min-w-0">
        <header className="bg-white border-b border-slate-100 px-6 py-3 flex items-center justify-between flex-wrap gap-2">
          <div className="flex items-center gap-3 text-xs">
            <span className="bg-teal-50 text-teal-800 font-bold px-2.5 py-1 rounded-lg border border-teal-100">
              1 USD = Bs. {rates.VES} (BCV)
            </span>
            <span className="bg-amber-50 text-amber-800 font-bold px-2.5 py-1 rounded-lg border border-amber-100">
              1 USD = COP {rates.COP}
            </span>
          </div>
          <button onClick={fetchBCV} className="btn-secondary text-xs py-1.5">
            <RefreshCw className="w-3.5 h-3.5" /> Actualizar BCV
          </button>
        </header>

        <div className="p-6 overflow-y-auto flex-1">
          <Outlet />
        </div>
      </main>
    </div>
  )
}
