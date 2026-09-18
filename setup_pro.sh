#!/bin/bash
set -e

echo "🦷 Construyendo Sistema Odontológico Profesional Completo..."

# Crear estructura
rm -rf src/components src/context src/lib src/utils 2>/dev/null || true
mkdir -p public src/{components/{Auth,Layout,Dashboard,Consultorio,Ventas,Inventario,Configuracion,UI},context,lib,utils}

# package.json
cat > package.json << 'EOF'
{
  "name": "sistema-odontologico-pro",
  "private": true,
  "version": "2.5.0",
  "type": "module",
  "scripts": {
    "dev": "vite --host 0.0.0.0",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "@supabase/supabase-js": "^2.48.1",
    "lucide-react": "^0.475.0",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-hot-toast": "^2.5.1",
    "react-router-dom": "^6.28.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.4",
    "autoprefixer": "^10.4.20",
    "postcss": "^8.4.49",
    "tailwindcss": "^3.4.17",
    "vite": "^5.4.11"
  }
}
EOF

# vite.config.js
cat > vite.config.js << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
export default defineConfig({ plugins: [react()], server: { host: '0.0.0.0', port: 5173 } })
EOF

# tailwind.config.js
cat > tailwind.config.js << 'EOF'
export default {
  content: ["./index.html", "./src/**/*.{js,jsx}"],
  theme: {
    extend: {
      colors: {
        teal: {
          50: '#f0fdfa', 100: '#ccfbf1', 200: '#99f6e4', 300: '#5eead4',
          400: '#2dd4bf', 500: '#14b8a6', 600: '#0d9488', 700: '#0f766e',
          800: '#115e59', 900: '#134e4a'
        }
      }
    }
  },
  plugins: []
}
EOF

cat > postcss.config.js << 'EOF'
export default { plugins: { tailwindcss: {}, autoprefixer: {} } }
EOF

