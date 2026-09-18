#!/bin/bash
set -e

echo "🦷 Instalando réplica de Inventario Odontológico..."

# Limpieza y estructura
mkdir -p public src/{components/{Auth,Layout,Consultorio,Ventas,Config,UI},context,lib,utils}

# package.json
cat > package.json << 'EOF'
{
  "name": "inventario-odontologia",
  "private": true,
  "version": "1.0.0",
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

# tailwind.config.js & postcss
cat > tailwind.config.js << 'EOF'
export default {
  content: ["./index.html", "./src/**/*.{js,jsx}"],
  theme: {
    extend: {
      colors: {
        dental: { 500: '#0d9488', 600: '#0f766e', 700: '#115e59' }
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
  <title>🦷 Sistema Odontológico - Consultorio & Insumos</title>
</head>
<body class="bg-slate-50 text-slate-900 font-sans"><div id="root"></div><script type="module" src="/src/main.jsx"></script></body>
</html>
EOF

# index.css
cat > src/index.css << 'EOF'
@tailwind base; @tailwind components; @tailwind utilities;
.btn-primary { @apply bg-teal-600 hover:bg-teal-700 text-white font-medium px-4 py-2 rounded-xl flex items-center gap-2 text-sm transition-all disabled:opacity-50; }
.btn-secondary { @apply bg-slate-100 hover:bg-slate-200 text-slate-700 font-medium px-4 py-2 rounded-xl flex items-center gap-2 text-sm transition-all; }
.input-field { @apply w-full px-3 py-2 bg-white border border-slate-200 rounded-xl focus:ring-2 focus:ring-teal-500 outline-none text-sm; }
.card-box { @apply bg-white rounded-2xl border border-slate-100 p-5 shadow-sm; }
EOF

# Libs & Utils
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
export const formatCurrency = (val, cur = 'USD') => {
  const n = Number(val || 0)
  if (cur === 'VES') return `Bs. ${n.toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
  if (cur === 'COP') return `COP ${n.toLocaleString('es-CO', { minimumFractionDigits: 0 })}`
  return `$ ${n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}
EOF

# Contexts
cat > src/context/AuthContext.jsx << 'EOF'
import { createContext, useContext, useState, useEffect } from 'react'
const AuthContext = createContext()
export function AuthProvider({ children }) {
  const [auth, setAuth] = useState(false)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const ok = localStorage.getItem('odonto_access_token')
    if (ok === 'authorized') setAuth(true)
    setLoading(false)
  }, [])

  const login = (pass) => {
    const valid = import.meta.env.VITE_APP_PASSWORD || 'admin123'
    if (pass === valid) {
      localStorage.setItem('odonto_access_token', 'authorized')
      setAuth(true)
      return true
    }
    return false
  }

  const logout = () => {
    localStorage.removeItem('odonto_access_token')
    setAuth(false)
  }

  return <AuthContext.Provider value={{ auth, loading, login, logout }}>{children}</AuthContext.Provider>
}
export const useAuth = () => useContext(AuthContext)
EOF

cat > src/context/CurrencyContext.jsx << 'EOF'
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
EOF

# Login Gatekeeper
cat > src/components/Auth/Login.jsx << 'EOF'
import { useState } from 'react'
import { useAuth } from '../../context/AuthContext'
import { Lock } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Login() {
  const [key, setKey] = useState('')
  const { login } = useAuth()

  const handle = (e) => {
    e.preventDefault()
    if (login(key)) toast.success('Acceso Autorizado')
    else { toast.error('Clave de acceso incorrecta'); setKey('') }
  }

  return (
    <div className="min-h-screen bg-slate-900 flex items-center justify-center p-4">
      <form onSubmit={handle} className="bg-white p-8 rounded-3xl w-full max-w-sm shadow-2xl space-y-6 text-center">
        <div className="w-16 h-16 bg-teal-100 text-teal-700 rounded-2xl flex items-center justify-center mx-auto text-3xl">🦷</div>
        <div>
          <h1 className="text-xl font-bold text-slate-800">Sistema Odontológico</h1>
          <p className="text-xs text-slate-400 mt-1">Consultorio & Ventas de Insumos</p>
        </div>
        <div className="text-left space-y-1">
          <label className="text-xs font-semibold text-slate-600">Clave de Acceso</label>
          <div className="flex items-center border rounded-xl px-3 py-2.5 bg-slate-50 focus-within:ring-2 focus-within:ring-teal-500">
            <Lock className="w-4 h-4 text-slate-400 mr-2" />
            <input type="password" placeholder="••••••••" value={key} onChange={e => setKey(e.target.value)} className="bg-transparent outline-none w-full text-sm" autoFocus />
          </div>
        </div>
        <button type="submit" className="w-full btn-primary justify-center py-3">Ingresar al Sistema</button>
      </form>
    </div>
  )
}
EOF

# Layout Principal
cat > src/components/Layout/Shell.jsx << 'EOF'
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
EOF

# MÓDULO 1: CONSULTORIO
cat > src/components/Consultorio/Pacientes.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { Plus, User, Search, Trash2 } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Pacientes() {
  const [list, setList] = useState([])
  const [q, setQ] = useState('')
  const [modal, setModal] = useState(false)
  const [form, setForm] = useState({ nombres: '', apellidos: '', cedula: '', telefono: '', alergias: '' })

  const load = async () => {
    const { data } = await supabase.from('pacientes').select('*').eq('activo', true).order('created_at', { ascending: false })
    setList(data || [])
  }
  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    await supabase.from('pacientes').insert([form])
    toast.success('Paciente registrado')
    setModal(false); setForm({ nombres: '', apellidos: '', cedula: '', telefono: '', alergias: '' }); load()
  }

  const del = async (id) => {
    if (confirm('¿Eliminar paciente?')) {
      await supabase.from('pacientes').update({ activo: false }).eq('id', id)
      toast.success('Paciente eliminado'); load()
    }
  }

  const filtered = list.filter(p => `${p.nombres} ${p.apellidos} ${p.cedula}`.toLowerCase().includes(q.toLowerCase()))

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <div><h1 className="text-xl font-bold">Pacientes del Consultorio</h1><p className="text-xs text-slate-400">Control clínico</p></div>
        <button onClick={() => setModal(true)} className="btn-primary"><Plus className="w-4 h-4" /> Nuevo Paciente</button>
      </div>

      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
        <input placeholder="Buscar por nombre o cédula..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-9" />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
        {filtered.map(p => (
          <div key={p.id} className="card-box space-y-2 relative">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-teal-50 text-teal-700 flex items-center justify-center font-bold"><User className="w-5 h-5" /></div>
              <div><h3 className="font-bold text-sm">{p.nombres} {p.apellidos}</h3><p className="text-xs text-slate-400">CI: {p.cedula || 'S/N'}</p></div>
            </div>
            <div className="text-xs space-y-1 text-slate-600 border-t pt-2">
              <p>📞 {p.telefono || 'Sin teléfono'}</p>
              <p className={p.alergias ? 'text-rose-600 font-bold' : ''}>⚠️ Alergias: {p.alergias || 'Ninguna'}</p>
            </div>
            <button onClick={() => del(p.id)} className="absolute top-4 right-4 text-slate-300 hover:text-rose-600"><Trash2 className="w-4 h-4" /></button>
          </div>
        ))}
      </div>

      {modal && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-3">
            <h2 className="font-bold text-base">Registrar Paciente</h2>
            <input required placeholder="Nombres" value={form.nombres} onChange={e => setForm({...form, nombres: e.target.value})} className="input-field" />
            <input required placeholder="Apellidos" value={form.apellidos} onChange={e => setForm({...form, apellidos: e.target.value})} className="input-field" />
            <input placeholder="Cédula" value={form.cedula} onChange={e => setForm({...form, cedula: e.target.value})} className="input-field" />
            <input placeholder="Teléfono" value={form.telefono} onChange={e => setForm({...form, telefono: e.target.value})} className="input-field" />
            <textarea placeholder="Alergias o condiciones" value={form.alergias} onChange={e => setForm({...form, alergias: e.target.value})} className="input-field" rows={2} />
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

cat > src/components/Consultorio/Citas.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { Plus, Check, X } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Citas() {
  const [citas, setCitas] = useState([])
  const [pacs, setPacs] = useState([])
  const [modal, setModal] = useState(false)
  const [form, setForm] = useState({ paciente_id: '', fecha: '', notas: '' })

  const load = async () => {
    const [c, p] = await Promise.all([
      supabase.from('citas').select('*, pacientes(nombres, apellidos)').order('fecha', { ascending: true }),
      supabase.from('pacientes').select('id, nombres, apellidos').eq('activo', true)
    ])
    setCitas(c.data || []); setPacs(p.data || [])
  }
  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    await supabase.from('citas').insert([form])
    toast.success('Cita programada')
    setModal(false); load()
  }

  const setStatus = async (id, estado) => {
    await supabase.from('citas').update({ estado }).eq('id', id)
    toast.success(`Cita: ${estado}`)
    load()
  }

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <div><h1 className="text-xl font-bold">Agenda Odontológica</h1><p className="text-xs text-slate-400">Control de citas</p></div>
        <button onClick={() => setModal(true)} className="btn-primary"><Plus className="w-4 h-4" /> Nueva Cita</button>
      </div>

      <div className="space-y-2">
        {citas.map(c => (
          <div key={c.id} className="card-box flex items-center justify-between p-4">
            <div>
              <h3 className="font-bold text-sm">{c.pacientes?.nombres} {c.pacientes?.apellidos}</h3>
              <p className="text-xs text-slate-500">📅 {new Date(c.fecha).toLocaleString()}</p>
              {c.notas && <p className="text-xs text-slate-400 mt-1">{c.notas}</p>}
            </div>
            <div className="flex items-center gap-2">
              <span className={`text-[10px] font-bold px-2.5 py-1 rounded-full uppercase ${c.estado === 'completada' ? 'bg-emerald-100 text-emerald-800' : c.estado === 'cancelada' ? 'bg-rose-100 text-rose-800' : 'bg-blue-100 text-blue-800'}`}>{c.estado}</span>
              {c.estado === 'programada' && (
                <>
                  <button onClick={() => setStatus(c.id, 'completada')} className="p-1.5 bg-emerald-50 text-emerald-600 rounded-lg"><Check className="w-4 h-4" /></button>
                  <button onClick={() => setStatus(c.id, 'cancelada')} className="p-1.5 bg-rose-50 text-rose-600 rounded-lg"><X className="w-4 h-4" /></button>
                </>
              )}
            </div>
          </div>
        ))}
      </div>

      {modal && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-3">
            <h2 className="font-bold text-base">Programar Cita</h2>
            <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
              <option value="">Seleccione Paciente</option>
              {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
            </select>
            <input required type="datetime-local" className="input-field" value={form.fecha} onChange={e => setForm({...form, fecha: e.target.value})} />
            <textarea placeholder="Motivo de la consulta" className="input-field" value={form.notas} onChange={e => setForm({...form, notas: e.target.value})} />
            <div className="flex justify-end gap-2 pt-2"><button type="button" onClick={() => setModal(false)} className="btn-secondary">Cancelar</button><button type="submit" className="btn-primary">Programar</button></div>
          </form>
        </div>
      )}
    </div>
  )
}
EOF

cat > src/components/Consultorio/Historial.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { formatCurrency } from '../../utils/helpers'
import { Plus } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Historial() {
  const [list, setList] = useState([])
  const [pacs, setPacs] = useState([])
  const [modal, setModal] = useState(false)
  const [form, setForm] = useState({ paciente_id: '', diagnostico: '', procedimiento: '', monto_usd: 0 })

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
    toast.success('Procedimiento guardado')
    setModal(false); load()
  }

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <div><h1 className="text-xl font-bold">Historial Clínico</h1><p className="text-xs text-slate-400">Consultas y procedimientos</p></div>
        <button onClick={() => setModal(true)} className="btn-primary"><Plus className="w-4 h-4" /> Registrar Consulta</button>
      </div>

      <div className="space-y-3">
        {list.map(h => (
          <div key={h.id} className="card-box flex justify-between items-center p-4">
            <div>
              <h3 className="font-bold text-sm">{h.pacientes?.nombres} {h.pacientes?.apellidos}</h3>
              <p className="text-xs text-slate-600 font-semibold">{h.procedimiento}</p>
              <p className="text-xs text-slate-400">Dx: {h.diagnostico}</p>
            </div>
            <div className="text-right">
              <span className="font-bold text-sm text-teal-700">{formatCurrency(h.monto_usd)}</span>
              <p className="text-[10px] text-slate-400">{new Date(h.fecha).toLocaleDateString()}</p>
            </div>
          </div>
        ))}
      </div>

      {modal && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-3">
            <h2 className="font-bold text-base">Registrar Consulta</h2>
            <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
              <option value="">Seleccione Paciente</option>
              {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
            </select>
            <input required placeholder="Procedimiento (ej. Limpieza, Resina)" className="input-field" value={form.procedimiento} onChange={e => setForm({...form, procedimiento: e.target.value})} />
            <textarea placeholder="Diagnóstico clínico" className="input-field" value={form.diagnostico} onChange={e => setForm({...form, diagnostico: e.target.value})} />
            <input type="number" step="0.01" placeholder="Monto cobrado ($)" className="input-field" value={form.monto_usd} onChange={e => setForm({...form, monto_usd: e.target.value})} />
            <div className="flex justify-end gap-2 pt-2"><button type="button" onClick={() => setModal(false)} className="btn-secondary">Cancelar</button><button type="submit" className="btn-primary">Guardar</button></div>
          </form>
        </div>
      )}
    </div>
  )
}
EOF

cat > src/components/Consultorio/Tratamientos.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { formatCurrency } from '../../utils/helpers'
import { Plus } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Tratamientos() {
  const [list, setList] = useState([])
  const { rates } = useCurrency()
  const [modal, setModal] = useState(false)
  const [form, setForm] = useState({ nombre: '', precio: '' })

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
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <div><h1 className="text-xl font-bold">Catálogo de Tratamientos</h1><p className="text-xs text-slate-400">Precios en todas las monedas</p></div>
        <button onClick={() => setModal(true)} className="btn-primary"><Plus className="w-4 h-4" /> Nuevo Tratamiento</button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
        {list.map(t => (
          <div key={t.id} className="card-box space-y-2">
            <h3 className="font-bold text-sm">{t.nombre}</h3>
            <div className="pt-2 border-t text-xs space-y-1">
              <p className="font-bold text-teal-700 text-base">{formatCurrency(t.precio, 'USD')}</p>
              <p className="text-slate-500 font-semibold">{formatCurrency(t.precio * rates.VES, 'VES')}</p>
              <p className="text-amber-700 font-semibold">{formatCurrency(t.precio * rates.COP, 'COP')}</p>
            </div>
          </div>
        ))}
      </div>

      {modal && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-3">
            <h2 className="font-bold text-base">Crear Tratamiento</h2>
            <input required placeholder="Nombre (ej. Extracción Simple)" className="input-field" value={form.nombre} onChange={e => setForm({...form, nombre: e.target.value})} />
            <input required type="number" step="0.01" placeholder="Precio ($ USD)" className="input-field" value={form.precio} onChange={e => setForm({...form, precio: e.target.value})} />
            <div className="flex justify-end gap-2 pt-2"><button type="button" onClick={() => setModal(false)} className="btn-secondary">Cancelar</button><button type="submit" className="btn-primary">Guardar</button></div>
          </form>
        </div>
      )}
    </div>
  )
}
EOF

