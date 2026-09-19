import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { DollarSign, Percent, Save, Plus, RefreshCw, CheckCircle2 } from 'lucide-react'
import toast from 'react-hot-toast'

export default function TasasImpuestos() {
  const { rates, setRates, loadData, syncOfficialRates, loadingRates, lastUpdate } = useCurrency()
  const [ves, setVes] = useState(rates.VES)
  const [cop, setCop] = useState(rates.COP)
  const [taxes, setTaxes] = useState([])
  const [newTax, setNewTax] = useState({ nombre: '', porcentaje: '' })

  useEffect(() => {
    setVes(rates.VES)
    setCop(rates.COP)
  }, [rates])

  const loadTaxes = async () => {
    const { data } = await supabase.from('impuestos').select('*')
    setTaxes(data || [])
  }
  useEffect(() => { loadTaxes() }, [])

  const saveRates = async (e) => {
    e.preventDefault()
    const numVes = Number(ves)
    const numCop = Number(cop)

    if (!numVes || !numCop) return toast.error('Ingresa valores válidos')

    await supabase.from('tasas_cambio').upsert({ moneda: 'VES', tasa: numVes, fuente: 'Manual' }, { onConflict: 'moneda' })
    await supabase.from('tasas_cambio').upsert({ moneda: 'COP', tasa: numCop, fuente: 'Manual' }, { onConflict: 'moneda' })
    
    setRates({ VES: numVes, COP: numCop })
    toast.success('Tasas fijadas manualmente')
  }

  const addTax = async (e) => {
    e.preventDefault()
    await supabase.from('impuestos').insert([newTax])
    toast.success('Impuesto agregado')
    setNewTax({ nombre: '', porcentaje: '' })
    loadTaxes(); loadData()
  }

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Ajustes de Monedas e Impuestos</h1>
          <p className="text-xs text-slate-400">Tasas oficiales del Banco Central de Venezuela (BCV) y TRM Colombia</p>
        </div>
        <button onClick={() => syncOfficialRates(true)} disabled={loadingRates} className="btn-primary">
          <RefreshCw className={`w-4 h-4 ${loadingRates ? 'animate-spin' : ''}`} /> Sincronizar Tasas Oficiales de Hoy
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Tasas */}
        <form onSubmit={saveRates} className="card-box space-y-4">
          <div className="flex justify-between items-center">
            <h2 className="font-bold text-sm text-slate-800 flex items-center gap-2">
              <DollarSign className="w-4 h-4 text-teal-600" /> Tasas Oficiales del Sistema
            </h2>
            {lastUpdate && (
              <span className="text-[10px] text-teal-700 bg-teal-50 px-2 py-0.5 rounded-full font-semibold flex items-center gap-1">
                <CheckCircle2 className="w-3 h-3" /> Actualizado: {lastUpdate}
              </span>
            )}
          </div>

          <div>
            <label className="text-xs font-semibold text-slate-600 block mb-1">Tasa Bolívares (VES por cada 1 USD)</label>
            <input type="number" step="0.01" className="input-field font-bold text-base text-teal-800" value={ves} onChange={e => setVes(e.target.value)} />
            <span className="text-[10px] text-slate-400">Oficial Banco Central de Venezuela (BCV) con cierre de fin de semana</span>
          </div>

          <div>
            <label className="text-xs font-semibold text-slate-600 block mb-1">Tasa Pesos Colombianos (COP por cada 1 USD)</label>
            <input type="number" step="1" className="input-field font-bold text-base text-amber-800" value={cop} onChange={e => setCop(e.target.value)} />
            <span className="text-[10px] text-slate-400">Tasa Representativa del Mercado (TRM) Colombia</span>
          </div>

          <button type="submit" className="btn-secondary w-full justify-center text-xs font-bold py-2.5">
            <Save className="w-4 h-4" /> Guardar / Forzar Tasas Manualmente
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
            <input required placeholder="Nombre (ej. IVA 16%)" className="input-field text-xs" value={newTax.nombre} onChange={e => setNewTax({...newTax, nombre: e.target.value})} />
            <input required type="number" placeholder="%" className="input-field w-20 text-xs" value={newTax.porcentaje} onChange={e => setNewTax({...newTax, porcentaje: e.target.value})} />
            <button type="submit" className="btn-primary"><Plus className="w-4 h-4" /></button>
          </form>
        </div>
      </div>
    </div>
  )
}
