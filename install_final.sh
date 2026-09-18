#!/bin/bash
set -e

echo "🦷 Instalando Sistema Odontológico Definitivo..."

# Limpieza completa de src
rm -rf src/components src/context src/lib src/utils 2>/dev/null || true
mkdir -p public src/{components/{Auth,Layout,Dashboard,Consultorio,Ventas,Inventario,Configuracion,UI},context,lib,utils}

# 1. package.json con todas las dependencias
cat > package.json << 'EOF'
{
  "name": "sistema-odontologico-master",
  "private": true,
  "version": "4.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite --host 0.0.0.0",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "@supabase/supabase-js": "^2.48.1",
    "html5-qrcode": "^2.3.8",
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

# 2. Vite Config
cat > vite.config.js << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
export default defineConfig({ plugins: [react()], server: { host: '0.0.0.0', port: 5173 } })
EOF

# 3. Tailwind Config
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
  <title>DentalSys Pro - Consultorio & Insumos</title>
</head>
<body class="bg-slate-50 text-slate-900 font-sans antialiased">
  <div id="root"></div>
  <script type="module" src="/src/main.jsx"></script>
</body>
</html>
EOF

# 4. Estilos Globales
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

# 5. Core Libs y Utils
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
EOF

# 6. Contexto de Autenticación
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

# 7. Contexto de Monedas y Tasas BCV / COP
cat > src/context/CurrencyContext.jsx << 'EOF'
import { createContext, useContext, useState, useEffect, useCallback } from 'react'
import { supabase } from '../lib/supabase'
import toast from 'react-hot-toast'

const CurrencyContext = createContext()

export function CurrencyProvider({ children }) {
  const [rates, setRates] = useState({ VES: 65, COP: 4200 })
  const [taxes, setTaxes] = useState([])
  const [activeCur, setActiveCur] = useState('USD') // USD | VES | COP
  const [loadingRates, setLoadingRates] = useState(false)

  const fetchBCVReal = async () => {
    try {
      const res = await fetch('https://ve.dolarapi.com/v1/dolares/oficial')
      if (res.ok) {
        const data = await res.json()
        if (data?.promedio) return Number(data.promedio)
      }
    } catch {}
    return null
  }

  const fetchCOPReal = async () => {
    try {
      const res = await fetch('https://co.dolarapi.com/v1/dolares/oficial')
      if (res.ok) {
        const data = await res.json()
        if (data?.promedio) return Number(data.promedio)
      }
    } catch {}
    return null
  }

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
        await supabase.from('tasas_cambio').upsert({ moneda: 'COP', tasa: copRate, fuente: 'TRM Colombia' })
      }

      setRates(prev => ({ ...prev, ...updated }))
      if (notify) toast.success(`Tasas actualizadas: BCV Bs. ${updated.VES || rates.VES} | COP $${updated.COP || rates.COP}`)
    } catch {
      if (notify) toast.error('Error al sincronizar tasas oficiales')
    } finally {
      setLoadingRates(false)
    }
  }, [rates])

  const loadData = useCallback(async () => {
    const [tRes, iRes] = await Promise.all([
      supabase.from('tasas_cambio').select('*'),
      supabase.from('impuestos').select('*').eq('activo', true)
    ])

    const r = { VES: 65, COP: 4200 }
    if (tRes.data?.length > 0) {
      tRes.data.forEach(t => {
        if (t.moneda === 'VES') r.VES = Number(t.tasa)
        if (t.moneda === 'COP') r.COP = Number(t.tasa)
      })
      setRates(r)
    }
    if (iRes.data) setTaxes(iRes.data)
    syncOfficialRates(false)
  }, [syncOfficialRates])

  useEffect(() => { loadData() }, [loadData])

  return (
    <CurrencyContext.Provider value={{ rates, setRates, taxes, activeCur, setActiveCur, syncOfficialRates, loadingRates, loadData }}>
      {children}
    </CurrencyContext.Provider>
  )
}

export const useCurrency = () => useContext(CurrencyContext)
EOF

# 8. UI Helpers (Precios, Scanner, Ticket)
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

cat > src/components/UI/QRScanner.jsx << 'EOF'
import { useEffect } from 'react'
import { Html5QrcodeScanner } from 'html5-qrcode'
import { X } from 'lucide-react'

export default function QRScanner({ onScan, onClose }) {
  useEffect(() => {
    const scanner = new Html5QrcodeScanner(
      'qr-reader-box',
      { fps: 15, qrbox: { width: 220, height: 220 }, aspectRatio: 1.0 },
      false
    )

    scanner.render(
      (text) => {
        scanner.clear().then(() => onScan(text)).catch(() => onScan(text))
      },
      () => {}
    )

    return () => {
      scanner.clear().catch(() => {})
    }
  }, [onScan])

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-3xl p-6 w-full max-w-md shadow-2xl space-y-4">
        <div className="flex justify-between items-center border-b pb-2">
          <h3 className="font-bold text-sm text-slate-800">Cámara Escáner QR de Insumo</h3>
          <button onClick={onClose} className="p-1 hover:bg-slate-100 rounded-lg text-slate-500"><X className="w-4 h-4" /></button>
        </div>
        <div id="qr-reader-box" className="overflow-hidden rounded-2xl border border-slate-100"></div>
        <p className="text-[11px] text-slate-400 text-center">Coloca el código QR del material frente a la cámara.</p>
      </div>
    </div>
  )
}
EOF

# 9. ODONTOGRAMA INTERACTIVO (Componente Profesional de 32 dientes)
cat > src/components/Consultorio/Odontograma.jsx << 'EOF'
import React from 'react'

const dientesSuperiores = ['18','17','16','15','14','13','12','11', '21','22','23','24','25','26','27','28']
const dientesInferiores = ['48','47','46','45','44','43','42','41', '31','32','33','34','35','36','37','38']

export default function Odontograma({ selected = [], onChange }) {
  const toggleDiente = (num) => {
    if (selected.includes(num)) {
      onChange(selected.filter(d => d !== num))
    } else {
      onChange([...selected, num])
    }
  }

  return (
    <div className="bg-slate-50 p-4 rounded-2xl border border-slate-200 space-y-3">
      <div className="flex justify-between items-center text-xs text-slate-500 font-bold border-b pb-2">
        <span>ODONTOGRAMA (Seleccione Dientes Tratados)</span>
        <span className="text-teal-600 font-mono">{selected.length ? selected.join(', ') : 'Ninguno seleccionado'}</span>
      </div>

      <div className="space-y-2 text-center">
        {/* Arcada Superior */}
        <div>
          <p className="text-[10px] text-slate-400 uppercase font-semibold mb-1">Arcada Superior</p>
          <div className="flex flex-wrap justify-center gap-1">
            {dientesSuperiores.map(num => {
              const isSel = selected.includes(num)
              return (
                <button
                  type="button"
                  key={num}
                  onClick={() => toggleDiente(num)}
                  className={`w-7 h-9 rounded-lg text-[10px] font-bold border transition-all flex flex-col items-center justify-between p-1 ${
                    isSel ? 'bg-teal-600 text-white border-teal-700 shadow-md scale-105' : 'bg-white text-slate-700 border-slate-200 hover:border-teal-300'
                  }`}
                >
                  <span>{num}</span>
                  <div className={`w-3 h-3 rounded-full border ${isSel ? 'bg-white' : 'bg-slate-100'}`} />
                </button>
              )
            })}
          </div>
        </div>

        {/* Arcada Inferior */}
        <div>
          <p className="text-[10px] text-slate-400 uppercase font-semibold mb-1">Arcada Inferior</p>
          <div className="flex flex-wrap justify-center gap-1">
            {dientesInferiores.map(num => {
              const isSel = selected.includes(num)
              return (
                <button
                  type="button"
                  key={num}
                  onClick={() => toggleDiente(num)}
                  className={`w-7 h-9 rounded-lg text-[10px] font-bold border transition-all flex flex-col items-center justify-between p-1 ${
                    isSel ? 'bg-teal-600 text-white border-teal-700 shadow-md scale-105' : 'bg-white text-slate-700 border-slate-200 hover:border-teal-300'
                  }`}
                >
                  <div className={`w-3 h-3 rounded-full border ${isSel ? 'bg-white' : 'bg-slate-100'}`} />
                  <span>{num}</span>
                </button>
              )
            })}
          </div>
        </div>
      </div>
    </div>
  )
}
EOF