# MÓDULO 2: INSUMOS & VENTAS
cat > src/components/Ventas/POS.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { formatCurrency } from '../../utils/helpers'
import { ShoppingCart, Trash2, Check } from 'lucide-react'
import toast from 'react-hot-toast'

export default function POS() {
  const [prods, setProds] = useState([])
  const [cart, setCart] = useState([])
  const [client, setClient] = useState('')
  const { rates } = useCurrency()

  const load = async () => {
    const { data } = await supabase.from('productos').select('*, impuestos(porcentaje)').eq('activo', true).eq('es_vendible', true).gt('stock', 0)
    setProds(data || [])
  }
  useEffect(() => { load() }, [])

  const add = (p) => {
    const ex = cart.find(i => i.id === p.id)
    if (ex) {
      if (ex.cant >= p.stock) return toast.error('Sin stock suficiente')
      setCart(cart.map(i => i.id === p.id ? { ...i, cant: i.cant + 1 } : i))
    } else {
      setCart([...cart, { ...p, cant: 1, taxPct: p.impuestos?.porcentaje || 0 }])
    }
  }

  const subtotal = cart.reduce((acc, i) => acc + (i.precio_venta * i.cant), 0)
  const totalTax = cart.reduce((acc, i) => acc + (i.precio_venta * i.cant * (i.taxPct / 100)), 0)
  const totalUSD = subtotal + totalTax

  const checkout = async () => {
    if (!cart.length) return toast.error('Carrito vacío')
    const fac = `FAC-${Date.now().toString().slice(-6)}`

    const { error } = await supabase.from('ventas').insert([{
      factura: fac,
      cliente: client || 'Cliente General',
      subtotal_usd: subtotal,
      impuesto_usd: totalTax,
      total_usd: totalUSD,
      total_ves: totalUSD * rates.VES,
      total_cop: totalUSD * rates.COP,
      tasa_ves: rates.VES,
      tasa_cop: rates.COP
    }])

    if (error) return toast.error('Error procesando venta')

    for (const item of cart) {
      await supabase.from('productos').update({ stock: item.stock - item.cant }).eq('id', item.id)
    }

    toast.success(`¡Venta ${fac} procesada!`)
    setCart([]); setClient(''); load()
  }

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <div className="lg:col-span-2 space-y-4">
        <h1 className="text-xl font-bold">Punto de Venta de Insumos</h1>
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
          {prods.map(p => (
            <button key={p.id} onClick={() => add(p)} className="card-box text-left p-3 hover:border-teal-500 transition-all">
              <h4 className="font-bold text-xs truncate">{p.nombre}</h4>
              <p className="text-[10px] text-slate-400">Stock: {p.stock}</p>
              <p className="font-bold text-sm text-teal-700 mt-2">{formatCurrency(p.precio_venta)}</p>
            </button>
          ))}
        </div>
      </div>

      <div className="card-box space-y-4 h-fit">
        <h2 className="font-bold text-sm flex items-center gap-2 border-b pb-3"><ShoppingCart className="w-4 h-4" /> Carrito</h2>
        <input placeholder="Nombre del cliente" value={client} onChange={e => setClient(e.target.value)} className="input-field" />

        <div className="space-y-2 max-h-56 overflow-y-auto">
          {cart.map(i => (
            <div key={i.id} className="flex justify-between items-center text-xs bg-slate-50 p-2 rounded-xl">
              <div><p className="font-bold truncate w-28">{i.nombre}</p><span className="text-slate-400">{formatCurrency(i.precio_venta)} x {i.cant}</span></div>
              <button onClick={() => setCart(cart.filter(x => x.id !== i.id))} className="text-rose-500"><Trash2 className="w-4 h-4" /></button>
            </div>
          ))}
        </div>

        <div className="border-t pt-3 space-y-1 text-xs">
          <div className="flex justify-between text-slate-500"><span>Subtotal:</span><span>{formatCurrency(subtotal)}</span></div>
          <div className="flex justify-between text-slate-500"><span>Impuestos:</span><span>{formatCurrency(totalTax)}</span></div>
          <div className="flex justify-between text-base font-bold text-teal-900 border-t pt-2"><span>Total USD:</span><span>{formatCurrency(totalUSD, 'USD')}</span></div>
          <div className="flex justify-between text-xs font-bold text-slate-600"><span>Total Bs. (BCV):</span><span>{formatCurrency(totalUSD * rates.VES, 'VES')}</span></div>
          <div className="flex justify-between text-xs font-bold text-amber-700"><span>Total COP:</span><span>{formatCurrency(totalUSD * rates.COP, 'COP')}</span></div>
        </div>

        <button onClick={checkout} className="w-full btn-primary justify-center py-3"><Check className="w-4 h-4" /> Finalizar Venta</button>
      </div>
    </div>
  )
}
EOF

