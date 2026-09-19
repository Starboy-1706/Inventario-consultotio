import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { DollarSign, Percent, Save, Plus, RefreshCw, ShieldCheck, Clock } from 'lucide-react'
import toast from 'react-hot-toast'

export default function TasasImpuestos() {
  const { rates, setRates, rateInfo, setRateInfo, loadData, syncOfficialRates, loadingRates } = useCurrency()
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

  const saveRatesManual = async (e) => {
    e.preventDefault()
    const numVes = Number(ves)
    const numCop = Number(cop)

    if (!numVes || !numCop) return toast.error('Ingresa valores válidos')

    await supabase.from('tasas_cambio').upsert({ moneda: 'VES', tasa: numVes, fuente: 'Manual (Fijada por Consultorio)' }, { onConflict: 'moneda' })
    await supabase.from('tasas_cambio').upsert({ moneda: 'COP', tasa: numCop, fuente: 'Manual (Fijada por Consultorio)' }, { onConflict: 'moneda' })
    
    setRates({ VES: numVes, COP: numCop })
    setRateInfo(prev => ({ ...prev, modo: 'manual', bcvFuente: 'Fijada Manualmente', copFuente: 'Fijada Manualmente' }))
    toast.success('Tasas fijadas manualmente con éxito')
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
          <h1 className="text-xl font-bold text-slate-800">Control Financiero & Tasas Bancarias</h1>
          <p className="text-xs text-slate-400">Tasas oficiales BCV (Venezuela), TRM (Colombia) e Impuestos</p>
        </div>
        <button onClick={() => syncOfficialRates(true)} disabled={loadingRates} className="btn-primary shadow-sm">
          <RefreshCw className={`w-4 h-4 ${loadingRates ? 'animate-spin' : ''}`} /> Sincronizar Tasas Oficiales de Hoy
        </button>
      </div>

      {/* Estado del sistema de tasas */}
      <div className="p-4 bg-teal-50 border border-teal-200 rounded-2xl flex items-center justify-between flex-wrap gap-3">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-teal-600 text-white rounded-xl flex items-center justify-center font-bold">
            <ShieldCheck className="w-5 h-5" />
          </div>
          <div>
            <p className="text-xs font-bold text-teal-900">Manejo Oficial de Cierres Bancarios Activo</p>
            <p className="text-[11px] text-teal-700">Los fines de semana y feriados se mantiene automáticamente la tasa de cierre del viernes sin saltar al paralelo.</p>
          </div>
        </div>
        <div className="text-xs font-mono font-bold text-teal-800 bg-white px-3 py-1.5 rounded-lg border border-teal-200">
          Modo: {rateInfo.modo === 'manual' ? '🔒 Tasa Manual Fija' : '🔄 Oficial Sincronizada'}
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Formulario de Tasas */}
        <form onSubmit={saveRatesManual} className="card-box space-y-4">
          <h2 className="font-bold text-sm text-slate-800 flex items-center gap-2">
            <DollarSign className="w-4 h-4 text-teal-600" /> Tasas Vigentes del Sistema
          </h2>

          <div className="space-y-1">
            <div className="flex justify-between items-center">
              <label className="text-xs font-semibold text-slate-600">Tasa Bolívares (VES por cada 1 USD)</label>
              <span className="text-[10px] text-teal-700 font-bold bg-teal-50 px-2 py-0.5 rounded">{rateInfo.bcvFuente}</span>
            </div>
            <input type="number" step="0.01" className="input-field font-bold text-base text-teal-800" value={ves} onChange={e => setVes(e.target.value)} />
            <span className="text-[10px] text-slate-400">Oficial Banco Central de Venezuela (BCV)</span>
          </div>

          <div className="space-y-1">
            <div className="flex justify-between items-center">
              <label className="text-xs font-semibold text-slate-600">Tasa Pesos Colombianos (COP por cada 1 USD)</label>
              <span className="text-[10px] text-amber-700 font-bold bg-amber-50 px-2 py-0.5 rounded">{rateInfo.copFuente}</span>
            </div>
            <input type="number" step="1" className="input-field font-bold text-base text-amber-800" value={cop} onChange={e => setCop(e.target.value)} />
            <span className="text-[10px] text-slate-400">TRM Oficial Superintendencia Financiera de Colombia</span>
          </div>

          <button type="submit" className="btn-secondary w-full justify-center text-xs font-bold py-2.5">
            <Save className="w-4 h-4" /> Fijar Tasas Manualmente
          </button>
        </form>

        {/* Impuestos */}
        <div className="card-box space-y-4">
          <h2 className="font-bold text-sm text-slate-800 flex items-center gap-2">
            <Percent className="w-4 h-4 text-teal-600" /> Impuestos y Retenciones
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
            <input required placeholder="Nuevo Impuesto (ej. IGTF 3%)" className="input-field text-xs" value={newTax.nombre} onChange={e => setNewTax({...newTax, nombre: e.target.value})} />
            <input required type="number" placeholder="%" className="input-field w-20 text-xs" value={newTax.porcentaje} onChange={e => setNewTax({...newTax, porcentaje: e.target.value})} />
            <button type="submit" className="btn-primary"><Plus className="w-4 h-4" /></button>
          </form>
        </div>
      </div>
    </div>
  )
}