cat > vercel.json << 'EOF'
{ "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }] }
EOF

cat > index.html << 'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🦷</text></svg>">
  <title>DentalSys - Consultorio & Insumos Odontológicos</title>
</head>
<body class="bg-slate-50 text-slate-900 font-sans antialiased">
  <div id="root"></div>
  <script type="module" src="/src/main.jsx"></script>
</body>
</html>
EOF

# CSS Base
cat > src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer components {
  .btn-primary { @apply bg-teal-600 hover:bg-teal-700 active:scale-95 text-white font-medium px-4 py-2 rounded-xl flex items-center justify-center gap-2 text-sm shadow-sm transition-all disabled:opacity-50; }
  .btn-secondary { @apply bg-slate-100 hover:bg-slate-200 active:scale-95 text-slate-700 font-medium px-4 py-2 rounded-xl flex items-center justify-center gap-2 text-sm transition-all; }
  .btn-danger { @apply bg-rose-50 hover:bg-rose-100 active:scale-95 text-rose-600 font-medium px-3 py-1.5 rounded-xl flex items-center gap-1.5 text-xs transition-all; }
  .input-field { @apply w-full px-3.5 py-2 bg-white border border-slate-200 rounded-xl focus:ring-2 focus:ring-teal-500 focus:border-teal-500 outline-none text-sm transition-all; }
  .card-box { @apply bg-white rounded-2xl border border-slate-100 p-5 shadow-sm; }
  .badge { @apply text-xs font-semibold px-2.5 py-0.5 rounded-full inline-flex items-center gap-1; }
}

::-webkit-scrollbar { width: 6px; height: 6px; }
::-webkit-scrollbar-track { background: #f1f5f9; }
::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 9999px; }
::-webkit-scrollbar-thumb:hover { background: #94a3b8; }
EOF

# Helpers y Libs
cat > src/main.jsx << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './index.css'
ReactDOM.createRoot(document.getElementById('root')).render(<React.StrictMode><App /></React.StrictMode>)
EOF

cat > src/lib/supabase.js << 'EOF'
import { createClient } from '@supabase/supabase-js'
export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL || '',
  import.meta.env.VITE_SUPABASE_ANON_KEY || ''
)
EOF

cat > src/utils/helpers.js << 'EOF'
export const fmt = (amount, cur = 'USD') => {
  const n = Number(amount || 0)
  if (cur === 'VES') return `Bs. ${n.toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
  if (cur === 'COP') return `COP ${n.toLocaleString('es-CO', { minimumFractionDigits: 0 })}`
  return `$ ${n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}

export const formatDate = (d) => {
  if (!d) return ''
  return new Date(d).toLocaleDateString('es-VE', { day: '2-digit', month: 'short', year: 'numeric' })
}

export const formatDateTime = (d) => {
  if (!d) return ''
  return new Date(d).toLocaleString('es-VE', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
}
EOF

# Contexto de Autenticación
cat > src/context/AuthContext.jsx << 'EOF'
import { createContext, useContext, useState, useEffect } from 'react'

const AuthContext = createContext()

export function AuthProvider({ children }) {
  const [auth, setAuth] = useState(false)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const s = localStorage.getItem('odonto_auth_session')
    if (s === 'active') setAuth(true)
    setLoading(false)
  }, [])

  const login = (pass) => {
    const valid = import.meta.env.VITE_APP_PASSWORD || 'admin123'
    if (pass === valid) {
      localStorage.setItem('odonto_auth_session', 'active')
      setAuth(true)
      return true
    }
    return false
  }

  const logout = () => {
    localStorage.removeItem('odonto_auth_session')
    setAuth(false)
  }

  return (
    <AuthContext.Provider value={{ auth, loading, login, logout }}>
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = () => useContext(AuthContext)
EOF

# Contexto de Monedas y Tasas
cat > src/context/CurrencyContext.jsx << 'EOF'
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
EOF

# Precios Multi-moneda
cat > src/components/UI/PriceBox.jsx << 'EOF'
import { useCurrency } from '../../context/CurrencyContext'
import { fmt } from '../../utils/helpers'

export default function PriceBox({ usd, className = '', showAll = false }) {
  const { rates, activeCur } = useCurrency()
  const amountUSD = Number(usd || 0)
  const amountVES = amountUSD * rates.VES
  const amountCOP = amountUSD * rates.COP

  if (showAll) {
    return (
      <div className={`space-y-0.5 ${className}`}>
        <div className="font-bold text-teal-700">{fmt(amountUSD, 'USD')}</div>
        <div className="text-xs text-slate-500 font-medium">{fmt(amountVES, 'VES')}</div>
        <div className="text-[11px] text-amber-700 font-medium">{fmt(amountCOP, 'COP')}</div>
      </div>
    )
  }

  return (
    <span className={className}>
      {activeCur === 'USD' && fmt(amountUSD, 'USD')}
      {activeCur === 'VES' && fmt(amountVES, 'VES')}
      {activeCur === 'COP' && fmt(amountCOP, 'COP')}
    </span>
  )
}
EOF

# Ticket Modal
cat > src/components/UI/TicketModal.jsx << 'EOF'
import { Printer, X } from 'lucide-react'
import { fmt } from '../../utils/helpers'

export default function TicketModal({ venta, onClose }) {
  if (!venta) return null

  const printTicket = () => {
    window.print()
  }

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-3xl p-6 w-full max-w-sm shadow-2xl space-y-4 text-center">
        <div className="flex justify-between items-center border-b pb-2">
          <span className="text-xs font-bold text-slate-400">COMPROBANTE DE PAGO</span>
          <button onClick={onClose} className="p-1 hover:bg-slate-100 rounded-lg text-slate-500"><X className="w-4 h-4" /></button>
        </div>

        <div className="text-center space-y-1">
          <div className="text-3xl">🦷</div>
          <h2 className="font-bold text-base text-slate-800">CONSULTORIO DENTAL</h2>
          <p className="text-[11px] text-slate-400">Venta de Insumos & Atención Odontológica</p>
          <p className="text-xs font-mono font-bold text-teal-700 pt-1">{venta.factura}</p>
          <p className="text-[10px] text-slate-400">{new Date(venta.created_at || Date.now()).toLocaleString()}</p>
        </div>

        <div className="text-left text-xs bg-slate-50 p-3 rounded-xl space-y-1">
          <p><span className="text-slate-400">Cliente:</span> <b>{venta.cliente}</b></p>
          {venta.cedula_cliente && <p><span className="text-slate-400">Documento:</span> <b>{venta.cedula_cliente}</b></p>}
        </div>

        <div className="space-y-1 text-xs border-t border-b py-2 text-left">
          <div className="flex justify-between text-slate-500"><span>Subtotal:</span><span>{fmt(venta.subtotal_usd, 'USD')}</span></div>
          {Number(venta.impuesto_usd) > 0 && (
            <div className="flex justify-between text-teal-700"><span>Impuestos:</span><span>{fmt(venta.impuesto_usd, 'USD')}</span></div>
          )}
          <div className="flex justify-between text-sm font-bold text-slate-900 pt-1">
            <span>TOTAL USD:</span><span>{fmt(venta.total_usd, 'USD')}</span>
          </div>
          <div className="flex justify-between font-bold text-teal-700">
            <span>TOTAL BS:</span><span>{fmt(venta.total_ves, 'VES')}</span>
          </div>
          <div className="flex justify-between font-bold text-amber-700">
            <span>TOTAL COP:</span><span>{fmt(venta.total_cop, 'COP')}</span>
          </div>
        </div>

        <div className="flex gap-2 pt-2">
          <button onClick={onClose} className="w-1/2 btn-secondary justify-center">Cerrar</button>
          <button onClick={printTicket} className="w-1/2 btn-primary justify-center"><Printer className="w-4 h-4" /> Imprimir</button>
        </div>
      </div>
    </div>
  )
}
EOF

# Login
cat > src/components/Auth/Login.jsx << 'EOF'
import { useState } from 'react'
import { useAuth } from '../../context/AuthContext'
import { Lock, ArrowRight } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Login() {
  const [pass, setPass] = useState('')
  const { login } = useAuth()

  const handle = (e) => {
    e.preventDefault()
    if (login(pass)) toast.success('Acceso correcto')
    else { toast.error('Clave de acceso incorrecta'); setPass('') }
  }

  return (
    <div className="min-h-screen bg-slate-950 flex items-center justify-center p-4 relative overflow-hidden">
      <div className="absolute -top-40 -left-40 w-96 h-96 bg-teal-500/10 rounded-full blur-3xl"></div>
      <div className="absolute -bottom-40 -right-40 w-96 h-96 bg-cyan-500/10 rounded-full blur-3xl"></div>

      <form onSubmit={handle} className="relative bg-white/95 backdrop-blur-md p-8 rounded-3xl w-full max-w-sm border border-white/20 shadow-2xl space-y-6 text-center">
        <div className="w-16 h-16 bg-teal-50 text-teal-600 rounded-2xl flex items-center justify-center mx-auto text-3xl shadow-inner">
          🦷
        </div>
        <div>
          <h1 className="text-xl font-bold text-slate-800">Sistema Odontológico</h1>
          <p className="text-xs text-slate-400 mt-1">Consultorio & Ventas de Insumos</p>
        </div>

        <div className="text-left space-y-1.5">
          <label className="text-xs font-semibold text-slate-600">Clave de Acceso</label>
          <div className="flex items-center border border-slate-200 rounded-xl px-3.5 py-2.5 bg-slate-50/50 focus-within:ring-2 focus-within:ring-teal-500 focus-within:bg-white transition-all">
            <Lock className="w-4 h-4 text-slate-400 mr-2 shrink-0" />
            <input type="password" placeholder="••••••••" value={pass} onChange={e => setPass(e.target.value)} className="bg-transparent outline-none w-full text-sm" autoFocus />
          </div>
        </div>

        <button type="submit" className="w-full btn-primary py-3 justify-center shadow-lg shadow-teal-600/20">
          Ingresar al Sistema <ArrowRight className="w-4 h-4" />
        </button>
      </form>
    </div>
  )
}
EOF

# Layout General
cat > src/components/Layout/Shell.jsx << 'EOF'
import { Outlet, NavLink } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import { useCurrency } from '../../context/CurrencyContext'
import { Users, Calendar, FileText, Activity, ShoppingBag, Package, Settings, LogOut, RefreshCw, LayoutDashboard, Receipt } from 'lucide-react'

export default function Shell() {
  const { logout } = useAuth()
  const { rates, activeCur, setActiveCur, syncBCV } = useCurrency()

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
            <div className="w-10 h-10 bg-teal-50 text-teal-600 rounded-xl flex items-center justify-center text-xl font-bold">🦷</div>
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
              BCV: Bs. {rates.VES}
            </span>
            <span className="bg-amber-50 text-amber-800 font-bold px-2.5 py-1 rounded-lg text-xs border border-amber-100">
              COP: ${rates.COP}
            </span>
            <button onClick={syncBCV} title="Sincronizar BCV" className="p-1.5 hover:bg-slate-100 rounded-lg text-slate-600">
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
EOF

# Dashboard
cat > src/components/Dashboard/Dashboard.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import PriceBox from '../UI/PriceBox'
import { Users, Calendar, ShoppingBag, Package, AlertTriangle, ArrowUpRight } from 'lucide-react'
import { Link } from 'react-router-dom'

export default function Dashboard() {
  const [stats, setStats] = useState({ pacs: 0, citas: 0, ventasTotal: 0, lowStock: 0 })
  const [citasHoy, setCitasHoy] = useState([])
  const [prodsBajos, setProdsBajos] = useState([])

  const load = async () => {
    const today = new Date().toISOString().split('T')[0]
    const [p, c, v, pr] = await Promise.all([
      supabase.from('pacientes').select('id', { count: 'exact', head: true }).eq('activo', true),
      supabase.from('citas').select('*, pacientes(nombres, apellidos), tratamientos(nombre)').gte('fecha', `${today}T00:00:00`).lte('fecha', `${today}T23:59:59`),
      supabase.from('ventas').select('total_usd').eq('estado', 'completada'),
      supabase.from('productos').select('*').eq('activo', true)
    ])

    const totalV = v.data?.reduce((a, b) => a + Number(b.total_usd), 0) || 0
    const low = pr.data?.filter(x => x.stock <= x.stock_minimo) || []

    setStats({ pacs: p.count || 0, citas: c.data?.length || 0, ventasTotal: totalV, lowStock: low.length })
    setCitasHoy(c.data || [])
    setProdsBajos(low.slice(0, 5))
  }
  useEffect(() => { load() }, [])

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-bold text-slate-800">Panel de Control</h1>
        <p className="text-xs text-slate-400">Resumen operativo del consultorio y ventas de insumos</p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="card-box flex items-center justify-between">
          <div><p className="text-xs text-slate-400 font-medium">Pacientes Registrados</p><h3 className="text-2xl font-bold text-slate-800 mt-1">{stats.pacs}</h3></div>
          <div className="w-12 h-12 bg-blue-50 text-blue-600 rounded-2xl flex items-center justify-center"><Users className="w-6 h-6" /></div>
        </div>
        <div className="card-box flex items-center justify-between">
          <div><p className="text-xs text-slate-400 font-medium">Citas para Hoy</p><h3 className="text-2xl font-bold text-slate-800 mt-1">{stats.citas}</h3></div>
          <div className="w-12 h-12 bg-teal-50 text-teal-600 rounded-2xl flex items-center justify-center"><Calendar className="w-6 h-6" /></div>
        </div>
        <div className="card-box flex items-center justify-between">
          <div>
            <p className="text-xs text-slate-400 font-medium">Ventas de Insumos</p>
            <h3 className="text-xl font-bold text-slate-800 mt-1"><PriceBox usd={stats.ventasTotal} /></h3>
          </div>
          <div className="w-12 h-12 bg-emerald-50 text-emerald-600 rounded-2xl flex items-center justify-center"><ShoppingBag className="w-6 h-6" /></div>
        </div>
        <div className="card-box flex items-center justify-between">
          <div><p className="text-xs text-slate-400 font-medium">Insumos en Alerta</p><h3 className="text-2xl font-bold text-rose-600 mt-1">{stats.lowStock}</h3></div>
          <div className="w-12 h-12 bg-rose-50 text-rose-600 rounded-2xl flex items-center justify-center"><AlertTriangle className="w-6 h-6" /></div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Citas de Hoy */}
        <div className="card-box space-y-3">
          <div className="flex justify-between items-center border-b pb-2">
            <h3 className="font-bold text-sm text-slate-800 flex items-center gap-2"><Calendar className="w-4 h-4 text-teal-600" /> Agenda de Hoy</h3>
            <Link to="/citas" className="text-xs font-semibold text-teal-600 flex items-center gap-1 hover:underline">Ver todas <ArrowUpRight className="w-3.5 h-3.5" /></Link>
          </div>
          <div className="space-y-2">
            {citasHoy.length === 0 ? <p className="text-xs text-slate-400 py-6 text-center">No hay citas para hoy</p> :
            citasHoy.map(c => (
              <div key={c.id} className="flex justify-between items-center p-2.5 bg-slate-50 rounded-xl text-xs">
                <div><p className="font-bold text-slate-800">{c.pacientes?.nombres} {c.pacientes?.apellidos}</p><span className="text-slate-400">{c.tratamientos?.nombre || 'Consulta General'}</span></div>
                <span className="font-bold text-teal-700">{new Date(c.fecha).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Insumos con bajo stock */}
        <div className="card-box space-y-3">
          <div className="flex justify-between items-center border-b pb-2">
            <h3 className="font-bold text-sm text-slate-800 flex items-center gap-2"><Package className="w-4 h-4 text-rose-500" /> Insumos con Stock Bajo</h3>
            <Link to="/inventario" className="text-xs font-semibold text-teal-600 flex items-center gap-1 hover:underline">Ir al almacén <ArrowUpRight className="w-3.5 h-3.5" /></Link>
          </div>
          <div className="space-y-2">
            {prodsBajos.length === 0 ? <p className="text-xs text-slate-400 py-6 text-center">Stock de insumos en óptimas condiciones</p> :
            prodsBajos.map(p => (
              <div key={p.id} className="flex justify-between items-center p-2.5 bg-rose-50/50 border border-rose-100 rounded-xl text-xs">
                <div><p className="font-bold text-slate-800">{p.nombre}</p><span className="text-slate-400">{p.codigo || 'S/C'}</span></div>
                <span className="badge bg-rose-100 text-rose-700 font-bold">Stock: {p.stock} (Mín: {p.stock_minimo})</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
EOF

# Módulo Consultorio: Pacientes
cat > src/components/Consultorio/Pacientes.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { Plus, User, Search, Trash2, Phone, AlertCircle } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Pacientes() {
  const [list, setList] = useState([])
  const [q, setQ] = useState('')
  const [modal, setModal] = useState(false)
  const [form, setForm] = useState({ nombres: '', apellidos: '', cedula: '', telefono: '', email: '', alergias: '', antecedentes: '' })

  const load = async () => {
    const { data } = await supabase.from('pacientes').select('*').eq('activo', true).order('created_at', { ascending: false })
    setList(data || [])
  }
  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    await supabase.from('pacientes').insert([form])
    toast.success('Paciente registrado con éxito')
    setModal(false); setForm({ nombres: '', apellidos: '', cedula: '', telefono: '', email: '', alergias: '', antecedentes: '' }); load()
  }

  const del = async (id) => {
    if (confirm('¿Desea desactivar este paciente?')) {
      await supabase.from('pacientes').update({ activo: false }).eq('id', id)
      toast.success('Paciente desactivado'); load()
    }
  }

  const filtered = list.filter(p => `${p.nombres} ${p.apellidos} ${p.cedula}`.toLowerCase().includes(q.toLowerCase()))

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Fichas de Pacientes</h1>
          <p className="text-xs text-slate-400">Expedientes clínicos y antecedentes</p>
        </div>
        <button onClick={() => setModal(true)} className="btn-primary"><Plus className="w-4 h-4" /> Nuevo Paciente</button>
      </div>

      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input placeholder="Buscar por nombre o cédula..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {filtered.map(p => (
          <div key={p.id} className="card-box space-y-3 relative">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-teal-50 text-teal-600 flex items-center justify-center font-bold">
                <User className="w-5 h-5" />
              </div>
              <div>
                <h3 className="font-bold text-sm text-slate-800">{p.nombres} {p.apellidos}</h3>
                <p className="text-xs text-slate-400">CI: {p.cedula || 'Sin registrar'}</p>
              </div>
            </div>

            <div className="text-xs space-y-1.5 text-slate-600 border-t border-slate-100 pt-3">
              <p className="flex items-center gap-1.5"><Phone className="w-3.5 h-3.5 text-slate-400" /> {p.telefono || 'Sin teléfono'}</p>
              {p.alergias && (
                <div className="p-2 bg-rose-50 border border-rose-100 rounded-lg text-rose-700 font-medium flex items-center gap-1.5">
                  <AlertCircle className="w-4 h-4 shrink-0" /> Alergias: {p.alergias}
                </div>
              )}
            </div>

            <button onClick={() => del(p.id)} className="absolute top-4 right-4 text-slate-300 hover:text-rose-600 transition-colors">
              <Trash2 className="w-4 h-4" />
            </button>
          </div>
        ))}
      </div>

      {modal && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-4 shadow-2xl">
            <h2 className="font-bold text-base text-slate-800">Registrar Nuevo Paciente</h2>
            <div className="grid grid-cols-2 gap-3">
              <input required placeholder="Nombres" value={form.nombres} onChange={e => setForm({...form, nombres: e.target.value})} className="input-field" />
              <input required placeholder="Apellidos" value={form.apellidos} onChange={e => setForm({...form, apellidos: e.target.value})} className="input-field" />
            </div>
            <input placeholder="Cédula / Documento" value={form.cedula} onChange={e => setForm({...form, cedula: e.target.value})} className="input-field" />
            <input placeholder="Teléfono" value={form.telefono} onChange={e => setForm({...form, telefono: e.target.value})} className="input-field" />
            <textarea placeholder="Alergias conocidas (ej. Penicilina, Látex)" value={form.alergias} onChange={e => setForm({...form, alergias: e.target.value})} className="input-field" rows={2} />
            <textarea placeholder="Antecedentes médicos (ej. Hipertensión)" value={form.antecedentes} onChange={e => setForm({...form, antecedentes: e.target.value})} className="input-field" rows={2} />

            <div className="flex justify-end gap-2 pt-2">
              <button type="button" onClick={() => setModal(false)} className="btn-secondary">Cancelar</button>
              <button type="submit" className="btn-primary">Guardar Paciente</button>
            </div>
          </form>
        </div>
      )}
    </div>
  )
}
EOF

# Módulo Consultorio: Citas
cat > src/components/Consultorio/Citas.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { Plus, Check, X, Calendar as CalIcon } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Citas() {
  const [citas, setCitas] = useState([])
  const [pacs, setPacs] = useState([])
  const [trats, setTrats] = useState([])
  const [modal, setModal] = useState(false)
  const [form, setForm] = useState({ paciente_id: '', tratamiento_id: '', fecha: '', notas: '' })

  const load = async () => {
    const [c, p, t] = await Promise.all([
      supabase.from('citas').select('*, pacientes(nombres, apellidos), tratamientos(nombre)').order('fecha', { ascending: true }),
      supabase.from('pacientes').select('id, nombres, apellidos').eq('activo', true),
      supabase.from('tratamientos').select('id, nombre').eq('activo', true)
    ])
    setCitas(c.data || []); setPacs(p.data || []); setTrats(t.data || [])
  }
  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    await supabase.from('citas').insert([{ ...form, tratamiento_id: form.tratamiento_id || null }])
    toast.success('Cita agendada correctamente')
    setModal(false); load()
  }

  const setStatus = async (id, estado) => {
    await supabase.from('citas').update({ estado }).eq('id', id)
    toast.success(`Cita marcada como: ${estado}`)
    load()
  }

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Agenda Odontológica</h1>
          <p className="text-xs text-slate-400">Control y estado de citas</p>
        </div>
        <button onClick={() => setModal(true)} className="btn-primary"><Plus className="w-4 h-4" /> Agendar Cita</button>
      </div>

      <div className="space-y-3">
        {citas.map(c => (
          <div key={c.id} className="card-box flex items-center justify-between p-4 flex-wrap gap-3">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-teal-50 text-teal-600 flex items-center justify-center">
                <CalIcon className="w-5 h-5" />
              </div>
              <div>
                <h3 className="font-bold text-sm text-slate-800">{c.pacientes?.nombres} {c.pacientes?.apellidos}</h3>
                <p className="text-xs text-teal-700 font-semibold">{c.tratamientos?.nombre || 'Consulta General'}</p>
                <p className="text-[11px] text-slate-400 mt-0.5">📅 {new Date(c.fecha).toLocaleString()}</p>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <span className={`badge ${
                c.estado === 'completada' ? 'bg-emerald-100 text-emerald-800' :
                c.estado === 'cancelada' ? 'bg-rose-100 text-rose-800' : 'bg-blue-100 text-blue-800'
              }`}>
                {c.estado}
              </span>
              {c.estado === 'programada' && (
                <>
                  <button onClick={() => setStatus(c.id, 'completada')} title="Completar" className="p-1.5 bg-emerald-50 text-emerald-600 rounded-lg hover:bg-emerald-100">
                    <Check className="w-4 h-4" />
                  </button>
                  <button onClick={() => setStatus(c.id, 'cancelada')} title="Cancelar" className="p-1.5 bg-rose-50 text-rose-600 rounded-lg hover:bg-rose-100">
                    <X className="w-4 h-4" />
                  </button>
                </>
              )}
            </div>
          </div>
        ))}
      </div>

      {modal && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-4 shadow-2xl">
            <h2 className="font-bold text-base text-slate-800">Agendar Cita</h2>
            <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
              <option value="">Seleccione Paciente</option>
              {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
            </select>
            <select className="input-field" value={form.tratamiento_id} onChange={e => setForm({...form, tratamiento_id: e.target.value})}>
              <option value="">Tratamiento / Motivo</option>
              {trats.map(t => <option key={t.id} value={t.id}>{t.nombre}</option>)}
            </select>
            <input required type="datetime-local" className="input-field" value={form.fecha} onChange={e => setForm({...form, fecha: e.target.value})} />
            <textarea placeholder="Notas u observaciones" className="input-field" value={form.notas} onChange={e => setForm({...form, notas: e.target.value})} />
            <div className="flex justify-end gap-2 pt-2">
              <button type="button" onClick={() => setModal(false)} className="btn-secondary">Cancelar</button>
              <button type="submit" className="btn-primary">Confirmar</button>
            </div>
          </form>
        </div>
      )}
    </div>
  )
}
EOF

# Módulo Consultorio: Historial Clínico
cat > src/components/Consultorio/Historial.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import PriceBox from '../UI/PriceBox'
import { Plus, FileText, CheckCircle2 } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Historial() {
  const [list, setList] = useState([])
  const [pacs, setPacs] = useState([])
  const [modal, setModal] = useState(false)
  const [form, setForm] = useState({ paciente_id: '', diagnostico: '', procedimiento: '', dientes_tratados: '', monto_usd: 0, pagado: true })

  const load = async () => {
    const [h, p] = await Promise.all([
      supabase.from('historial_clinico').select('*, pacientes(nombres, apellidos)').order('created_at', { ascending: false }),
      supabase.from('pacientes').select('id, nombres, apellidos').eq('activo', true)
    ])
    setList(h.data || []); setPacs(p.data || [])
  }
  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    await supabase.from('historial_clinico').insert([form])
    toast.success('Consulta registrada en el expediente')
    setModal(false); load()
  }

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Historial Clínico</h1>
          <p className="text-xs text-slate-400">Tratamientos realizados y evolución</p>
        </div>
        <button onClick={() => setModal(true)} className="btn-primary"><Plus className="w-4 h-4" /> Registrar Consulta</button>
      </div>

      <div className="space-y-3">
        {list.map(h => (
          <div key={h.id} className="card-box flex justify-between items-center p-4 flex-wrap gap-4">
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-xl bg-teal-50 text-teal-600 flex items-center justify-center shrink-0">
                <FileText className="w-5 h-5" />
              </div>
              <div>
                <h3 className="font-bold text-sm text-slate-800">{h.pacientes?.nombres} {h.pacientes?.apellidos}</h3>
                <p className="text-xs text-teal-700 font-bold">{h.procedimiento}</p>
                <p className="text-xs text-slate-500 mt-1">Dx: {h.diagnostico}</p>
                {h.dientes_tratados && <span className="badge bg-slate-100 text-slate-700 mt-2">Dientes: {h.dientes_tratados}</span>}
              </div>
            </div>

            <div className="text-right">
              <PriceBox usd={h.monto_usd} showAll />
              <div className="mt-2">
                <span className="badge bg-emerald-50 text-emerald-700 border border-emerald-100">
                  <CheckCircle2 className="w-3 h-3" /> Cobrado
                </span>
              </div>
            </div>
          </div>
        ))}
      </div>

      {modal && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-4 shadow-2xl">
            <h2 className="font-bold text-base text-slate-800">Registrar Procedimiento Clínico</h2>
            <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
              <option value="">Seleccione Paciente</option>
              {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
            </select>
            <input required placeholder="Procedimiento (ej. Resina Fotocurada #14)" className="input-field" value={form.procedimiento} onChange={e => setForm({...form, procedimiento: e.target.value})} />
            <input placeholder="Dientes Tratados (ej. 14, 15, 21)" className="input-field" value={form.dientes_tratados} onChange={e => setForm({...form, dientes_tratados: e.target.value})} />
            <textarea placeholder="Diagnóstico e indicaciones" className="input-field" value={form.diagnostico} onChange={e => setForm({...form, diagnostico: e.target.value})} />
            <input type="number" step="0.01" placeholder="Monto cobrado ($ USD)" className="input-field" value={form.monto_usd} onChange={e => setForm({...form, monto_usd: e.target.value})} />

            <div className="flex justify-end gap-2 pt-2">
              <button type="button" onClick={() => setModal(false)} className="btn-secondary">Cancelar</button>
              <button type="submit" className="btn-primary">Guardar Ficha</button>
            </div>
          </form>
        </div>
      )}
    </div>
  )
}
EOF