cat > src/components/Ventas/Inventario.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { formatCurrency } from '../../utils/helpers'
import { Plus } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Inventario() {
  const [list, setList] = useState([])
  const [taxes, setTaxes] = useState([])
  const [modal, setModal] = useState(false)
  const [form, setForm] = useState({ nombre: '', codigo: '', stock: 10, stock_minimo: 5, precio_venta: '', impuesto_id: '' })

  const load = async () => {
    const [p, t] = await Promise.all([
      supabase.from('productos').select('*, impuestos(nombre, porcentaje)').eq('activo', true),
      supabase.from('impuestos').select('*').eq('activo', true)
    ])
    setList(p.data || []); setTaxes(t.data || [])
  }
  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    const dataToSave = { ...form, impuesto_id: form.impuesto_id || null }
    await supabase.from('productos').insert([dataToSave])
    toast.success('Insumo guardado')
    setModal(false); load()
  }

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <div><h1 className="text-xl font-bold">Inventario de Insumos Dentales</h1><p className="text-xs text-slate-400">Existencias y stock</p></div>
        <button onClick={() => setModal(true)} className="btn-primary"><Plus className="w-4 h-4" /> Nuevo Insumo</button>
      </div>

      <div className="overflow-x-auto card-box p-0 border">
        <table className="w-full text-left text-xs">
          <thead className="bg-slate-50 border-b text-slate-500 uppercase">
            <tr><th className="p-3">Código</th><th className="p-3">Insumo</th><th className="p-3">Stock</th><th className="p-3">Impuesto</th><th className="p-3">Precio USD</th></tr>
          </thead>
          <tbody className="divide-y">
            {list.map(i => (
              <tr key={i.id} className="hover:bg-slate-50">
                <td className="p-3 font-mono">{i.codigo || '—'}</td>
                <td className="p-3 font-bold">{i.nombre}</td>
                <td className="p-3 font-bold">{i.stock}</td>
                <td className="p-3">{i.impuestos ? `${i.impuestos.nombre} (${i.impuestos.porcentaje}%)` : 'Exento'}</td>
                <td className="p-3 font-bold text-teal-700">{formatCurrency(i.precio_venta)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {modal && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-3">
            <h2 className="font-bold text-base">Nuevo Insumo</h2>
            <input required placeholder="Nombre (ej. Resina 3M Z250)" className="input-field" value={form.nombre} onChange={e => setForm({...form, nombre: e.target.value})} />
            <input placeholder="Código / SKU" className="input-field" value={form.codigo} onChange={e => setForm({...form, codigo: e.target.value})} />
            <select className="input-field" value={form.impuesto_id} onChange={e => setForm({...form, impuesto_id: e.target.value})}>
              <option value="">Seleccione Impuesto</option>
              {taxes.map(t => <option key={t.id} value={t.id}>{t.nombre} ({t.porcentaje}%)</option>)}
            </select>
            <div className="grid grid-cols-2 gap-2">
              <input required type="number" placeholder="Stock" className="input-field" value={form.stock} onChange={e => setForm({...form, stock: e.target.value})} />
              <input required type="number" step="0.01" placeholder="Precio Venta ($)" className="input-field" value={form.precio_venta} onChange={e => setForm({...form, precio_venta: e.target.value})} />
            </div>
            <div className="flex justify-end gap-2 pt-2"><button type="button" onClick={() => setModal(false)} className="btn-secondary">Cancelar</button><button type="submit" className="btn-primary">Guardar</button></div>
          </form>
        </div>
      )}
    </div>
  )
}
EOF

# MÓDULO 3: CONFIGURACIÓN TASAS E IMPUESTOS
cat > src/components/Config/Configuracion.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import toast from 'react-hot-toast'

export default function Configuracion() {
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
    toast.success('Tasas de cambio actualizadas')
  }

  const addTax = async (e) => {
    e.preventDefault()
    await supabase.from('impuestos').insert([newTax])
    toast.success('Impuesto añadido')
    setNewTax({ nombre: '', porcentaje: '' }); load(); loadData()
  }

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
      <form onSubmit={saveRates} className="card-box space-y-4">
        <h2 className="font-bold text-base">Tasas de Cambio Oficiales</h2>
        <div>
          <label className="text-xs font-semibold block mb-1">Tasa Bolívares (VES por USD)</label>
          <input type="number" step="0.01" className="input-field" value={ves} onChange={e => setVes(e.target.value)} />
        </div>
        <div>
          <label className="text-xs font-semibold block mb-1">Tasa Pesos Colombianos (COP por USD)</label>
          <input type="number" step="1" className="input-field" value={cop} onChange={e => setCop(e.target.value)} />
        </div>
        <button type="submit" className="btn-primary">Guardar Tasas</button>
      </form>

      <div className="card-box space-y-4">
        <h2 className="font-bold text-base">Impuestos y Retenciones</h2>
        <div className="space-y-2">
          {taxes.map(t => (
            <div key={t.id} className="flex justify-between items-center text-xs p-2 bg-slate-50 rounded-xl">
              <span className="font-bold">{t.nombre}</span>
              <span className="font-mono bg-teal-100 text-teal-800 px-2 py-0.5 rounded-full font-bold">{t.porcentaje}%</span>
            </div>
          ))}
        </div>
        <form onSubmit={addTax} className="flex gap-2 pt-2">
          <input required placeholder="Impuesto (ej. IVA 16%)" className="input-field" value={newTax.nombre} onChange={e => setNewTax({...newTax, nombre: e.target.value})} />
          <input required type="number" placeholder="%" className="input-field w-24" value={newTax.porcentaje} onChange={e => setNewTax({...newTax, porcentaje: e.target.value})} />
          <button type="submit" className="btn-primary">Añadir</button>
        </form>
      </div>
    </div>
  )
}
EOF

