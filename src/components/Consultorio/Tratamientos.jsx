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