# Módulo Consultorio: Tratamientos
cat > src/components/Consultorio/Tratamientos.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import PriceBox from '../UI/PriceBox'
import { Plus } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Tratamientos() {
  const [list, setList] = useState([])
  const [modal, setModal] = useState(false)
  const [form, setForm] = useState({ nombre: '', precio: '', duracion_min: 30, categoria: 'General' })

  const load = async () => {
    const { data } = await supabase.from('tratamientos').select('*').eq('activo', true)
    setList(data || [])
  }
  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    await supabase.from('tratamientos').insert([form])
    toast.success('Tratamiento registrado')
    setModal(false); load()
  }

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Catálogo de Procedimientos</h1>
          <p className="text-xs text-slate-400">Precios sincronizados en USD, VES y COP</p>
        </div>
        <button onClick={() => setModal(true)} className="btn-primary"><Plus className="w-4 h-4" /> Nuevo Tratamiento</button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {list.map(t => (
          <div key={t.id} className="card-box space-y-3">
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-sm text-slate-800">{t.nombre}</h3>
              <span className="badge bg-slate-100 text-slate-600">{t.categoria}</span>
            </div>
            <p className="text-xs text-slate-400">Duración estimada: ~{t.duracion_min} min</p>
            <div className="pt-3 border-t border-slate-100">
              <PriceBox usd={t.precio} showAll />
            </div>
          </div>
        ))}
      </div>

      {modal && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-4 shadow-2xl">
            <h2 className="font-bold text-base text-slate-800">Registrar Procedimiento</h2>
            <input required placeholder="Nombre del tratamiento" className="input-field" value={form.nombre} onChange={e => setForm({...form, nombre: e.target.value})} />
            <input required type="number" step="0.01" placeholder="Precio Base ($ USD)" className="input-field" value={form.precio} onChange={e => setForm({...form, precio: e.target.value})} />
            <input placeholder="Categoría (ej. Ortodoncia, Estética)" className="input-field" value={form.categoria} onChange={e => setForm({...form, categoria: e.target.value})} />
            <div className="flex justify-end gap-2 pt-2">
              <button type="button" onClick={() => setModal(false)} className="btn-secondary">Cancelar</button>
              <button type="submit" className="btn-primary">Guardar</button>
            </div>
          </form>
        </div>
      )}
    </div>
  )
}
EOF