# App Routing
cat > src/App.jsx << 'EOF'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { Toaster } from 'react-hot-toast'
import { AuthProvider, useAuth } from './context/AuthContext'
import { CurrencyProvider } from './context/CurrencyContext'
import Login from './components/Auth/Login'
import Shell from './components/Layout/Shell'
import Pacientes from './components/Consultorio/Pacientes'
import Citas from './components/Consultorio/Citas'
import Historial from './components/Consultorio/Historial'
import Tratamientos from './components/Consultorio/Tratamientos'
import POS from './components/Ventas/POS'
import Inventario from './components/Ventas/Inventario'
import Configuracion from './components/Config/Configuracion'

function AppContent() {
  const { auth, loading } = useAuth()
  if (loading) return null
  if (!auth) return <Login />

  return (
    <CurrencyProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Shell />}>
            <Route index element={<Navigate to="/pacientes" replace />} />
            <Route path="pacientes" element={<Pacientes />} />
            <Route path="citas" element={<Citas />} />
            <Route path="historial" element={<Historial />} />
            <Route path="tratamientos" element={<Tratamientos />} />
            <Route path="pos" element={<POS />} />
            <Route path="inventario" element={<Inventario />} />
            <Route path="config" element={<Configuracion />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </CurrencyProvider>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <AppContent />
      <Toaster position="top-right" />
    </AuthProvider>
  )
}
EOF

# Instalación de paquetes
echo "📦 Instalando dependencias en Codespace..."
npm install

echo "✅ ¡Sistema configurado con éxito!"
