#!/bin/bash
set -e

echo "🔌 Instalando monitor y detector de conexión con Supabase..."

# 1. Supabase Client con diagnósticos detallados
cat > src/lib/supabase.js << 'EOF'
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || ''
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || ''

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('⚠️ [SUPABASE] Faltan variables de entorno: VITE_SUPABASE_URL o VITE_SUPABASE_ANON_KEY no están definidas.')
}

export const supabase = createClient(
  supabaseUrl || 'https://placeholder.supabase.co',
  supabaseAnonKey || 'placeholder',
  {
    auth: {
      persistSession: false,
      autoRefreshToken: false
    }
  }
)

// Función para probar la conexión en tiempo real
export async function testSupabaseConnection() {
  if (!supabaseUrl || !supabaseAnonKey || supabaseUrl.includes('placeholder')) {
    return {
      ok: false,
      reason: 'MISSING_ENV',
      message: 'Faltan las variables VITE_SUPABASE_URL o VITE_SUPABASE_ANON_KEY en Vercel / .env'
    }
  }

  try {
    const start = Date.now()
    const { data, error, status } = await supabase
      .from('tasas_cambio')
      .select('moneda, tasa')
      .limit(1)

    const latency = Date.now() - start

    if (error) {
      return {
        ok: false,
        reason: 'QUERY_ERROR',
        status,
        message: error.message || 'Error al consultar la tabla en Supabase',
        details: error
      }
    }

    return {
      ok: true,
      latency,
      url: supabaseUrl.replace(/https?:\/\//, '').split('.')[0] + '.supabase.co',
      message: 'Conexión activa con Supabase'
    }
  } catch (err) {
    return {
      ok: false,
      reason: 'NETWORK_ERROR',
      message: err.message || 'Error de red al conectar con Supabase'
    }
  }
}
EOF

# 2. Header con indicador en vivo de conexión con Supabase
cat > src/components/Layout/Shell.jsx << 'EOF'
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
EOF

# 3. Vista de Configuración con tarjeta de diagnóstico interactivo
cat > src/components/Configuracion/TasasImpuestos.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase, testSupabaseConnection } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { DollarSign, Percent, Save, Plus, RefreshCw, Database, CheckCircle2, AlertTriangle } from 'lucide-react'
import toast from 'react-hot-toast'