# Módulo Ventas: POS
cat > src/components/Ventas/POS.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { fmt } from '../../utils/helpers'
import TicketModal from '../UI/TicketModal'
import { ShoppingBag, Trash2, CheckCircle } from 'lucide-react'
import toast from 'react-hot-toast'

export default function POS() {
  const [prods, setProds] = useState([])
  const [cart, setCart] = useState([])
  const [client, setClient] = useState('')
  const [cedula, setCedula] = useState('')
  const [taxId, setTaxId] = useState('')
  const [lastSale, setLastSale] = useState(null)
  const { rates, taxes } = useCurrency()

  const load = async () => {
    const { data } = await supabase.from('productos').select('*, impuestos(porcentaje)').eq('activo', true).eq('es_vendible', true).gt('stock', 0)
    setProds(data || [])
  }
  useEffect(() => { load() }, [])

  const addToCart = (p) => {
    const ex = cart.find(i => i.id === p.id)
    if (ex) {
      if (ex.cant >= p.stock) return toast.error('Sin stock suficiente')
      setCart(cart.map(i => i.id === p.id ? { ...i, cant: i.cant + 1 } : i))
    } else {
      setCart([...cart, { ...p, cant: 1 }])
    }
  }

  const selectedTax = taxes.find(t => t.id === taxId)
  const taxPct = selectedTax ? selectedTax.porcentaje : 0

  const subtotalUSD = cart.reduce((acc, i) => acc + (i.precio_venta * i.cant), 0)
  const taxUSD = subtotalUSD * (taxPct / 100)
  const totalUSD = subtotalUSD + taxUSD

  const checkout = async () => {
    if (!cart.length) return toast.error('El carrito está vacío')
    const fac = `FAC-${Date.now().toString().slice(-6)}`

    const salePayload = {
      factura: fac,
      cliente: client || 'Cliente General',
      cedula_cliente: cedula || null,
      subtotal_usd: subtotalUSD,
      impuesto_usd: taxUSD,
      total_usd: totalUSD,
      total_ves: totalUSD * rates.VES,
      total_cop: totalUSD * rates.COP,
      tasa_ves: rates.VES,
      tasa_cop: rates.COP
    }

    const { data: v, error } = await supabase.from('ventas').insert([salePayload]).select().single()

    if (error) return toast.error('Error al procesar venta')

    for (const item of cart) {
      await supabase.from('productos').update({ stock: item.stock - item.cant }).eq('id', item.id)
      await supabase.from('movimientos').insert({
        producto_id: item.id,
        tipo: 'venta',
        cantidad: -item.cant,
        stock_antes: item.stock,
        stock_despues: item.stock - item.cant,
        referencia: `Factura: ${fac}`
      })
    }

    toast.success(`¡Venta ${fac} procesada!`)
    setLastSale(v)
    setCart([]); setClient(''); setCedula(''); load()
  }

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
      {/* Catálogo */}
      <div className="lg:col-span-2 space-y-4">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Punto de Venta (Insumos Dentales)</h1>
          <p className="text-xs text-slate-400">Seleccione materiales dentales para facturar</p>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
          {prods.map(p => (
            <button key={p.id} onClick={() => addToCart(p)} className="card-box text-left p-3.5 hover:border-teal-500 transition-all group">
              <h4 className="font-bold text-xs text-slate-800 truncate group-hover:text-teal-700">{p.nombre}</h4>
              <p className="text-[10px] text-slate-400 mt-0.5">Stock disponible: {p.stock}</p>
              <div className="mt-3 flex items-center justify-between">
                <span className="font-bold text-sm text-teal-700">{fmt(p.precio_venta, 'USD')}</span>
                <span className="text-[10px] bg-slate-100 text-slate-600 px-2 py-0.5 rounded-full font-bold">Añadir +</span>
              </div>
            </button>
          ))}
        </div>
      </div>

      {/* Ticket / Carrito */}
      <div className="card-pro space-y-4 h-fit border-2 border-slate-100">
        <h2 className="font-bold text-sm text-slate-800 flex items-center gap-2 border-b pb-3">
          <ShoppingBag className="w-4 h-4 text-teal-600" /> Resumen de Venta
        </h2>

        <div className="space-y-2">
          <input placeholder="Nombre del Comprador" value={client} onChange={e => setClient(e.target.value)} className="input-field text-xs" />
          <input placeholder="Cédula / Documento (Opcional)" value={cedula} onChange={e => setCedula(e.target.value)} className="input-field text-xs" />
          <select value={taxId} onChange={e => setTaxId(e.target.value)} className="input-field text-xs">
            <option value="">Impuesto Global (Exento)</option>
            {taxes.map(t => <option key={t.id} value={t.id}>{t.nombre} ({t.porcentaje}%)</option>)}
          </select>
        </div>

        <div className="space-y-2 max-h-52 overflow-y-auto pr-1">
          {cart.map(i => (
            <div key={i.id} className="flex justify-between items-center text-xs bg-slate-50 p-2 rounded-xl">
              <div>
                <p className="font-bold text-slate-800 truncate w-32">{i.nombre}</p>
                <span className="text-slate-400">{fmt(i.precio_venta)} x {i.cant}</span>
              </div>
              <button onClick={() => setCart(cart.filter(x => x.id !== i.id))} className="text-slate-400 hover:text-rose-600">
                <Trash2 className="w-4 h-4" />
              </button>
            </div>
          ))}
        </div>

        {/* Totales */}
        <div className="border-t border-slate-100 pt-3 space-y-1.5 text-xs">
          <div className="flex justify-between text-slate-500"><span>Subtotal:</span><span>{fmt(subtotalUSD, 'USD')}</span></div>
          {taxPct > 0 && (
            <div className="flex justify-between text-teal-700"><span>Impuesto ({taxPct}%):</span><span>{fmt(taxUSD, 'USD')}</span></div>
          )}
          <div className="flex justify-between text-base font-bold text-slate-900 border-t border-slate-100 pt-2">
            <span>Total USD:</span><span>{fmt(totalUSD, 'USD')}</span>
          </div>
          <div className="flex justify-between text-xs font-bold text-teal-700">
            <span>Total Bs. (BCV):</span><span>{fmt(totalUSD * rates.VES, 'VES')}</span>
          </div>
          <div className="flex justify-between text-xs font-bold text-amber-700">
            <span>Total COP:</span><span>{fmt(totalUSD * rates.COP, 'COP')}</span>
          </div>
        </div>

        <button onClick={checkout} className="w-full btn-primary justify-center py-3 shadow-lg shadow-teal-600/10">
          <CheckCircle className="w-4 h-4" /> Finalizar y Emitir Ticket
        </button>
      </div>

      {lastSale && <TicketModal venta={lastSale} onClose={() => setLastSale(null)} />}
    </div>
  )
}
EOF

