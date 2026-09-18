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
