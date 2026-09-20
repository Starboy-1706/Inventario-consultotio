import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { msgRecordatorioCita, openWhatsApp, makePhoneCall } from '../../utils/comunicaciones'
import {
  Plus, Check, X, Clock, Calendar as CalIcon, User,
  ChevronLeft, ChevronRight, Save, LayoutGrid, List, MessageCircle, Phone
} from 'lucide-react'
import toast from 'react-hot-toast'

const estados = {
  programada: { color: 'border-l-blue-500', bg: 'bg-blue-50', text: 'text-blue-700', label: 'Programada' },
  confirmada: { color: 'border-l-teal-500', bg: 'bg-teal-50', text: 'text-teal-700', label: 'Confirmada' },
  en_curso: { color: 'border-l-amber-500', bg: 'bg-amber-50', text: 'text-amber-700', label: 'En Curso' },
  completada: { color: 'border-l-emerald-500', bg: 'bg-emerald-50', text: 'text-emerald-700', label: 'Completada' },
  cancelada: { color: 'border-l-rose-500', bg: 'bg-rose-50', text: 'text-rose-700', label: 'Cancelada' }
}

const horasJornada = ['08:00', '09:00', '10:00', '11:00', '12:00', '14:00', '15:00', '16:00', '17:00', '18:00']