# Módulo Ventas: Historial
cat > src/components/Ventas/HistorialVentas.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { fmt, formatDateTime } from '../../utils/helpers'
import TicketModal from '../UI/TicketModal'
import { Search, Eye, XCircle } from 'lucide-react'
import toast from 'react-hot-toast'

export default function HistorialVentas() {
  const [list, setList] = useState([])
  const [q, setQ] = useState('')
  const [ticket, setTicket] = useState(null)

  const load = async () => {
    const { data } = await supabase.from('ventas').select('*').order('created_at', { ascending: false })
    setList(data || [])
  }
  useEffect(() => { load() }, [])

  const anular = async (v) => {
    if (!confirm(`¿Desea anular la factura ${v.factura}?`)) return
    await supabase.from('ventas').update({ estado: 'anulada' }).eq('id', v.id)
    toast.success('Venta anulada')
    load()
  }

  const filtered = list.filter(v => `${v.factura} ${v.cliente}`.toLowerCase().includes(q.toLowerCase()))

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-xl font-bold text-slate-800">Historial de Ventas</h1>
        <p className="text-xs text-slate-400">Auditoría y reimpresión de comprobantes</p>
      </div>

      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input placeholder="Buscar por factura o cliente..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
      </div>

      <div className="card-pro p-0 overflow-hidden border">
        <table className="w-full text-left text-xs">
          <thead className="bg-slate-50 border-b border-slate-100 text-slate-500 font-bold uppercase">
            <tr>
              <th className="p-3.5">Factura</th>
              <th className="p-3.5">Cliente</th>
              <th className="p-3.5">Fecha</th>
              <th className="p-3.5">Total USD</th>
              <th className="p-3.5">Total Bs (BCV)</th>
              <th className="p-3.5">Total COP</th>
              <th className="p-3.5">Estado</th>
              <th className="p-3.5 text-right">Acciones</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {filtered.map(v => (
              <tr key={v.id} className={v.estado === 'anulada' ? 'opacity-50 bg-slate-50' : ''}>
                <td className="p-3.5 font-mono font-bold text-slate-800">{v.factura}</td>
                <td className="p-3.5">{v.cliente}</td>
                <td className="p-3.5 text-slate-400">{formatDateTime(v.created_at)}</td>
                <td className="p-3.5 font-bold text-teal-700">{fmt(v.total_usd, 'USD')}</td>
                <td className="p-3.5 font-semibold text-slate-600">{fmt(v.total_ves, 'VES')}</td>
                <td className="p-3.5 font-semibold text-amber-700">{fmt(v.total_cop, 'COP')}</td>
                <td className="p-3.5">
                  <span className={`badge ${v.estado === 'anulada' ? 'bg-rose-100 text-rose-700' : 'bg-emerald-100 text-emerald-700'}`}>
                    {v.estado}
                  </span>
                </td>
                <td className="p-3.5 text-right space-x-1">
                  <button onClick={() => setTicket(v)} className="p-1.5 hover:bg-slate-100 rounded-lg text-slate-600" title="Ver Ticket"><Eye className="w-4 h-4" /></button>
                  {v.estado !== 'anulada' && (
                    <button onClick={() => anular(v)} className="p-1.5 hover:bg-rose-50 rounded-lg text-rose-600" title="Anular"><XCircle className="w-4 h-4" /></button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {ticket && <TicketModal venta={ticket} onClose={() => setTicket(null)} />}
    </div>
  )
}
EOF

# Módulo Inventario
cat > src/components/Inventario/Inventario.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import PriceBox from '../UI/PriceBox'
import { Plus, AlertTriangle } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Inventario() {
  const [list, setList] = useState([])
  const [cats, setCats] = useState([])
  const [taxes, setTaxes] = useState([])
  const [modal, setModal] = useState(false)
  const [form, setForm] = useState({ nombre: '', codigo: '', stock: 10, stock_minimo: 5, precio_venta: '', categoria_id: '', impuesto_id: '' })

  const load = async () => {
    const [p, c, t] = await Promise.all([
      supabase.from('productos').select('*, categorias(nombre), impuestos(nombre, porcentaje)').eq('activo', true).order('nombre'),
      supabase.from('categorias').select('*'),
      supabase.from('impuestos').select('*')
    ])
    setList(p.data || []); setCats(c.data || []); setTaxes(t.data || [])
  }
  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    const payload = {
      ...form,
      categoria_id: form.categoria_id || null,
      impuesto_id: form.impuesto_id || null
    }
    await supabase.from('productos').insert([payload])
    toast.success('Insumo registrado')
    setModal(false); load()
  }

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Almacén de Insumos Dentales</h1>
          <p className="text-xs text-slate-400">Control de stock y precios de venta</p>
        </div>
        <button onClick={() => setModal(true)} className="btn-primary"><Plus className="w-4 h-4" /> Agregar Insumo</button>
      </div>

      <div className="card-pro p-0 overflow-hidden border">
        <table className="w-full text-left text-xs">
          <thead className="bg-slate-50 border-b border-slate-100 text-slate-500 font-bold uppercase">
            <tr>
              <th className="p-3.5">Código</th>
              <th className="p-3.5">Nombre del Insumo</th>
              <th className="p-3.5">Categoría</th>
              <th className="p-3.5">Stock</th>
              <th className="p-3.5">Impuesto</th>
              <th className="p-3.5">Precio de Venta</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {list.map(i => (
              <tr key={i.id} className="hover:bg-slate-50/50">
                <td className="p-3.5 font-mono text-slate-400">{i.codigo || '—'}</td>
                <td className="p-3.5 font-bold text-slate-800">{i.nombre}</td>
                <td className="p-3.5"><span className="badge bg-slate-100 text-slate-600">{i.categorias?.nombre || 'General'}</span></td>
                <td className="p-3.5 font-bold">
                  <span className={`inline-flex items-center gap-1 ${i.stock <= i.stock_minimo ? 'text-rose-600' : 'text-slate-700'}`}>
                    {i.stock} {i.stock <= i.stock_minimo && <AlertTriangle className="w-3.5 h-3.5" />}
                  </span>
                </td>
                <td className="p-3.5 text-slate-500">{i.impuestos ? `${i.impuestos.nombre}` : 'Exento'}</td>
                <td className="p-3.5"><PriceBox usd={i.precio_venta} showAll /></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {modal && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-4 shadow-2xl">
            <h2 className="font-bold text-base text-slate-800">Nuevo Insumo / Material</h2>
            <input required placeholder="Nombre (ej. Resina 3M Z250)" className="input-field" value={form.nombre} onChange={e => setForm({...form, nombre: e.target.value})} />
            <input placeholder="Código SKU" className="input-field" value={form.codigo} onChange={e => setForm({...form, codigo: e.target.value})} />
            <div className="grid grid-cols-2 gap-3">
              <select className="input-field" value={form.categoria_id} onChange={e => setForm({...form, categoria_id: e.target.value})}>
                <option value="">Categoría</option>
                {cats.map(c => <option key={c.id} value={c.id}>{c.nombre}</option>)}
              </select>
              <select className="input-field" value={form.impuesto_id} onChange={e => setForm({...form, impuesto_id: e.target.value})}>
                <option value="">Impuesto</option>
                {taxes.map(t => <option key={t.id} value={t.id}>{t.nombre} ({t.porcentaje}%)</option>)}
              </select>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <input required type="number" placeholder="Stock Inicial" className="input-field" value={form.stock} onChange={e => setForm({...form, stock: e.target.value})} />
              <input required type="number" step="0.01" placeholder="Precio ($ USD)" className="input-field" value={form.precio_venta} onChange={e => setForm({...form, precio_venta: e.target.value})} />
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <button type="button" onClick={() => setModal(false)} className="btn-secondary">Cancelar</button>
              <button type="submit" className="btn-primary">Guardar</button>
            </div>
          </form>
        </div>
      )}
    </div>
  )
}
EOF

# Módulo Configuración
cat > src/components/Configuracion/TasasImpuestos.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { DollarSign, Percent, Save, Plus } from 'lucide-react'
import toast from 'react-hot-toast'

export default function TasasImpuestos() {
  const { rates, setRates, loadData } = useCurrency()
  const [ves, setVes] = useState(rates.VES)
  const [cop, setCop] = useState(rates.COP)
  const [taxes, setTaxes] = useState([])
  const [newTax, setNewTax] = useState({ nombre: '', porcentaje: '' })

  const load = async () => {
    const { data } = await supabase.from('impuestos').select('*')
    setTaxes(data || [])
  }
  useEffect(() => { load() }, [])

  const saveRates = async (e) => {
    e.preventDefault()
    await supabase.from('tasas_cambio').upsert({ moneda: 'VES', tasa: ves, fuente: 'Manual' })
    await supabase.from('tasas_cambio').upsert({ moneda: 'COP', tasa: cop, fuente: 'Manual' })
    setRates({ VES: Number(ves), COP: Number(cop) })
    toast.success('Tasas de cambio guardadas correctamente')
  }

  const addTax = async (e) => {
    e.preventDefault()
    await supabase.from('impuestos').insert([newTax])
    toast.success('Nuevo impuesto agregado')
    setNewTax({ nombre: '', porcentaje: '' }); load(); loadData()
  }

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-xl font-bold text-slate-800">Ajustes Financieros</h1>
        <p className="text-xs text-slate-400">Tasas oficiales del día e impuestos aplicables</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Tasas */}
        <form onSubmit={saveRates} className="card-box space-y-4">
          <h2 className="font-bold text-sm text-slate-800 flex items-center gap-2">
            <DollarSign className="w-4 h-4 text-teal-600" /> Tasas de Cambio Manuales
          </h2>
          <div>
            <label className="text-xs font-semibold text-slate-600 block mb-1">Tasa Bolívares (VES por cada 1 USD)</label>
            <input type="number" step="0.01" className="input-field" value={ves} onChange={e => setVes(e.target.value)} />
          </div>
          <div>
            <label className="text-xs font-semibold text-slate-600 block mb-1">Tasa Pesos Colombianos (COP por cada 1 USD)</label>
            <input type="number" step="1" className="input-field" value={cop} onChange={e => setCop(e.target.value)} />
          </div>
          <button type="submit" className="btn-primary w-full justify-center">
            <Save className="w-4 h-4" /> Guardar Nuevas Tasas
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
                <span className="font-mono bg-teal-100 text-teal-800 px-2 py-0.5 rounded-full font-bold">{t.porcentaje}%</span>
              </div>
            ))}
          </div>
          <form onSubmit={addTax} className="flex gap-2 pt-2">
            <input required placeholder="Nombre (ej. IVA 19%)" className="input-field" value={newTax.nombre} onChange={e => setNewTax({...newTax, nombre: e.target.value})} />
            <input required type="number" placeholder="%" className="input-field w-20" value={newTax.porcentaje} onChange={e => setNewTax({...newTax, porcentaje: e.target.value})} />
            <button type="submit" className="btn-primary"><Plus className="w-4 h-4" /></button>
          </form>
        </div>
      </div>
    </div>
  )
}
EOF

