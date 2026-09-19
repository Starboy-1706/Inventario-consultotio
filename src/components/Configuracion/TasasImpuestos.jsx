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
