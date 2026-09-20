import { useState } from 'react'
import { Outlet, NavLink } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import { useCurrency } from '../../context/CurrencyContext'
import {
  Users, Calendar, FileText, Activity, ShoppingBag, Package,
  Settings, LogOut, RefreshCw, LayoutDashboard, Receipt, BarChart3,
  CreditCard, UserCheck, Menu, X, Wallet, FlaskConical, MessageSquare
} from 'lucide-react'

export default function Shell() {
  const { logout } = useAuth()
  const { rates, activeCur, setActiveCur, syncOfficialRates } = useCurrency()
  const [mob, setMob] = useState(false)

  const nav = ({ isActive }) =>
    `flex items-center gap-2.5 px-3.5 py-2.5 rounded-xl text-xs font-semibold transition-all ${isActive ? 'bg-teal-600 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-100'}`
  const close = () => setMob(false)

  return (
    <div className="min-h-screen flex flex-col md:flex-row bg-slate-50">
      <div className="md:hidden bg-white border-b px-4 py-3 flex justify-between items-center z-50">
        <span className="font-bold text-sm">🦷 OdontoCare Pro</span>
        <button onClick={() => setMob(!mob)} className="p-1.5">{mob ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}</button>
      </div>

      <aside className={`fixed md:static inset-y-0 left-0 z-40 w-64 bg-white border-r p-4 flex flex-col justify-between shrink-0 overflow-y-auto transition-transform ${mob ? 'translate-x-0 shadow-2xl' : '-translate-x-full md:translate-x-0'}`}>
        <div className="space-y-4">
          <div className="hidden md:flex items-center gap-3 px-2 mb-2">
            <span className="text-xl">🦷</span>
            <div><h2 className="font-bold text-sm">OdontoCare Pro</h2><span className="text-[10px] text-slate-400">Gestión Integral</span></div>
          </div>
          <nav className="space-y-0.5">
            <NavLink to="/" onClick={close} className={nav}><LayoutDashboard className="w-4 h-4" /> Panel</NavLink>
            <NavLink to="/reportes" onClick={close} className={nav}><BarChart3 className="w-4 h-4" /> Reportes & Finanzas</NavLink>
            <NavLink to="/caja" onClick={close} className={nav}><Wallet className="w-4 h-4" /> Caja Chica & Cierre</NavLink>
            <NavLink to="/comunicacion" onClick={close} className={nav}><MessageSquare className="w-4 h-4 text-emerald-600" /> WhatsApp & Contacto</NavLink>

            <p className="text-[10px] uppercase font-bold text-slate-400 px-3 pt-3 py-1">Consultorio</p>
            <NavLink to="/pacientes" onClick={close} className={nav}><Users className="w-4 h-4" /> Pacientes 360°</NavLink>
            <NavLink to="/citas" onClick={close} className={nav}><Calendar className="w-4 h-4" /> Agenda & Horarios</NavLink>
            <NavLink to="/historial" onClick={close} className={nav}><FileText className="w-4 h-4" /> Historial & Cobros</NavLink>
            <NavLink to="/planes" onClick={close} className={nav}><CreditCard className="w-4 h-4" /> Planes & Cuotas</NavLink>
            <NavLink to="/tratamientos" onClick={close} className={nav}><Activity className="w-4 h-4" /> Tratamientos</NavLink>
            <NavLink to="/doctores" onClick={close} className={nav}><UserCheck className="w-4 h-4" /> Doctores</NavLink>
            <NavLink to="/laboratorio" onClick={close} className={nav}><FlaskConical className="w-4 h-4" /> Laboratorio Dental</NavLink>

            <p className="text-[10px] uppercase font-bold text-slate-400 px-3 pt-3 py-1">Insumos & Ventas</p>
            <NavLink to="/pos" onClick={close} className={nav}><ShoppingBag className="w-4 h-4" /> Punto de Venta (POS)</NavLink>
            <NavLink to="/ventas" onClick={close} className={nav}><Receipt className="w-4 h-4" /> Historial de Ventas</NavLink>
            <NavLink to="/inventario" onClick={close} className={nav}><Package className="w-4 h-4" /> Almacén & Kardex</NavLink>
            <NavLink to="/config" onClick={close} className={nav}><Settings className="w-4 h-4" /> Membrete & Tasas</NavLink>
          </nav>
        </div>
        <button onClick={logout} className="flex items-center gap-2 text-xs font-semibold text-rose-600 hover:bg-rose-50 p-3 rounded-xl mt-4"><LogOut className="w-4 h-4" /> Salir</button>
      </aside>

      {mob && <div onClick={close} className="fixed inset-0 bg-black/40 z-30 md:hidden" />}

      <main className="flex-1 flex flex-col min-w-0">
        <header className="bg-white border-b px-6 py-3 flex items-center justify-between flex-wrap gap-3">
          <div className="flex items-center gap-2">
            {['USD','VES','COP'].map(c => (
              <button key={c} onClick={() => setActiveCur(c)} className={`px-2.5 py-1 rounded-lg text-xs font-bold ${activeCur === c ? 'bg-slate-900 text-white' : 'bg-slate-100 text-slate-600'}`}>{c}</button>
            ))}
          </div>
          <div className="flex items-center gap-2 text-xs">
            <span className="bg-teal-50 text-teal-800 font-bold px-2 py-1 rounded-lg border border-teal-100">BCV: Bs.{rates.VES}</span>
            <span className="bg-amber-50 text-amber-800 font-bold px-2 py-1 rounded-lg border border-amber-100">COP: ${rates.COP}</span>
            <button onClick={() => syncOfficialRates(true)} className="p-1.5 hover:bg-slate-100 rounded-lg"><RefreshCw className="w-3.5 h-3.5" /></button>
          </div>
        </header>
        <div className="p-6 overflow-y-auto flex-1"><Outlet /></div>
      </main>
    </div>
  )
}