# Router App
cat > src/App.jsx << 'EOF'
import { BrowserRouter, Routes, Route } from 'react-router-dom'
import { Toaster } from 'react-hot-toast'
import { AuthProvider, useAuth } from './context/AuthContext'
import { CurrencyProvider } from './context/CurrencyContext'
import Login from './components/Auth/Login'
import Shell from './components/Layout/Shell'
import Dashboard from './components/Dashboard/Dashboard'
import Pacientes from './components/Consultorio/Pacientes'
import Citas from './components/Consultorio/Citas'
import Historial from './components/Consultorio/Historial'
import Tratamientos from './components/Consultorio/Tratamientos'
import POS from './components/Ventas/POS'
import HistorialVentas from './components/Ventas/HistorialVentas'
import Inventario from './components/Inventario/Inventario'
import TasasImpuestos from './components/Configuracion/TasasImpuestos'

function RoutesWrapper() {
  const { auth, loading } = useAuth()
  if (loading) return null
  if (!auth) return <Login />

  return (
    <CurrencyProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Shell />}>
            <Route index element={<Dashboard />} />
            <Route path="pacientes" element={<Pacientes />} />
            <Route path="citas" element={<Citas />} />
            <Route path="historial" element={<Historial />} />
            <Route path="tratamientos" element={<Tratamientos />} />
            <Route path="pos" element={<POS />} />
            <Route path="ventas" element={<HistorialVentas />} />
            <Route path="inventario" element={<Inventario />} />
            <Route path="config" element={<TasasImpuestos />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </CurrencyProvider>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <RoutesWrapper />
      <Toaster position="top-right" />
    </AuthProvider>
  )
}
EOF

# Instalar paquetes
echo "📦 Instalando dependencias necesarias..."
npm install

echo "✅ ¡Sistema Odontológico Completo Generado con Éxito!"
