import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { Plus, Check, X } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Citas() {
  const [citas, setCitas] = useState([])
  const [pacs, setPacs] = useState([])
  const [modal, setModal] = useState(false)
  const [form, setForm] = useState({ paciente_id: '', fecha: '', notas: '' })

  const load = async () => {
    const [c, p] = await Promise.all([
      supabase.from('citas').select('*, pacientes(nombres, apellidos)').order('fecha', { ascending: true }),
      supabase.from('pacientes').select('id, nombres, apellidos').eq('activo', true)
    ])
    setCitas(c.data || []); setPacs(p.data || [])
  }
  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    await supabase.from('citas').insert([form])
    toast.success('Cita programada')
    setModal(false); load()
  }

  const setStatus = async (id, estado) => {
    await supabase.from('citas').update({ estado }).eq('id', id)
    toast.success(`Cita: ${estado}`)
    load()
  }

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <div><h1 className="text-xl font-bold">Agenda Odontológica</h1><p className="text-xs text-slate-400">Control de citas</p></div>
        <button onClick={() => setModal(true)} className="btn-primary"><Plus className="w-4 h-4" /> Nueva Cita</button>
      </div>

      <div className="space-y-2">
        {citas.map(c => (
          <div key={c.id} className="card-box flex items-center justify-between p-4">
            <div>
              <h3 className="font-bold text-sm">{c.pacientes?.nombres} {c.pacientes?.apellidos}</h3>
              <p className="text-xs text-slate-500">📅 {new Date(c.fecha).toLocaleString()}</p>
              {c.notas && <p className="text-xs text-slate-400 mt-1">{c.notas}</p>}
            </div>
            <div className="flex items-center gap-2">
              <span className={`text-[10px] font-bold px-2.5 py-1 rounded-full uppercase ${c.estado === 'completada' ? 'bg-emerald-100 text-emerald-800' : c.estado === 'cancelada' ? 'bg-rose-100 text-rose-800' : 'bg-blue-100 text-blue-800'}`}>{c.estado}</span>
              {c.estado === 'programada' && (
                <>
                  <button onClick={() => setStatus(c.id, 'completada')} className="p-1.5 bg-emerald-50 text-emerald-600 rounded-lg"><Check className="w-4 h-4" /></button>
                  <button onClick={() => setStatus(c.id, 'cancelada')} className="p-1.5 bg-rose-50 text-rose-600 rounded-lg"><X className="w-4 h-4" /></button>
                </>
              )}
            </div>
          </div>
        ))}
      </div>

      {modal && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-3">
            <h2 className="font-bold text-base">Programar Cita</h2>
            <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
              <option value="">Seleccione Paciente</option>
              {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
            </select>
            <input required type="datetime-local" className="input-field" value={form.fecha} onChange={e => setForm({...form, fecha: e.target.value})} />
            <textarea placeholder="Motivo de la consulta" className="input-field" value={form.notas} onChange={e => setForm({...form, notas: e.target.value})} />
            <div className="flex justify-end gap-2 pt-2"><button type="button" onClick={() => setModal(false)} className="btn-secondary">Cancelar</button><button type="submit" className="btn-primary">Programar</button></div>
          </form>
        </div>
      )}
    </div>
  )
}