export default function TasasImpuestos() {
  const { rates, setRates, loadData, syncOfficialRates, loadingRates } = useCurrency()
  const [ves, setVes] = useState(rates.VES)
  const [cop, setCop] = useState(rates.COP)
  const [taxes, setTaxes] = useState([])
  const [newTax, setNewTax] = useState({ nombre: '', porcentaje: '' })

  // Diagnóstico
  const [diag, setDiag] = useState({ loading: true })

  const runDiagnostics = async () => {
    setDiag({ loading: true })
    const res = await testSupabaseConnection()
    setDiag({ loading: false, ...res })
  }

  useEffect(() => {
    setVes(rates.VES)
    setCop(rates.COP)
  }, [rates])

  useEffect(() => {
    runDiagnostics()
    const loadTaxes = async () => {
      const { data } = await supabase.from('impuestos').select('*')
      setTaxes(data || [])
    }
    loadTaxes()
  }, [])

  const saveRates = async (e) => {
    e.preventDefault()
    const numVes = Number(ves)
    const numCop = Number(cop)

    if (!numVes || !numCop) return toast.error('Ingresa valores válidos')

    const { error } = await supabase.from('tasas_cambio').upsert({ moneda: 'VES', tasa: numVes, fuente: 'Manual' }, { onConflict: 'moneda' })
    await supabase.from('tasas_cambio').upsert({ moneda: 'COP', tasa: numCop, fuente: 'Manual' }, { onConflict: 'moneda' })
    
    if (error) {
      toast.error(`Error al guardar en Supabase: ${error.message}`)
    } else {
      setRates({ VES: numVes, COP: numCop })
      toast.success('Tasas guardadas en Supabase')
    }
  }

  const addTax = async (e) => {
    e.preventDefault()
    const { error } = await supabase.from('impuestos').insert([newTax])
    if (error) {
      toast.error(`Error al guardar impuesto: ${error.message}`)
    } else {
      toast.success('Impuesto agregado a Supabase')
      setNewTax({ nombre: '', porcentaje: '' })
      const { data } = await supabase.from('impuestos').select('*')
      setTaxes(data || [])
      loadData()
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Ajustes de Sistema & Base de Datos</h1>
          <p className="text-xs text-slate-400">Tasas oficiales, impuestos y diagnóstico de conexión con Supabase</p>
        </div>
        <button onClick={() => syncOfficialRates(true)} disabled={loadingRates} className="btn-primary">
          <RefreshCw className={`w-4 h-4 ${loadingRates ? 'animate-spin' : ''}`} /> Sincronizar Tasas de Hoy
        </button>
      </div>

      {/* TARJETA DE DIAGNÓSTICO EN VIVO */}
      <div className="card-box space-y-3 border-2 border-slate-200">
        <div className="flex justify-between items-center">
          <h2 className="font-bold text-sm text-slate-800 flex items-center gap-2">
            <Database className="w-4 h-4 text-teal-600" /> Estado de Conexión con Supabase
          </h2>
          <button onClick={runDiagnostics} className="btn-secondary text-xs py-1">
            <RefreshCw className={`w-3.5 h-3.5 ${diag.loading ? 'animate-spin' : ''}`} /> Re-probar
          </button>
        </div>

        {diag.loading ? (
          <p className="text-xs text-slate-400">Verificando conexión con Supabase...</p>
        ) : diag.ok ? (
          <div className="p-3 bg-emerald-50 border border-emerald-200 rounded-xl flex items-center gap-3 text-xs text-emerald-800">
            <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0" />
            <div>
              <p className="font-bold">¡Conexión Exitosa con Supabase!</p>
              <p className="text-[11px] text-emerald-700">Proyecto: <b>{diag.url}</b> (Latencia: {diag.latency}ms). Las tablas responden correctamente.</p>
            </div>
          </div>
        ) : (
          <div className="p-4 bg-rose-50 border border-rose-200 rounded-xl space-y-2 text-xs text-rose-800">
            <div className="flex items-center gap-2 font-bold text-sm text-rose-700">
              <AlertTriangle className="w-5 h-5 text-rose-600 shrink-0" />
              Error: No se pudo conectar con Supabase
            </div>
            <p className="text-slate-700">{diag.message}</p>

            <div className="p-3 bg-white rounded-lg border border-rose-200 text-[11px] space-y-1 text-slate-600">
              <p className="font-bold text-slate-800">¿Cómo solucionarlo?</p>
              {diag.reason === 'MISSING_ENV' ? (
                <ol className="list-decimal pl-4 space-y-0.5">
                  <li>Ve a <b>vercel.com</b> ➔ Tu Proyecto ➔ <b>Settings</b> ➔ <b>Environment Variables</b>.</li>
                  <li>Asegúrate de agregar <b>VITE_SUPABASE_URL</b> y <b>VITE_SUPABASE_ANON_KEY</b>.</li>
                  <li>Haz un <b>Redeploy</b> en Vercel para que tome los cambios.</li>
                </ol>
              ) : (
                <p>Verifica que ejecutaste el script SQL en Supabase para habilitar las políticas de acceso (RLS).</p>
              )}
            </div>
          </div>
        )}
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
            <span className="text-[10px] text-slate-400">Oficial Banco Central de Venezuela (BCV)</span>
          </div>

          <div>
            <label className="text-xs font-semibold text-slate-600 block mb-1">Tasa Pesos Colombianos (COP por cada 1 USD)</label>
            <input type="number" step="1" className="input-field font-bold text-base text-amber-800" value={cop} onChange={e => setCop(e.target.value)} />
            <span className="text-[10px] text-slate-400">Tasa Representativa del Mercado (TRM) Colombia</span>
          </div>

          <button type="submit" className="btn-secondary w-full justify-center text-xs font-bold py-2.5">
            <Save className="w-4 h-4" /> Guardar Tasas en Supabase
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
            <input required placeholder="Nuevo Impuesto (ej. IVA 16%)" className="input-field text-xs" value={newTax.nombre} onChange={e => setNewTax({...newTax, nombre: e.target.value})} />
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
echo "✅ Monitor de conexión con Supabase instalado y probado."
