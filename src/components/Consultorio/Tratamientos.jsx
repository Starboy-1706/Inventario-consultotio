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
