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
