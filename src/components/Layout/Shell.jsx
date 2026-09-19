import { Outlet, NavLink } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import { useCurrency } from '../../context/CurrencyContext'
import { Users, Calendar, FileText, Activity, ShoppingBag, Package, Settings, LogOut, RefreshCw, LayoutDashboard, Receipt } from 'lucide-react'

export default function Shell() {
  const { logout } = useAuth()
  const { rates, activeCur, setActiveCur, syncOfficialRates } = useCurrency()

  const nav = ({ isActive }) =>
    `flex items-center gap-2.5 px-3.5 py-2.5 rounded-xl text-xs font-semibold transition-all ${
      isActive ? 'bg-teal-600 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-100'
    }`

  return (
    <div className="min-h-screen flex flex-col md:flex-row bg-slate-50">
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
              BCV: Bs. {rates.VES}
            </span>
            <span className="bg-amber-50 text-amber-800 font-bold px-2.5 py-1 rounded-lg text-xs border border-amber-100">
              COP: ${rates.COP}
            </span>
            <button onClick={() => syncOfficialRates(true)} title="Actualizar BCV" className="p-1.5 hover:bg-slate-100 rounded-lg text-slate-600">
              <RefreshCw className="w-4 h-4" />
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