# 10. PACIENTES
cat > src/components/Consultorio/Pacientes.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { Plus, Search, Trash2, Phone, Mail, AlertTriangle, User, ChevronDown, ChevronUp, Save, X, Edit3 } from 'lucide-react'
import toast from 'react-hot-toast'

const calcEdad = f => { if (!f) return null; const h = new Date(), n = new Date(f); let e = h.getFullYear() - n.getFullYear(); if (h.getMonth() < n.getMonth() || (h.getMonth() === n.getMonth() && h.getDate() < n.getDate())) e--; return e }
const ini = (n, a) => `${(n||'?')[0]}${(a||'?')[0]}`.toUpperCase()
const cols = ['bg-teal-500','bg-blue-500','bg-violet-500','bg-rose-500','bg-amber-500','bg-emerald-500','bg-indigo-500']
const gc = id => cols[Math.abs((id||'a').charCodeAt(0)) % cols.length]
const blank = { nombres:'', apellidos:'', cedula:'', telefono:'', email:'', fecha_nacimiento:'', alergias:'', antecedentes:'' }

export default function Pacientes() {
  const [list, setList] = useState([])
  const [q, setQ] = useState('')
  const [showForm, setShowForm] = useState(false)
  const [editId, setEditId] = useState(null)
  const [expanded, setExpanded] = useState(null)
  const [form, setForm] = useState(blank)

  const load = async () => {
    const { data } = await supabase.from('pacientes').select('*').eq('activo', true).order('created_at', { ascending: false })
    setList(data || [])
  }
  useEffect(() => { load() }, [])

  const save = async e => {
    e.preventDefault()
    if (editId) {
      await supabase.from('pacientes').update(form).eq('id', editId)
      toast.success('Paciente actualizado')
    } else {
      await supabase.from('pacientes').insert([form])
      toast.success('Paciente registrado')
    }
    setShowForm(false); setEditId(null); setForm(blank); load()
  }

  const startEdit = p => {
    setForm({ nombres: p.nombres, apellidos: p.apellidos, cedula: p.cedula||'', telefono: p.telefono||'', email: p.email||'', fecha_nacimiento: p.fecha_nacimiento||'', alergias: p.alergias||'', antecedentes: p.antecedentes||'' })
    setEditId(p.id); setShowForm(true); setExpanded(null)
  }

  const del = async id => {
    if (!confirm('¿Desactivar paciente?')) return
    await supabase.from('pacientes').update({ activo: false }).eq('id', id)
    toast.success('Paciente desactivado'); setExpanded(null); load()
  }

  const filtered = list.filter(p => `${p.nombres} ${p.apellidos} ${p.cedula} ${p.telefono}`.toLowerCase().includes(q.toLowerCase()))

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div><h1 className="text-xl font-bold text-slate-800">Expedientes de Pacientes</h1><p className="text-xs text-slate-400">{list.length} pacientes activos</p></div>
        <button onClick={() => { setShowForm(!showForm); setEditId(null); setForm(blank) }} className={showForm ? 'btn-secondary' : 'btn-primary'}>
          {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Nuevo Paciente</>}
        </button>
      </div>

      {showForm && (
        <form onSubmit={save} className="card-box space-y-3 border-2 border-teal-200 bg-teal-50/20">
          <h3 className="font-bold text-sm text-teal-800">{editId ? 'Editar Paciente' : 'Registrar Nuevo Paciente'}</h3>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Nombres *</label><input required className="input-field" value={form.nombres} onChange={e => setForm({...form, nombres: e.target.value})} placeholder="María" /></div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Apellidos *</label><input required className="input-field" value={form.apellidos} onChange={e => setForm({...form, apellidos: e.target.value})} placeholder="González" /></div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Cédula</label><input className="input-field" value={form.cedula} onChange={e => setForm({...form, cedula: e.target.value})} placeholder="V-12345678" /></div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Nacimiento</label><input type="date" className="input-field" value={form.fecha_nacimiento} onChange={e => setForm({...form, fecha_nacimiento: e.target.value})} /></div>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Teléfono</label><input className="input-field" value={form.telefono} onChange={e => setForm({...form, telefono: e.target.value})} placeholder="0412-1234567" /></div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Email</label><input type="email" className="input-field" value={form.email} onChange={e => setForm({...form, email: e.target.value})} placeholder="correo@email.com" /></div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">⚠️ Alergias</label><input className="input-field" value={form.alergias} onChange={e => setForm({...form, alergias: e.target.value})} placeholder="Penicilina, Látex..." /></div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">🏥 Antecedentes</label><input className="input-field" value={form.antecedentes} onChange={e => setForm({...form, antecedentes: e.target.value})} placeholder="Diabetes, HTA..." /></div>
          </div>
          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> {editId ? 'Actualizar' : 'Guardar Paciente'}</button>
            <button type="button" onClick={() => { setShowForm(false); setEditId(null) }} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input placeholder="Buscar por nombre, cédula o teléfono..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
      </div>

      <div className="space-y-2">
        {filtered.map(p => (
          <div key={p.id} className="card-box p-0 overflow-hidden">
            <button onClick={() => setExpanded(expanded === p.id ? null : p.id)} className="w-full flex items-center justify-between p-4 hover:bg-slate-50 transition-all text-left">
              <div className="flex items-center gap-3">
                <div className={`w-10 h-10 rounded-xl ${gc(p.id)} text-white flex items-center justify-center font-bold text-sm`}>{ini(p.nombres, p.apellidos)}</div>
                <div>
                  <h3 className="font-bold text-sm text-slate-800">{p.nombres} {p.apellidos}</h3>
                  <p className="text-[11px] text-slate-400">{p.cedula || 'Sin cédula'} {calcEdad(p.fecha_nacimiento) ? `• ${calcEdad(p.fecha_nacimiento)} años` : ''}</p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                {p.alergias && <span className="badge bg-rose-100 text-rose-700 text-[10px]"><AlertTriangle className="w-3 h-3" /> Alergias</span>}
                <span className="text-xs text-slate-400 flex items-center gap-1"><Phone className="w-3 h-3" /> {p.telefono || '—'}</span>
                {expanded === p.id ? <ChevronUp className="w-4 h-4 text-slate-400" /> : <ChevronDown className="w-4 h-4 text-slate-400" />}
              </div>
            </button>

            {expanded === p.id && (
              <div className="border-t bg-slate-50 p-4 space-y-3">
                <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-xs">
                  <div><p className="text-slate-400 font-semibold">Teléfono</p><p className="font-bold text-slate-700">{p.telefono || '—'}</p></div>
                  <div><p className="text-slate-400 font-semibold">Email</p><p className="font-bold text-slate-700">{p.email || '—'}</p></div>
                  <div><p className="text-slate-400 font-semibold">Nacimiento</p><p className="font-bold text-slate-700">{p.fecha_nacimiento ? new Date(p.fecha_nacimiento).toLocaleDateString('es-VE') : '—'}</p></div>
                  <div><p className="text-slate-400 font-semibold">Cédula</p><p className="font-bold text-slate-700">{p.cedula || '—'}</p></div>
                </div>

                {p.alergias && (
                  <div className="p-2.5 bg-rose-50 border border-rose-200 rounded-xl text-rose-700 text-xs font-semibold flex items-center gap-2">
                    <AlertTriangle className="w-4 h-4 shrink-0" /> Alergias: {p.alergias}
                  </div>
                )}
                {p.antecedentes && (
                  <div className="p-2.5 bg-amber-50 border border-amber-200 rounded-xl text-amber-800 text-xs">
                    🏥 Antecedentes: {p.antecedentes}
                  </div>
                )}

                <div className="flex gap-2 pt-1">
                  <button onClick={() => startEdit(p)} className="btn-secondary text-xs"><Edit3 className="w-3.5 h-3.5" /> Editar</button>
                  <button onClick={() => del(p.id)} className="btn-danger text-xs"><Trash2 className="w-3.5 h-3.5" /> Desactivar</button>
                </div>
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}
EOF

# 11. CITAS
cat > src/components/Consultorio/Citas.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { Plus, Check, X, Clock, Calendar as CalIcon, User, ChevronLeft, ChevronRight, Save } from 'lucide-react'
import toast from 'react-hot-toast'

const estados = {
  programada: { color: 'border-l-blue-500', bg: 'bg-blue-50', text: 'text-blue-700', label: 'Programada' },
  confirmada: { color: 'border-l-teal-500', bg: 'bg-teal-50', text: 'text-teal-700', label: 'Confirmada' },
  en_curso: { color: 'border-l-amber-500', bg: 'bg-amber-50', text: 'text-amber-700', label: 'En Curso' },
  completada: { color: 'border-l-emerald-500', bg: 'bg-emerald-50', text: 'text-emerald-700', label: 'Completada' },
  cancelada: { color: 'border-l-rose-500', bg: 'bg-rose-50', text: 'text-rose-700', label: 'Cancelada' }
}

export default function Citas() {
  const [citas, setCitas] = useState([])
  const [pacs, setPacs] = useState([])
  const [trats, setTrats] = useState([])
  const [showForm, setShowForm] = useState(false)
  const [filtro, setFiltro] = useState('todas')
  const [fecha, setFecha] = useState(new Date().toISOString().split('T')[0])
  const [form, setForm] = useState({ paciente_id: '', tratamiento_id: '', fecha: '', duracion_min: 30, notas: '' })

  const load = async () => {
    const [c, p, t] = await Promise.all([
      supabase.from('citas').select('*, pacientes(nombres, apellidos, telefono), tratamientos(nombre, precio, duracion_min)').order('fecha'),
      supabase.from('pacientes').select('id, nombres, apellidos, cedula').eq('activo', true).order('nombres'),
      supabase.from('tratamientos').select('id, nombre, precio, duracion_min').eq('activo', true).order('nombre')
    ])
    setCitas(c.data || []); setPacs(p.data || []); setTrats(t.data || [])
  }
  useEffect(() => { load() }, [])

  const save = async e => {
    e.preventDefault()
    const t = trats.find(x => x.id === form.tratamiento_id)
    await supabase.from('citas').insert([{ ...form, tratamiento_id: form.tratamiento_id || null, duracion_min: t?.duracion_min || form.duracion_min }])
    toast.success('Cita agendada'); setShowForm(false); load()
  }

  const setStatus = async (id, est) => {
    await supabase.from('citas').update({ estado: est }).eq('id', id)
    toast.success(`Cita: ${estados[est]?.label}`)
    load()
  }

  const hoy = new Date().toISOString().split('T')[0]
  const citasDia = citas.filter(c => {
    const f = c.fecha?.split('T')[0]
    return f === fecha && (filtro === 'todas' || c.estado === filtro)
  })

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div><h1 className="text-xl font-bold text-slate-800">Agenda Odontológica</h1><p className="text-xs text-slate-400">{citas.length} citas registradas</p></div>
        <button onClick={() => { setShowForm(!showForm); setForm({ paciente_id: '', tratamiento_id: '', fecha: `${fecha}T09:00`, duracion_min: 30, notas: '' }) }} className={showForm ? 'btn-secondary' : 'btn-primary'}>
          {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Agendar Cita</>}
        </button>
      </div>

      {showForm && (
        <form onSubmit={save} className="card-box space-y-3 border-2 border-teal-200 bg-teal-50/20">
          <h3 className="font-bold text-sm text-teal-800">Agendar Nueva Cita</h3>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Paciente *</label>
              <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
                <option value="">Seleccionar paciente...</option>
                {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
              </select>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Tratamiento</label>
              <select className="input-field" value={form.tratamiento_id} onChange={e => { const t = trats.find(x => x.id === e.target.value); setForm({...form, tratamiento_id: e.target.value, duracion_min: t?.duracion_min || 30}) }}>
                <option value="">Consulta General</option>
                {trats.map(t => <option key={t.id} value={t.id}>{t.nombre} — ${t.precio}</option>)}
              </select>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Fecha y Hora *</label>
              <input required type="datetime-local" className="input-field" value={form.fecha} onChange={e => setForm({...form, fecha: e.target.value})} />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Notas</label>
              <input className="input-field" value={form.notas} onChange={e => setForm({...form, notas: e.target.value})} placeholder="Indicaciones..." />
            </div>
          </div>
          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> Confirmar Cita</button>
            <button type="button" onClick={() => setShowForm(false)} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      {/* Selector de Fecha */}
      <div className="card-box p-3 flex items-center justify-between">
        <span className="text-xs font-bold text-slate-500">Filtrar por Día:</span>
        <input type="date" value={fecha} onChange={e => setFecha(e.target.value)} className="input-field w-auto font-bold" />
        <button onClick={() => setFecha(hoy)} className="btn-secondary text-xs">Hoy</button>
      </div>

      {/* Lista de citas del día */}
      <div className="space-y-2">
        {citasDia.length === 0 ? (
          <div className="card-box text-center py-10 text-slate-400"><CalIcon className="w-8 h-8 mx-auto mb-2 opacity-30" /><p className="text-sm">Sin citas para este día</p></div>
        ) : citasDia.map(c => {
          const est = estados[c.estado] || estados.programada
          const hora = new Date(c.fecha).toLocaleTimeString('es-VE', { hour: '2-digit', minute: '2-digit' })
          return (
            <div key={c.id} className={`card-box p-4 border-l-4 ${est.color}`}>
              <div className="flex items-center justify-between flex-wrap gap-3">
                <div className="flex items-center gap-3">
                  <div className="text-center w-14"><p className="text-lg font-bold text-slate-800">{hora}</p><p className="text-[10px] text-slate-400">{c.duracion_min}m</p></div>
                  <div>
                    <h3 className="font-bold text-sm text-slate-800">{c.pacientes?.nombres} {c.pacientes?.apellidos}</h3>
                    <p className="text-xs text-teal-700 font-semibold">{c.tratamientos?.nombre || 'Consulta General'}</p>
                    {c.notas && <p className="text-[11px] text-slate-400 italic mt-0.5">"{c.notas}"</p>}
                  </div>
                </div>
                <div className="flex items-center gap-1.5">
                  <span className={`badge ${est.bg} ${est.text}`}>{est.label}</span>
                  {c.estado === 'programada' && <>
                    <button onClick={() => setStatus(c.id, 'confirmada')} className="p-1.5 bg-teal-50 text-teal-600 rounded-lg hover:bg-teal-100"><Check className="w-4 h-4" /></button>
                    <button onClick={() => setStatus(c.id, 'cancelada')} className="p-1.5 bg-rose-50 text-rose-500 rounded-lg hover:bg-rose-100"><X className="w-4 h-4" /></button>
                  </>}
                  {c.estado === 'confirmada' && <button onClick={() => setStatus(c.id, 'completada')} className="p-1.5 bg-emerald-50 text-emerald-600 rounded-lg"><Check className="w-4 h-4" /></button>}
                </div>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
EOF

# 12. TRATAMIENTOS CON VINCULACIÓN Y CÁLCULO DE INSUMOS
cat > src/components/Consultorio/Tratamientos.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { fmt } from '../../utils/helpers'
import PriceBox from '../UI/PriceBox'
import { Plus, Save, X, Clock, Trash2, Edit3, Package, ChevronDown, ChevronUp, Calculator } from 'lucide-react'
import toast from 'react-hot-toast'

const catIcons = { 'General':'🔍','Preventivo':'🛡️','Restauración':'🦷','Cirugía':'⚕️','Endodoncia':'🔬','Estético':'✨','Ortodoncia':'😁','Prótesis':'👑','Diagnóstico':'📷' }

export default function Tratamientos() {
  const [list, setList] = useState([])
  const [prods, setProds] = useState([])
  const [insumosTrat, setInsumosTrat] = useState({})
  const [showForm, setShowForm] = useState(false)
  const [editId, setEditId] = useState(null)
  const [expanded, setExpanded] = useState(null)
  const { rates } = useCurrency()

  const [form, setForm] = useState({ nombre: '', descripcion: '', precio: '', duracion_min: 30, categoria: 'General' })
  const [formInsumos, setFormInsumos] = useState([])

  const load = async () => {
    const [t, p, ti] = await Promise.all([
      supabase.from('tratamientos').select('*').eq('activo', true).order('categoria').order('nombre'),
      supabase.from('productos').select('*').eq('activo', true).order('nombre'),
      supabase.from('tratamiento_insumos').select('*, productos(nombre, precio_venta)').catch(() => ({ data: [] }))
    ])
    setList(t.data || [])
    setProds(p.data || [])

    const map = {}
    ;(ti.data || []).forEach(i => {
      if (!map[i.tratamiento_id]) map[i.tratamiento_id] = []
      map[i.tratamiento_id].push(i)
    })
    setInsumosTrat(map)
  }
  useEffect(() => { load() }, [])

  const costoInsumos = formInsumos.reduce((acc, fi) => {
    const prod = prods.find(p => p.id === fi.producto_id)
    return acc + ((prod?.precio_venta || 0) * (fi.cantidad || 0))
  }, 0)

  const precioServicio = parseFloat(form.precio) || 0
  const precioTotal = precioServicio + costoInsumos

  const addInsumo = () => setFormInsumos([...formInsumos, { producto_id: '', cantidad: 1 }])
  const removeInsumo = i => setFormInsumos(formInsumos.filter((_, idx) => idx !== i))
  const updateInsumo = (i, field, val) => setFormInsumos(formInsumos.map((fi, idx) => idx === i ? { ...fi, [field]: val } : fi))

  const save = async e => {
    e.preventDefault()
    const payload = { ...form, precio: precioTotal, duracion_min: parseInt(form.duracion_min) }

    let tratId
    if (editId) {
      await supabase.from('tratamientos').update(payload).eq('id', editId)
      tratId = editId
      await supabase.from('tratamiento_insumos').delete().eq('tratamiento_id', editId)
      toast.success('Tratamiento actualizado')
    } else {
      const { data } = await supabase.from('tratamientos').insert([payload]).select().single()
      tratId = data?.id
      toast.success('Tratamiento creado')
    }

    if (tratId && formInsumos.length > 0) {
      const validInsumos = formInsumos.filter(fi => fi.producto_id && fi.cantidad > 0)
      if (validInsumos.length > 0) {
        await supabase.from('tratamiento_insumos').insert(
          validInsumos.map(fi => ({ tratamiento_id: tratId, producto_id: fi.producto_id, cantidad: parseInt(fi.cantidad) }))
        )
      }
    }

    setShowForm(false); setEditId(null); setFormInsumos([]); load()
  }

  const startEdit = async t => {
    setForm({ nombre: t.nombre, descripcion: t.descripcion || '', precio: t.precio, duracion_min: t.duracion_min, categoria: t.categoria || 'General' })
    const existing = insumosTrat[t.id] || []
    setFormInsumos(existing.map(i => ({ producto_id: i.producto_id, cantidad: i.cantidad })))
    setEditId(t.id); setShowForm(true); setExpanded(null)
  }

  const del = async id => { if (!confirm('¿Desactivar?')) return; await supabase.from('tratamientos').update({ activo: false }).eq('id', id); toast.success('Desactivado'); load() }

  const grouped = {}
  list.forEach(t => { const c = t.categoria || 'General'; if (!grouped[c]) grouped[c] = []; grouped[c].push(t) })

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div><h1 className="text-xl font-bold text-slate-800">Catálogo de Procedimientos</h1><p className="text-xs text-slate-400">Cálculo automático: Mano de Obra + Insumos Utilizados</p></div>
        <button onClick={() => { setShowForm(!showForm); setEditId(null); setForm({ nombre: '', descripcion: '', precio: '', duracion_min: 30, categoria: 'General' }); setFormInsumos([]) }} className={showForm ? 'btn-secondary' : 'btn-primary'}>
          {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Nuevo Tratamiento</>}
        </button>
      </div>

      {showForm && (
        <form onSubmit={save} className="card-box space-y-4 border-2 border-teal-200 bg-teal-50/20">
          <h3 className="font-bold text-sm text-teal-800 flex items-center gap-1.5"><Calculator className="w-4 h-4" /> {editId ? 'Editar Tratamiento' : 'Crear Tratamiento con Cálculo de Insumos'}</h3>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Nombre *</label>
              <input required className="input-field" value={form.nombre} onChange={e => setForm({...form, nombre: e.target.value})} placeholder="Ej: Resina Fotocurada" />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Honorarios / Mano de Obra ($) *</label>
              <input required type="number" step="0.01" min="0" className="input-field font-bold text-teal-700" value={form.precio} onChange={e => setForm({...form, precio: e.target.value})} placeholder="20.00" />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Duración</label>
              <select className="input-field" value={form.duracion_min} onChange={e => setForm({...form, duracion_min: e.target.value})}>
                {[15,30,45,60,90,120].map(m => <option key={m} value={m}>{m} min</option>)}
              </select>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Categoría</label>
              <select className="input-field" value={form.categoria} onChange={e => setForm({...form, categoria: e.target.value})}>
                {Object.keys(catIcons).map(c => <option key={c}>{c}</option>)}
              </select>
            </div>
          </div>

          <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Descripción</label>
            <input className="input-field" value={form.descripcion} onChange={e => setForm({...form, descripcion: e.target.value})} placeholder="Indicaciones del tratamiento..." />
          </div>

          {/* VINCULACIÓN DE INSUMOS */}
          <div className="border-t border-slate-200 pt-3 space-y-2">
            <div className="flex justify-between items-center">
              <p className="text-xs font-bold text-slate-700 flex items-center gap-1.5"><Package className="w-4 h-4 text-teal-600" /> Insumos / Materiales del Almacén Utilizados</p>
              <button type="button" onClick={addInsumo} className="text-xs font-bold text-teal-600 hover:underline flex items-center gap-1"><Plus className="w-3 h-3" /> Añadir Material</button>
            </div>

            {formInsumos.map((fi, idx) => {
              const prod = prods.find(p => p.id === fi.producto_id)
              const subtotal = (prod?.precio_venta || 0) * (fi.cantidad || 0)
              return (
                <div key={idx} className="flex items-center gap-2 bg-white p-2.5 rounded-xl border border-slate-200">
                  <select className="input-field flex-1" value={fi.producto_id} onChange={e => updateInsumo(idx, 'producto_id', e.target.value)}>
                    <option value="">Seleccionar insumo...</option>
                    {prods.map(p => <option key={p.id} value={p.id}>{p.nombre} — ${p.precio_venta} (Stock: {p.stock})</option>)}
                  </select>
                  <input type="number" min="1" className="input-field w-20 text-center" value={fi.cantidad} onChange={e => updateInsumo(idx, 'cantidad', e.target.value)} />
                  <span className="text-xs font-bold text-teal-700 w-20 text-right">{fmt(subtotal)}</span>
                  <button type="button" onClick={() => removeInsumo(idx)} className="p-1 text-rose-400 hover:text-rose-600"><Trash2 className="w-4 h-4" /></button>
                </div>
              )
            })}
          </div>

          {/* TOTAL CALCULADO EN VIVO */}
          <div className="bg-slate-900 text-white p-4 rounded-xl space-y-1.5 text-sm">
            <div className="flex justify-between text-xs text-slate-400"><span>Honorarios Profesionales:</span><span>{fmt(precioServicio)}</span></div>
            <div className="flex justify-between text-xs text-slate-400"><span>Costo Materiales ({formInsumos.length} items):</span><span>{fmt(costoInsumos)}</span></div>
            <div className="flex justify-between text-base font-bold border-t border-slate-700 pt-2"><span>PRECIO FINAL TOTAL USD:</span><span className="text-teal-400">{fmt(precioTotal)}</span></div>
            <div className="flex justify-between text-xs font-semibold text-slate-300"><span>Precio en Bs. (BCV):</span><span>{fmt(precioTotal * rates.VES, 'VES')}</span></div>
            <div className="flex justify-between text-xs font-semibold text-amber-300"><span>Precio en COP:</span><span>{fmt(precioTotal * rates.COP, 'COP')}</span></div>
          </div>

          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> {editId ? 'Actualizar' : 'Guardar Tratamiento'}</button>
            <button type="button" onClick={() => { setShowForm(false); setEditId(null) }} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      {/* CATÁLOGO EXPANDIBLE */}
      {Object.entries(grouped).map(([cat, items]) => (
        <div key={cat} className="space-y-2">
          <h2 className="text-sm font-bold text-slate-600 flex items-center gap-2">{catIcons[cat] || '🦷'} {cat} <span className="text-[10px] bg-slate-100 px-2 py-0.5 rounded-full font-mono">{items.length}</span></h2>

          {items.map(t => {
            const insT = insumosTrat[t.id] || []
            const isExp = expanded === t.id

            return (
              <div key={t.id} className="card-box p-0 overflow-hidden">
                <button onClick={() => setExpanded(isExp ? null : t.id)} className="w-full flex items-center justify-between p-4 hover:bg-slate-50 text-left">
                  <div className="flex items-center gap-3">
                    <span className="text-xl">{catIcons[t.categoria] || '🦷'}</span>
                    <div>
                      <h3 className="font-bold text-sm text-slate-800">{t.nombre}</h3>
                      {t.descripcion && <p className="text-[11px] text-slate-400">{t.descripcion}</p>}
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className="text-xs text-slate-400 flex items-center gap-1"><Clock className="w-3 h-3" /> {t.duracion_min}m</span>
                    <PriceBox usd={t.precio} />
                    {insT.length > 0 && <span className="badge bg-teal-50 text-teal-700 font-bold"><Package className="w-3 h-3" /> {insT.length} insumos</span>}
                    {isExp ? <ChevronUp className="w-4 h-4 text-slate-400" /> : <ChevronDown className="w-4 h-4 text-slate-400" />}
                  </div>
                </button>

                {isExp && (
                  <div className="border-t bg-slate-50 p-4 space-y-3">
                    <div className="text-xs"><PriceBox usd={t.precio} showAll /></div>

                    {insT.length > 0 && (
                      <div className="space-y-1.5">
                        <p className="text-[11px] font-bold text-slate-500 uppercase">Insumos vinculados para este procedimiento:</p>
                        {insT.map(i => (
                          <div key={i.id} className="flex justify-between text-xs bg-white p-2 rounded-lg border">
                            <span className="flex items-center gap-1.5"><Package className="w-3 h-3 text-teal-600" /> {i.productos?.nombre}</span>
                            <span className="font-bold">{i.cantidad} x ${i.productos?.precio_venta}</span>
                          </div>
                        ))}
                      </div>
                    )}

                    <div className="flex gap-2 pt-1">
                      <button onClick={() => startEdit(t)} className="btn-secondary text-xs"><Edit3 className="w-3.5 h-3.5" /> Editar</button>
                      <button onClick={() => del(t.id)} className="btn-danger text-xs"><Trash2 className="w-3.5 h-3.5" /> Desactivar</button>
                    </div>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      ))}
    </div>
  )
}
EOF

# 13. HISTORIAL CLÍNICO CON ODONTOGRAMA
cat > src/components/Consultorio/Historial.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import PriceBox from '../UI/PriceBox'
import Odontograma from './Odontograma'
import { Plus, FileText, CheckCircle2, Clock, Search, User, Save, X } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Historial() {
  const [list, setList] = useState([])
  const [pacs, setPacs] = useState([])
  const [showForm, setShowForm] = useState(false)
  const [q, setQ] = useState('')
  const [dientesSel, setDientesSel] = useState([])
  const [form, setForm] = useState({ paciente_id: '', diagnostico: '', procedimiento: '', monto_usd: 0, pagado: true, metodo_pago: 'efectivo_usd' })

  const load = async () => {
    const [h, p] = await Promise.all([
      supabase.from('historial_clinico').select('*, pacientes(nombres, apellidos)').order('created_at', { ascending: false }),
      supabase.from('pacientes').select('id, nombres, apellidos').eq('activo', true).order('nombres')
    ])
    setList(h.data || []); setPacs(p.data || [])
  }
  useEffect(() => { load() }, [])

  const save = async e => {
    e.preventDefault()
    await supabase.from('historial_clinico').insert([{
      ...form,
      dientes_tratados: dientesSel.join(', '),
      monto_usd: parseFloat(form.monto_usd) || 0
    }])
    toast.success('Procedimiento guardado en el expediente')
    setShowForm(false); setDientesSel([]); load()
  }

  const metodoLabel = m => ({ efectivo_usd:'Efectivo $', efectivo_ves:'Efectivo Bs.', efectivo_cop:'Efectivo COP', transferencia:'Transferencia', pago_movil:'Pago Móvil', zelle:'Zelle', tarjeta:'Tarjeta', mixto:'Mixto' }[m] || m)

  const filtered = list.filter(h => `${h.pacientes?.nombres} ${h.pacientes?.apellidos} ${h.procedimiento} ${h.diagnostico}`.toLowerCase().includes(q.toLowerCase()))

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div><h1 className="text-xl font-bold text-slate-800">Historial Clínico</h1><p className="text-xs text-slate-400">Expedientes odontológicos y odontogramas</p></div>
        <button onClick={() => setShowForm(!showForm)} className={showForm ? 'btn-secondary' : 'btn-primary'}>
          {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Registrar Consulta</>}
        </button>
      </div>

      {showForm && (
        <form onSubmit={save} className="card-box space-y-4 border-2 border-teal-200 bg-teal-50/20">
          <h3 className="font-bold text-sm text-teal-800">Nueva Consulta Odontológica</h3>

          <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Paciente *</label>
              <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
                <option value="">Seleccionar paciente...</option>
                {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
              </select>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Procedimiento *</label>
              <input required className="input-field" value={form.procedimiento} onChange={e => setForm({...form, procedimiento: e.target.value})} placeholder="Ej: Resina Compuesta" />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Monto Cobrado ($)</label>
              <input type="number" step="0.01" min="0" className="input-field font-bold text-teal-700" value={form.monto_usd} onChange={e => setForm({...form, monto_usd: e.target.value})} />
            </div>
          </div>

          {/* ODONTOGRAMA SELECCIONABLE */}
          <Odontograma selected={dientesSel} onChange={setDientesSel} />

          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Diagnóstico e Indicaciones</label>
              <textarea className="input-field" value={form.diagnostico} onChange={e => setForm({...form, diagnostico: e.target.value})} placeholder="Observaciones clínicas..." rows={2} />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Método de Pago</label>
              <select className="input-field" value={form.metodo_pago} onChange={e => setForm({...form, metodo_pago: e.target.value})}>
                {['efectivo_usd','efectivo_ves','efectivo_cop','transferencia','pago_movil','zelle','tarjeta','mixto'].map(m => <option key={m} value={m}>{metodoLabel(m)}</option>)}
              </select>
            </div>
          </div>

          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> Guardar Consulta</button>
            <button type="button" onClick={() => setShowForm(false)} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input placeholder="Buscar por paciente o diagnóstico..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
      </div>

      <div className="space-y-3">
        {filtered.map(h => (
          <div key={h.id} className="card-box space-y-2">
            <div className="flex justify-between items-start flex-wrap gap-2">
              <div>
                <h3 className="font-bold text-sm text-slate-800">{h.pacientes?.nombres} {h.pacientes?.apellidos}</h3>
                <p className="text-xs font-bold text-teal-700">{h.procedimiento}</p>
                <p className="text-[11px] text-slate-400">{new Date(h.fecha).toLocaleDateString('es-VE', { day: 'numeric', month: 'short', year: 'numeric' })}</p>
              </div>
              <PriceBox usd={h.monto_usd} showAll />
            </div>

            {h.diagnostico && <p className="text-xs text-slate-600 bg-slate-50 p-2.5 rounded-xl border border-slate-100"><span className="font-bold text-slate-400">Dx:</span> {h.diagnostico}</p>}

            <div className="flex items-center gap-2 flex-wrap text-xs">
              {h.dientes_tratados && <span className="badge bg-teal-50 text-teal-800 font-bold border border-teal-100">🦷 Dientes: {h.dientes_tratados}</span>}
              <span className="badge bg-slate-100 text-slate-600">{metodoLabel(h.metodo_pago)}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
EOF

# 14. PUNTO DE VENTA (POS)
cat > src/components/Ventas/POS.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { fmt } from '../../utils/helpers'
import QRScanner from '../UI/QRScanner'
import { ShoppingBag, Trash2, CheckCircle, QrCode, Printer, X } from 'lucide-react'
import toast from 'react-hot-toast'

export default function POS() {
  const [prods, setProds] = useState([])
  const [cart, setCart] = useState([])
  const [client, setClient] = useState('')
  const [cedula, setCedula] = useState('')
  const [taxId, setTaxId] = useState('')
  const [lastSale, setLastSale] = useState(null)
  const [scanning, setScanning] = useState(false)
  const { rates, taxes } = useCurrency()

  const load = async () => {
    const { data } = await supabase.from('productos').select('*, impuestos(porcentaje)').eq('activo', true).eq('es_vendible', true).gt('stock', 0)
    setProds(data || [])
  }
  useEffect(() => { load() }, [])

  const addToCart = (p) => {
    const ex = cart.find(i => i.id === p.id)
    if (ex) {
      if (ex.cant >= p.stock) return toast.error('Stock insuficiente')
      setCart(cart.map(i => i.id === p.id ? { ...i, cant: i.cant + 1 } : i))
    } else {
      setCart([...cart, { ...p, cant: 1 }])
    }
  }

  const handleQRScan = (code) => {
    setScanning(false)
    const found = prods.find(p => p.codigo === code)
    if (found) {
      addToCart(found)
      toast.success(`${found.nombre} añadido`)
    } else {
      toast.error(`Código no encontrado: ${code}`)
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

    const payload = {
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

    const { data: v, error } = await supabase.from('ventas').insert([payload]).select().single()
    if (error) return toast.error('Error al vender')

    for (const item of cart) {
      await supabase.from('productos').update({ stock: item.stock - item.cant }).eq('id', item.id)
      await supabase.from('movimientos').insert({
        producto_id: item.id,
        tipo: 'venta',
        cantidad: -item.cant,
        stock_antes: item.stock,
        stock_despues: item.stock - item.cant,
        referencia: `Venta: ${fac}`
      })
    }

    toast.success(`Venta ${fac} completada`)
    setLastSale(v)
    setCart([]); setClient(''); setCedula(''); load()
  }

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
      {/* Catálogo */}
      <div className="lg:col-span-2 space-y-4">
        <div className="flex justify-between items-center flex-wrap gap-2">
          <div>
            <h1 className="text-xl font-bold text-slate-800">Punto de Venta de Insumos</h1>
            <p className="text-xs text-slate-400">Facturación directa y escaneo de códigos QR</p>
          </div>
          <button onClick={() => setScanning(true)} className="btn-secondary"><QrCode className="w-4 h-4 text-teal-600" /> Escanear QR</button>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
          {prods.map(p => (
            <button key={p.id} onClick={() => addToCart(p)} className="card-box text-left p-3.5 hover:border-teal-500 transition-all group">
              <h4 className="font-bold text-xs text-slate-800 truncate group-hover:text-teal-700">{p.nombre}</h4>
              <p className="text-[10px] text-slate-400 mt-0.5">Stock: {p.stock}</p>
              <div className="mt-3 flex items-center justify-between">
                <span className="font-bold text-sm text-teal-700">{fmt(p.precio_venta, 'USD')}</span>
                <span className="text-[10px] bg-slate-100 text-slate-600 px-2 py-0.5 rounded-full font-bold">+</span>
              </div>
            </button>
          ))}
        </div>
      </div>

      {/* Carrito */}
      <div className="card-box space-y-4 h-fit border-2 border-slate-100">
        <h2 className="font-bold text-sm text-slate-800 flex items-center gap-2 border-b pb-3">
          <ShoppingBag className="w-4 h-4 text-teal-600" /> Carrito de Venta
        </h2>

        <div className="space-y-2">
          <input placeholder="Nombre del Comprador" value={client} onChange={e => setClient(e.target.value)} className="input-field text-xs" />
          <input placeholder="Cédula / RIF" value={cedula} onChange={e => setCedula(e.target.value)} className="input-field text-xs" />
          <select value={taxId} onChange={e => setTaxId(e.target.value)} className="input-field text-xs">
            <option value="">Impuesto Global (Exento)</option>
            {taxes.map(t => <option key={t.id} value={t.id}>{t.nombre} ({t.porcentaje}%)</option>)}
          </select>
        </div>

        <div className="space-y-2 max-h-52 overflow-y-auto">
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
          {cart.length === 0 && <p className="text-center py-6 text-xs text-slate-300">Carrito vacío</p>}
        </div>

        {/* Totales */}
        <div className="border-t border-slate-100 pt-3 space-y-1.5 text-xs">
          <div className="flex justify-between text-slate-500"><span>Subtotal:</span><span>{fmt(subtotalUSD, 'USD')}</span></div>
          {taxPct > 0 && <div className="flex justify-between text-teal-700"><span>Impuesto ({taxPct}%):</span><span>{fmt(taxUSD, 'USD')}</span></div>}
          <div className="flex justify-between text-base font-bold text-slate-900 border-t pt-2">
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
          <CheckCircle className="w-4 h-4" /> Procesar Venta
        </button>

        {/* Ticket Recibo Inline si se emitió venta */}
        {lastSale && (
          <div className="p-3 bg-teal-50 border border-teal-200 rounded-xl text-center space-y-2 text-xs">
            <p className="font-bold text-teal-900">✓ Venta {lastSale.factura} Registrada</p>
            <div className="flex gap-2">
              <button onClick={() => window.print()} className="w-full btn-primary text-xs py-1.5 justify-center"><Printer className="w-3.5 h-3.5" /> Imprimir Comprobante</button>
              <button onClick={() => setLastSale(null)} className="p-1.5 text-slate-400"><X className="w-4 h-4" /></button>
            </div>
          </div>
        )}
      </div>

      {scanning && <QRScanner onScan={handleQRScan} onClose={() => setScanning(false)} />}
    </div>
  )
}
EOF

# 15. HISTORIAL DE VENTAS
cat > src/components/Ventas/HistorialVentas.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { fmt } from '../../utils/helpers'
import { Search, XCircle } from 'lucide-react'
import toast from 'react-hot-toast'

export default function HistorialVentas() {
  const [list, setList] = useState([])
  const [q, setQ] = useState('')

  const load = async () => {
    const { data } = await supabase.from('ventas').select('*').order('created_at', { ascending: false })
    setList(data || [])
  }
  useEffect(() => { load() }, [])

  const anular = async v => {
    if (!confirm(`¿Anular la factura ${v.factura}?`)) return
    await supabase.from('ventas').update({ estado: 'anulada' }).eq('id', v.id)
    toast.success('Venta anulada')
    load()
  }

  const filtered = list.filter(v => `${v.factura} ${v.cliente}`.toLowerCase().includes(q.toLowerCase()))

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-xl font-bold text-slate-800">Historial de Ventas</h1>
        <p className="text-xs text-slate-400">Auditoría de facturación y pagos</p>
      </div>

      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input placeholder="Buscar por factura o cliente..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
      </div>

      <div className="card-box p-0 overflow-hidden border">
        <table className="w-full text-left text-xs">
          <thead className="bg-slate-50 border-b text-slate-500 font-bold uppercase">
            <tr>
              <th className="p-3.5">Factura</th>
              <th className="p-3.5">Cliente</th>
              <th className="p-3.5">Total USD</th>
              <th className="p-3.5">Total Bs (BCV)</th>
              <th className="p-3.5">Total COP</th>
              <th className="p-3.5">Estado</th>
              <th className="p-3.5 text-right">Acción</th>
            </tr>
          </thead>
          <tbody className="divide-y">
            {filtered.map(v => (
              <tr key={v.id} className={v.estado === 'anulada' ? 'opacity-40 bg-slate-50' : ''}>
                <td className="p-3.5 font-mono font-bold text-slate-800">{v.factura}</td>
                <td className="p-3.5">{v.cliente}</td>
                <td className="p-3.5 font-bold text-teal-700">{fmt(v.total_usd, 'USD')}</td>
                <td className="p-3.5 font-semibold text-slate-600">{fmt(v.total_ves, 'VES')}</td>
                <td className="p-3.5 font-semibold text-amber-700">{fmt(v.total_cop, 'COP')}</td>
                <td className="p-3.5">
                  <span className={`badge ${v.estado === 'anulada' ? 'bg-rose-100 text-rose-700' : 'bg-emerald-100 text-emerald-700'}`}>
                    {v.estado}
                  </span>
                </td>
                <td className="p-3.5 text-right">
                  {v.estado !== 'anulada' && (
                    <button onClick={() => anular(v)} className="p-1.5 hover:bg-rose-50 rounded-lg text-rose-600" title="Anular"><XCircle className="w-4 h-4" /></button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
EOF

# 16. INVENTARIO CON CÓDIGOS Y ETIQUETAS QR INLINE
cat > src/components/Inventario/Inventario.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import PriceBox from '../UI/PriceBox'
import QRScanner from '../UI/QRScanner'
import { Plus, AlertTriangle, QrCode, Printer, Search, RefreshCw, X, Save } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Inventario() {
  const [list, setList] = useState([])
  const [cats, setCats] = useState([])
  const [taxes, setTaxes] = useState([])
  const [showForm, setShowForm] = useState(false)
  const [activeLabel, setActiveLabel] = useState(null)
  const [scanning, setScanning] = useState(false)
  const [q, setQ] = useState('')

  const [form, setForm] = useState({
    nombre: '', codigo: '', stock: 10, stock_minimo: 5,
    precio_compra: 0, precio_venta: '', categoria_id: '', impuesto_id: '', es_vendible: true
  })

  const load = async () => {
    const [p, c, t] = await Promise.all([
      supabase.from('productos').select('*, categorias(nombre, color), impuestos(nombre, porcentaje)').eq('activo', true).order('nombre'),
      supabase.from('categorias').select('*'),
      supabase.from('impuestos').select('*')
    ])
    setList(p.data || []); setCats(c.data || []); setTaxes(t.data || [])
  }
  useEffect(() => { load() }, [])

  const generateCode = () => {
    const cat = cats.find(x => x.id === form.categoria_id)
    const prefix = cat ? cat.nombre.slice(0, 3).toUpperCase() : 'ODN'
    const num = Math.floor(1000 + Math.random() * 9000)
    setForm(prev => ({ ...prev, codigo: `OD-${prefix}-${num}` }))
  }

  const save = async e => {
    e.preventDefault()
    if (!form.codigo) return toast.error('Debes generar o asignar un código')

    await supabase.from('productos').insert([{
      ...form,
      precio_venta: parseFloat(form.precio_venta) || 0,
      stock: parseInt(form.stock) || 0,
      categoria_id: form.categoria_id || null,
      impuesto_id: form.impuesto_id || null
    }])
    toast.success('Insumo guardado')
    setShowForm(false); load()
  }

  const handleScan = code => {
    setScanning(false)
    setQ(code)
    toast.success(`Filtrado por QR: ${code}`)
  }

  const filtered = list.filter(i => `${i.nombre} ${i.codigo}`.toLowerCase().includes(q.toLowerCase()))

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div><h1 className="text-xl font-bold text-slate-800">Almacén de Insumos Dentales</h1><p className="text-xs text-slate-400">Control de stock y códigos QR</p></div>
        <div className="flex gap-2">
          <button onClick={() => setScanning(true)} className="btn-secondary"><QrCode className="w-4 h-4 text-teal-600" /> Escanear</button>
          <button onClick={() => setShowForm(!showForm)} className={showForm ? 'btn-secondary' : 'btn-primary'}>
            {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Registrar Insumo</>}
          </button>
        </div>
      </div>

      {showForm && (
        <form onSubmit={save} className="card-box space-y-3 border-2 border-teal-200 bg-teal-50/20">
          <h3 className="font-bold text-sm text-teal-800">Registrar Insumo</h3>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Categoría</label>
              <select required className="input-field" value={form.categoria_id} onChange={e => setForm({...form, categoria_id: e.target.value})}>
                <option value="">Seleccione...</option>
                {cats.map(c => <option key={c.id} value={c.id}>{c.nombre}</option>)}
              </select>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Código del Artículo</label>
              <div className="flex gap-1">
                <input required className="input-field font-mono" value={form.codigo} onChange={e => setForm({...form, codigo: e.target.value.toUpperCase()})} />
                <button type="button" onClick={generateCode} className="btn-secondary text-xs px-2"><RefreshCw className="w-3.5 h-3.5" /></button>
              </div>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Nombre</label>
              <input required className="input-field" value={form.nombre} onChange={e => setForm({...form, nombre: e.target.value})} placeholder="Ej: Resina 3M" />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Precio Venta ($ USD)</label>
              <input required type="number" step="0.01" className="input-field font-bold text-teal-700" value={form.precio_venta} onChange={e => setForm({...form, precio_venta: e.target.value})} placeholder="25.00" />
            </div>
          </div>
          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> Guardar</button>
            <button type="button" onClick={() => setShowForm(false)} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input placeholder="Buscar por nombre o código..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
      </div>

      <div className="card-box p-0 overflow-hidden border">
        <table className="w-full text-left text-xs">
          <thead className="bg-slate-50 border-b text-slate-500 font-bold uppercase">
            <tr>
              <th className="p-3.5">Código QR</th>
              <th className="p-3.5">Insumo</th>
              <th className="p-3.5">Stock</th>
              <th className="p-3.5">Precio</th>
              <th className="p-3.5 text-right">Etiqueta</th>
            </tr>
          </thead>
          <tbody className="divide-y">
            {filtered.map(i => (
              <tr key={i.id} className="hover:bg-slate-50">
                <td className="p-3.5 font-mono font-bold text-slate-800 flex items-center gap-1.5"><QrCode className="w-3.5 h-3.5 text-teal-600" /> {i.codigo}</td>
                <td className="p-3.5 font-bold text-slate-800">{i.nombre}</td>
                <td className="p-3.5 font-bold">
                  <span className={i.stock <= i.stock_minimo ? 'text-rose-600 flex items-center gap-1' : 'text-slate-700'}>
                    {i.stock} {i.stock <= i.stock_minimo && <AlertTriangle className="w-3.5 h-3.5" />}
                  </span>
                </td>
                <td className="p-3.5"><PriceBox usd={i.precio_venta} showAll /></td>
                <td className="p-3.5 text-right">
                  <button onClick={() => setActiveLabel(i)} className="p-1.5 bg-teal-50 text-teal-700 rounded-lg inline-flex items-center gap-1 font-bold">
                    <Printer className="w-3.5 h-3.5" /> Ver Etiqueta
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {activeLabel && (
        <div className="card-box bg-slate-900 text-white p-6 rounded-2xl flex flex-col items-center justify-center space-y-3">
          <p className="font-bold text-sm uppercase">{activeLabel.nombre}</p>
          <div className="bg-white p-3 rounded-xl">
            <img src={`https://api.qrserver.com/v1/create-qr-code/?size=140x140&data=${encodeURIComponent(activeLabel.codigo)}`} alt="QR" className="w-28 h-28" />
          </div>
          <p className="font-mono font-bold text-xs text-teal-400 tracking-widest">{activeLabel.codigo}</p>
          <div className="flex gap-2">
            <button onClick={() => window.print()} className="btn-primary text-xs"><Printer className="w-3.5 h-3.5" /> Imprimir Etiqueta</button>
            <button onClick={() => setActiveLabel(null)} className="btn-secondary text-xs">Cerrar</button>
          </div>
        </div>
      )}

      {scanning && <QRScanner onScan={handleScan} onClose={() => setScanning(false)} />}
    </div>
  )
}
EOF

# 17. CONFIGURACIÓN (Tasas Oficiales e Impuestos)
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
    toast.success('Tasas de cambio guardadas')
  }

  const addTax = async (e) => {
    e.preventDefault()
    await supabase.from('impuestos').insert([newTax])
    toast.success('Impuesto agregado')
    setNewTax({ nombre: '', porcentaje: '' }); load(); loadData()
  }

  return (
    <div className="space-y-5">
      <div><h1 className="text-xl font-bold text-slate-800">Ajustes de Monedas e Impuestos</h1><p className="text-xs text-slate-400">Tasas oficiales del BCV, Colombia e Impuestos configurables</p></div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <form onSubmit={saveRates} className="card-box space-y-4">
          <h2 className="font-bold text-sm text-slate-800 flex items-center gap-2"><DollarSign className="w-4 h-4 text-teal-600" /> Tasas de Cambio Manuales</h2>
          <div>
            <label className="text-xs font-semibold text-slate-600 block mb-1">Tasa Bolívares (VES por cada 1 USD)</label>
            <input type="number" step="0.01" className="input-field font-bold" value={ves} onChange={e => setVes(e.target.value)} />
          </div>
          <div>
            <label className="text-xs font-semibold text-slate-600 block mb-1">Tasa Pesos Colombianos (COP por cada 1 USD)</label>
            <input type="number" step="1" className="input-field font-bold" value={cop} onChange={e => setCop(e.target.value)} />
          </div>
          <button type="submit" className="btn-primary w-full justify-center"><Save className="w-4 h-4" /> Guardar Tasas</button>
        </form>

        <div className="card-box space-y-4">
          <h2 className="font-bold text-sm text-slate-800 flex items-center gap-2"><Percent className="w-4 h-4 text-teal-600" /> Impuestos Configurados</h2>
          <div className="space-y-2">
            {taxes.map(t => (
              <div key={t.id} className="flex justify-between items-center text-xs p-2.5 bg-slate-50 rounded-xl">
                <span className="font-bold text-slate-800">{t.nombre}</span>
                <span className="font-mono bg-teal-100 text-teal-800 px-2 py-0.5 rounded-full font-bold">{t.porcentaje}%</span>
              </div>
            ))}
          </div>
          <form onSubmit={addTax} className="flex gap-2 pt-2">
            <input required placeholder="Impuesto (ej. IVA 16%)" className="input-field" value={newTax.nombre} onChange={e => setNewTax({...newTax, nombre: e.target.value})} />
            <input required type="number" placeholder="%" className="input-field w-20" value={newTax.porcentaje} onChange={e => setNewTax({...newTax, porcentaje: e.target.value})} />
            <button type="submit" className="btn-primary"><Plus className="w-4 h-4" /></button>
          </form>
        </div>
      </div>
    </div>
  )
}
EOF

# 18. ROUTING PRINCIPAL
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

# Compilar para producción
echo "📦 Instalando y compilando..."
npm install
npm run build

echo "✅ ¡COMPILACIÓN EXITOSA! El sistema dental definitivo está listo."