export default function Citas() {
  const [citas, setCitas] = useState([])
  const [pacs, setPacs] = useState([])
  const [trats, setTrats] = useState([])
  const [clinica, setClinica] = useState(null)
  const [showForm, setShowForm] = useState(false)
  const [vista, setVista] = useState('horas')
  const [filtro, setFiltro] = useState('todas')
  const [fecha, setFecha] = useState(new Date().toISOString().split('T')[0])
  const [form, setForm] = useState({ paciente_id: '', tratamiento_id: '', fecha: '', duracion_min: 30, notas: '' })

  const load = async () => {
    const [c, p, t, cl] = await Promise.all([
      supabase.from('citas').select('*, pacientes(nombres, apellidos, telefono, email), tratamientos(nombre, precio, duracion_min)').order('fecha'),
      supabase.from('pacientes').select('id, nombres, apellidos, cedula').eq('activo', true).order('nombres'),
      supabase.from('tratamientos').select('id, nombre, precio, duracion_min').eq('activo', true).order('nombre'),
      supabase.from('configuracion_consultorio').select('*').limit(1)
    ])
    setCitas(c.data || []); setPacs(p.data || []); setTrats(t.data || [])
    if (cl.data?.[0]) setClinica(cl.data[0])
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

  const sendWhatsAppReminder = (cita) => {
    if (!cita.pacientes?.telefono) return toast.error('El paciente no tiene teléfono')
    const msg = msgRecordatorioCita({ paciente: cita.pacientes, cita, clinica })
    openWhatsApp(cita.pacientes.telefono, msg)
  }

  const hoy = new Date().toISOString().split('T')[0]
  const citasDia = citas.filter(c => {
    const f = c.fecha?.split('T')[0]
    return f === fecha && (filtro === 'todas' || c.estado === filtro)
  })

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Agenda Médica & Horarios</h1>
          <p className="text-xs text-slate-400">Control de citas con recordatorio WhatsApp directo</p>
        </div>
        <div className="flex gap-2">
          <div className="bg-white p-0.5 rounded-xl border border-slate-200 flex gap-0.5">
            <button onClick={() => setVista('horas')} className={`px-2.5 py-1 rounded-lg text-xs font-bold flex items-center gap-1 ${vista === 'horas' ? 'bg-teal-600 text-white' : 'text-slate-500'}`}>
              <LayoutGrid className="w-3.5 h-3.5" /> Horarios
            </button>
            <button onClick={() => setVista('lista')} className={`px-2.5 py-1 rounded-lg text-xs font-bold flex items-center gap-1 ${vista === 'lista' ? 'bg-teal-600 text-white' : 'text-slate-500'}`}>
              <List className="w-3.5 h-3.5" /> Lista
            </button>
          </div>
          <button onClick={() => { setShowForm(!showForm); setForm({ paciente_id: '', tratamiento_id: '', fecha: `${fecha}T09:00`, duracion_min: 30, notas: '' }) }} className={showForm ? 'btn-secondary' : 'btn-primary'}>
            {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Agendar Cita</>}
          </button>
        </div>
      </div>

      {showForm && (
        <form onSubmit={save} className="card-box space-y-3 border-2 border-teal-200 bg-teal-50/20">
          <h3 className="font-bold text-sm text-teal-800">Agendar Nueva Cita</h3>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Paciente *</label>
              <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
                <option value="">Seleccionar...</option>
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
              <input className="input-field" value={form.notas} onChange={e => setForm({...form, notas: e.target.value})} placeholder="Motivo..." />
            </div>
          </div>
          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> Confirmar Cita</button>
            <button type="button" onClick={() => setShowForm(false)} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      {/* Selector de Fecha */}
      <div className="card-box p-3 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="text-xs font-bold text-slate-500">Día:</span>
          <input type="date" value={fecha} onChange={e => setFecha(e.target.value)} className="input-field w-auto font-bold text-xs" />
        </div>
        <button onClick={() => setFecha(hoy)} className="btn-secondary text-xs py-1">Ir a Hoy</button>
      </div>

      {/* Vista de Horarios con botón WhatsApp */}
      {vista === 'horas' && (
        <div className="card-box p-4 space-y-2">
          <div className="divide-y divide-slate-100">
            {horasJornada.map(hora => {
              const cita = citasDia.find(c => {
                const hCita = new Date(c.fecha).toLocaleTimeString('es-VE', { hour: '2-digit', minute: '2-digit', hour12: false })
                return hCita.startsWith(hora.split(':')[0])
              })

              return (
                <div key={hora} className="py-2.5 flex items-center justify-between gap-3 text-xs">
                  <div className="w-16 font-mono font-bold text-slate-500">{hora}</div>

                  {cita ? (
                    <div className="flex-1 p-2.5 bg-teal-50/80 border border-teal-200 rounded-xl flex items-center justify-between flex-wrap gap-2">
                      <div>
                        <p className="font-bold text-slate-800">{cita.pacientes?.nombres} {cita.pacientes?.apellidos}</p>
                        <p className="text-[11px] text-teal-700">{cita.tratamientos?.nombre || 'Consulta General'}</p>
                      </div>
                      <div className="flex items-center gap-1.5">
                        <button
                          onClick={() => sendWhatsAppReminder(cita)}
                          title="Enviar Recordatorio por WhatsApp"
                          className="p-1.5 bg-emerald-100 hover:bg-emerald-200 text-emerald-800 rounded-lg flex items-center gap-1 font-bold text-[11px]"
                        >
                          <MessageCircle className="w-3.5 h-3.5 text-emerald-600" /> WhatsApp
                        </button>
                        <span className={`badge ${estados[cita.estado]?.bg} ${estados[cita.estado]?.text}`}>
                          {estados[cita.estado]?.label}
                        </span>
                        {cita.estado === 'programada' && (
                          <button onClick={() => setStatus(cita.id, 'confirmada')} className="p-1 text-teal-600 hover:bg-teal-100 rounded">
                            <Check className="w-3.5 h-3.5" />
                          </button>
                        )}
                      </div>
                    </div>
                  ) : (
                    <div className="flex-1 p-2 border border-dashed border-slate-200 rounded-xl flex items-center justify-between text-slate-400">
                      <span className="italic text-[11px]">Disponible</span>
                      <button onClick={() => { setForm({ paciente_id: '', tratamiento_id: '', fecha: `${fecha}T${hora}`, duracion_min: 30, notas: '' }); setShowForm(true) }} className="text-[11px] font-bold text-teal-600 hover:underline">
                        + Agendar
                      </button>
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        </div>
      )}

      {/* Vista Lista */}
      {vista === 'lista' && (
        <div className="space-y-2">
          {citasDia.map(c => (
            <div key={c.id} className={`card-box p-4 border-l-4 ${estados[c.estado]?.color}`}>
              <div className="flex items-center justify-between flex-wrap gap-3">
                <div>
                  <h3 className="font-bold text-sm text-slate-800">{c.pacientes?.nombres} {c.pacientes?.apellidos}</h3>
                  <p className="text-xs text-teal-700">{c.tratamientos?.nombre || 'Consulta General'} • {new Date(c.fecha).toLocaleTimeString('es-VE')}</p>
                </div>
                <div className="flex items-center gap-2">
                  <button onClick={() => sendWhatsAppReminder(c)} className="btn-secondary text-xs py-1 px-2.5 text-emerald-700 bg-emerald-50">
                    <MessageCircle className="w-3.5 h-3.5 text-emerald-600" /> Recordar WhatsApp
                  </button>
                  <span className={`badge ${estados[c.estado]?.bg} ${estados[c.estado]?.text}`}>{estados[c.estado]?.label}</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
