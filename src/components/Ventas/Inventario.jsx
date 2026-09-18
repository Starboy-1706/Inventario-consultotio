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
