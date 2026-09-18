import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { Plus, Check, X, Calendar as CalIcon } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Citas() {
  const [citas, setCitas] = useState([])
  const [pacs, setPacs] = useState([])
  const [trats, setTrats] = useState([])
  const [modal, setModal] = useState(false)
  const [form, setForm] = useState({ paciente_id: '', tratamiento_id: '', fecha: '', notas: '' })

  const load = async () => {
    const [c, p, t] = await Promise.all([
      supabase.from('citas').select('*, pacientes(nombres, apellidos), tratamientos(nombre)').order('fecha', { ascending: true }),
      supabase.from('pacientes').select('id, nombres, apellidos').eq('activo', true),
      supabase.from('tratamientos').select('id, nombre').eq('activo', true)
    ])
    setCitas(c.data || []); setPacs(p.data || []); setTrats(t.data || [])
  }
  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    await supabase.from('citas').insert([{ ...form, tratamiento_id: form.tratamiento_id || null }])
    toast.success('Cita agendada correctamente')
    setModal(false); load()
  }

  const setStatus = async (id, estado) => {
    await supabase.from('citas').update({ estado }).eq('id', id)
    toast.success(`Cita marcada como: ${estado}`)
    load()
  }

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Agenda Odontológica</h1>
          <p className="text-xs text-slate-400">Control y estado de citas</p>
        </div>
        <button onClick={() => setModal(true)} className="btn-primary"><Plus className="w-4 h-4" /> Agendar Cita</button>
      </div>

      <div className="space-y-3">
        {citas.map(c => (
          <div key={c.id} className="card-box flex items-center justify-between p-4 flex-wrap gap-3">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-teal-50 text-teal-600 flex items-center justify-center">
                <CalIcon className="w-5 h-5" />
              </div>
              <div>
                <h3 className="font-bold text-sm text-slate-800">{c.pacientes?.nombres} {c.pacientes?.apellidos}</h3>
                <p className="text-xs text-teal-700 font-semibold">{c.tratamientos?.nombre || 'Consulta General'}</p>
                <p className="text-[11px] text-slate-400 mt-0.5">📅 {new Date(c.fecha).toLocaleString()}</p>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <span className={`badge ${
                c.estado === 'completada' ? 'bg-emerald-100 text-emerald-800' :
                c.estado === 'cancelada' ? 'bg-rose-100 text-rose-800' : 'bg-blue-100 text-blue-800'
              }`}>
                {c.estado}
              </span>
              {c.estado === 'programada' && (
                <>
                  <button onClick={() => setStatus(c.id, 'completada')} title="Completar" className="p-1.5 bg-emerald-50 text-emerald-600 rounded-lg hover:bg-emerald-100">
                    <Check className="w-4 h-4" />
                  </button>
                  <button onClick={() => setStatus(c.id, 'cancelada')} title="Cancelar" className="p-1.5 bg-rose-50 text-rose-600 rounded-lg hover:bg-rose-100">
                    <X className="w-4 h-4" />
                  </button>
                </>
              )}
            </div>
          </div>
        ))}
      </div>

      {modal && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-4 shadow-2xl">
            <h2 className="font-bold text-base text-slate-800">Agendar Cita</h2>
            <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
              <option value="">Seleccione Paciente</option>
              {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
            </select>
            <select className="input-field" value={form.tratamiento_id} onChange={e => setForm({...form, tratamiento_id: e.target.value})}>
              <option value="">Tratamiento / Motivo</option>
              {trats.map(t => <option key={t.id} value={t.id}>{t.nombre}</option>)}
            </select>
            <input required type="datetime-local" className="input-field" value={form.fecha} onChange={e => setForm({...form, fecha: e.target.value})} />
            <textarea placeholder="Notas u observaciones" className="input-field" value={form.notas} onChange={e => setForm({...form, notas: e.target.value})} />
            <div className="flex justify-end gap-2 pt-2">
              <button type="button" onClick={() => setModal(false)} className="btn-secondary">Cancelar</button>
              <button type="submit" className="btn-primary">Confirmar</button>
            </div>
          </form>
        </div>
      )}
    </div>
  )
}
