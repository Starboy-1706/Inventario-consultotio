import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { Plus, Check, X, Clock, Calendar as CalIcon, User, ChevronLeft, ChevronRight, Save } from 'lucide-react'
import toast from 'react-hot-toast'

const estados = {
  programada: { color: 'border-l-blue-500', bg: 'bg-blue-50', text: 'text-blue-700', label: 'Programada' },
  confirmada: { color: 'border-l-teal-500', bg: 'bg-teal-50', text: 'text-teal-700', label: 'Confirmada' },
  en_curso: { color: 'border-l-amber-500', bg: 'bg-amber-50', text: 'text-amber-700', label: 'En Curso' },
  completada: { color: 'border-l-emerald-500', bg: 'bg-emerald-50', text: 'text-emerald-700', label: 'Completada' },
  cancelada: { color: 'border-l-rose-500', bg: 'bg-rose-50', text: 'text-rose-700', label: 'Cancelada' }
}

export default function Citas() {
  const [citas, setCitas] = useState([])
  const [pacs, setPacs] = useState([])
  const [trats, setTrats] = useState([])
  const [showForm, setShowForm] = useState(false)
  const [filtro, setFiltro] = useState('todas')
  const [fecha, setFecha] = useState(new Date().toISOString().split('T')[0])
  const [form, setForm] = useState({ paciente_id: '', tratamiento_id: '', fecha: '', duracion_min: 30, notas: '' })

  const load = async () => {
    const [c, p, t] = await Promise.all([
      supabase.from('citas').select('*, pacientes(nombres, apellidos, telefono), tratamientos(nombre, precio, duracion_min)').order('fecha'),
      supabase.from('pacientes').select('id, nombres, apellidos, cedula').eq('activo', true).order('nombres'),
      supabase.from('tratamientos').select('id, nombre, precio, duracion_min').eq('activo', true).order('nombre')
    ])
    setCitas(c.data || []); setPacs(p.data || []); setTrats(t.data || [])
  }
  useEffect(() => { load() }, [])

  const save = async e => {
    e.preventDefault()
    const t = trats.find(x => x.id === form.tratamiento_id)
    await supabase.from('citas').insert([{ ...form, tratamiento_id: form.tratamiento_id || null, duracion_min: t?.duracion_min || form.duracion_min }])
    toast.success('Cita agendada'); setShowForm(false); load()
  }

  const setStatus = async (id, est) => {
    await supabase.from('citas').update({ estado: est }).eq('id', id)
    toast.success(`Cita: ${estados[est]?.label}`)
    load()
  }

  const hoy = new Date().toISOString().split('T')[0]
  const citasDia = citas.filter(c => {
    const f = c.fecha?.split('T')[0]
    return f === fecha && (filtro === 'todas' || c.estado === filtro)
  })

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div><h1 className="text-xl font-bold text-slate-800">Agenda Odontológica</h1><p className="text-xs text-slate-400">{citas.length} citas registradas</p></div>
        <button onClick={() => { setShowForm(!showForm); setForm({ paciente_id: '', tratamiento_id: '', fecha: `${fecha}T09:00`, duracion_min: 30, notas: '' }) }} className={showForm ? 'btn-secondary' : 'btn-primary'}>
          {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Agendar Cita</>}
        </button>
      </div>

      {showForm && (
        <form onSubmit={save} className="card-box space-y-3 border-2 border-teal-200 bg-teal-50/20">
          <h3 className="font-bold text-sm text-teal-800">Agendar Nueva Cita</h3>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Paciente *</label>
              <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
                <option value="">Seleccionar paciente...</option>
                {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
              </select>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Tratamiento</label>
              <select className="input-field" value={form.tratamiento_id} onChange={e => { const t = trats.find(x => x.id === e.target.value); setForm({...form, tratamiento_id: e.target.value, duracion_min: t?.duracion_min || 30}) }}>
                <option value="">Consulta General</option>
                {trats.map(t => <option key={t.id} value={t.id}>{t.nombre} — ${t.precio}</option>)}
              </select>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Fecha y Hora *</label>
              <input required type="datetime-local" className="input-field" value={form.fecha} onChange={e => setForm({...form, fecha: e.target.value})} />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Notas</label>
              <input className="input-field" value={form.notas} onChange={e => setForm({...form, notas: e.target.value})} placeholder="Indicaciones..." />
            </div>
          </div>
          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> Confirmar Cita</button>
            <button type="button" onClick={() => setShowForm(false)} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      <div className="card-box p-3 flex items-center justify-between">
        <span className="text-xs font-bold text-slate-500">Filtrar por Día:</span>
        <input type="date" value={fecha} onChange={e => setFecha(e.target.value)} className="input-field w-auto font-bold" />
        <button onClick={() => setFecha(hoy)} className="btn-secondary text-xs">Hoy</button>
      </div>

      <div className="space-y-2">
        {citasDia.length === 0 ? (
          <div className="card-box text-center py-10 text-slate-400"><CalIcon className="w-8 h-8 mx-auto mb-2 opacity-30" /><p className="text-sm">Sin citas para este día</p></div>
        ) : citasDia.map(c => {
          const est = estados[c.estado] || estados.programada
          const hora = new Date(c.fecha).toLocaleTimeString('es-VE', { hour: '2-digit', minute: '2-digit' })
          return (
            <div key={c.id} className={`card-box p-4 border-l-4 ${est.color}`}>
              <div className="flex items-center justify-between flex-wrap gap-3">
                <div className="flex items-center gap-3">
                  <div className="text-center w-14"><p className="text-lg font-bold text-slate-800">{hora}</p><p className="text-[10px] text-slate-400">{c.duracion_min}m</p></div>
                  <div>
                    <h3 className="font-bold text-sm text-slate-800">{c.pacientes?.nombres} {c.pacientes?.apellidos}</h3>
                    <p className="text-xs text-teal-700 font-semibold">{c.tratamientos?.nombre || 'Consulta General'}</p>
                    {c.notas && <p className="text-[11px] text-slate-400 italic mt-0.5">"{c.notas}"</p>}
                  </div>
                </div>
                <div className="flex items-center gap-1.5">
                  <span className={`badge ${est.bg} ${est.text}`}>{est.label}</span>
                  {c.estado === 'programada' && <>
                    <button onClick={() => setStatus(c.id, 'confirmada')} className="p-1.5 bg-teal-50 text-teal-600 rounded-lg hover:bg-teal-100"><Check className="w-4 h-4" /></button>
                    <button onClick={() => setStatus(c.id, 'cancelada')} className="p-1.5 bg-rose-50 text-rose-500 rounded-lg hover:bg-rose-100"><X className="w-4 h-4" /></button>
                  </>}
                  {c.estado === 'confirmada' && <button onClick={() => setStatus(c.id, 'completada')} className="p-1.5 bg-emerald-50 text-emerald-600 rounded-lg"><Check className="w-4 h-4" /></button>}
                </div>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
