import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import {
  Plus, Check, X, Clock, Calendar as CalIcon, User,
  ChevronLeft, ChevronRight, AlertCircle
} from 'lucide-react'
import toast from 'react-hot-toast'

const estados = {
  programada: { color: 'bg-blue-500', bg: 'bg-blue-50 border-blue-200', text: 'text-blue-800', label: 'Programada', icon: Clock },
  confirmada: { color: 'bg-teal-500', bg: 'bg-teal-50 border-teal-200', text: 'text-teal-800', label: 'Confirmada', icon: Check },
  en_curso: { color: 'bg-amber-500', bg: 'bg-amber-50 border-amber-200', text: 'text-amber-800', label: 'En Curso', icon: AlertCircle },
  completada: { color: 'bg-emerald-500', bg: 'bg-emerald-50 border-emerald-200', text: 'text-emerald-800', label: 'Completada', icon: Check },
  cancelada: { color: 'bg-rose-500', bg: 'bg-rose-50 border-rose-200', text: 'text-rose-800', label: 'Cancelada', icon: X }
}

export default function Citas() {
  const [citas, setCitas] = useState([])
  const [pacs, setPacs] = useState([])
  const [trats, setTrats] = useState([])
  const [modal, setModal] = useState(false)
  const [filtroEstado, setFiltroEstado] = useState('todas')
  const [fechaSeleccionada, setFechaSeleccionada] = useState(new Date().toISOString().split('T')[0])
  const [form, setForm] = useState({ paciente_id: '', tratamiento_id: '', fecha: '', duracion_min: 30, notas: '' })

  const load = async () => {
    const [c, p, t] = await Promise.all([
      supabase.from('citas').select('*, pacientes(nombres, apellidos, telefono), tratamientos(nombre, precio, duracion_min)').order('fecha', { ascending: true }),
      supabase.from('pacientes').select('id, nombres, apellidos, cedula').eq('activo', true).order('nombres'),
      supabase.from('tratamientos').select('id, nombre, precio, duracion_min').eq('activo', true).order('nombre')
    ])
    setCitas(c.data || []); setPacs(p.data || []); setTrats(t.data || [])
  }
  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    const trat = trats.find(t => t.id === form.tratamiento_id)
    await supabase.from('citas').insert([{
      ...form,
      tratamiento_id: form.tratamiento_id || null,
      duracion_min: trat?.duracion_min || form.duracion_min
    }])
    toast.success('Cita agendada correctamente')
    setModal(false); load()
  }

  const setStatus = async (id, estado) => {
    await supabase.from('citas').update({ estado }).eq('id', id)
    toast.success(`Cita → ${estados[estado]?.label || estado}`)
    load()
  }

  const del = async (id) => {
    if (!confirm('¿Eliminar esta cita?')) return
    await supabase.from('citas').delete().eq('id', id)
    toast.success('Cita eliminada'); load()
  }

  // Filtrar citas por fecha seleccionada y estado
  const citasDelDia = citas.filter(c => {
    const fechaCita = c.fecha?.split('T')[0]
    const matchFecha = fechaCita === fechaSeleccionada
    const matchEstado = filtroEstado === 'todas' || c.estado === filtroEstado
    return matchFecha && matchEstado
  })

  // Contar citas por día para el mini calendario
  const citasPorDia = {}
  citas.forEach(c => {
    const d = c.fecha?.split('T')[0]
    if (d) citasPorDia[d] = (citasPorDia[d] || 0) + 1
  })

  // Generar días de la semana actual
  const getDiasSemana = () => {
    const base = new Date(fechaSeleccionada)
    const diaSemana = base.getDay()
    const inicio = new Date(base)
    inicio.setDate(base.getDate() - (diaSemana === 0 ? 6 : diaSemana - 1))
    const dias = []
    for (let i = 0; i < 7; i++) {
      const d = new Date(inicio)
      d.setDate(inicio.getDate() + i)
      dias.push(d)
    }
    return dias
  }

  const diasSemana = getDiasSemana()
  const nombresDia = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
  const hoy = new Date().toISOString().split('T')[0]

  const navegarSemana = (dir) => {
    const d = new Date(fechaSeleccionada)
    d.setDate(d.getDate() + (dir * 7))
    setFechaSeleccionada(d.toISOString().split('T')[0])
  }

  const seleccionarTratamiento = (id) => {
    const t = trats.find(x => x.id === id)
    setForm({ ...form, tratamiento_id: id, duracion_min: t?.duracion_min || 30 })
  }

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Agenda Odontológica</h1>
          <p className="text-xs text-slate-400">{citas.length} citas registradas</p>
        </div>
        <button onClick={() => {
          setForm({ paciente_id: '', tratamiento_id: '', fecha: `${fechaSeleccionada}T09:00`, duracion_min: 30, notas: '' })
          setModal(true)
        }} className="btn-primary">
          <Plus className="w-4 h-4" /> Agendar Cita
        </button>
      </div>

      {/* Mini Calendario Semanal */}
      <div className="card-box space-y-3">
        <div className="flex items-center justify-between">
          <button onClick={() => navegarSemana(-1)} className="p-2 hover:bg-slate-100 rounded-xl"><ChevronLeft className="w-4 h-4" /></button>
          <div className="flex items-center gap-2">
            <button onClick={() => setFechaSeleccionada(hoy)} className="text-xs font-bold text-teal-600 hover:underline">Hoy</button>
            <span className="text-sm font-bold text-slate-700">
              {new Date(fechaSeleccionada).toLocaleDateString('es-VE', { month: 'long', year: 'numeric' })}
            </span>
          </div>
          <button onClick={() => navegarSemana(1)} className="p-2 hover:bg-slate-100 rounded-xl"><ChevronRight className="w-4 h-4" /></button>
        </div>

        <div className="grid grid-cols-7 gap-2">
          {diasSemana.map((d, i) => {
            const fechaStr = d.toISOString().split('T')[0]
            const isSelected = fechaStr === fechaSeleccionada
            const isToday = fechaStr === hoy
            const count = citasPorDia[fechaStr] || 0

            return (
              <button key={i} onClick={() => setFechaSeleccionada(fechaStr)}
                className={`p-2 rounded-xl text-center transition-all ${
                  isSelected ? 'bg-teal-600 text-white shadow-md' :
                  isToday ? 'bg-teal-50 border-2 border-teal-300' : 'hover:bg-slate-50'
                }`}>
                <p className={`text-[10px] font-bold uppercase ${isSelected ? 'text-teal-100' : 'text-slate-400'}`}>{nombresDia[i]}</p>
                <p className={`text-lg font-bold ${isSelected ? 'text-white' : isToday ? 'text-teal-700' : 'text-slate-700'}`}>{d.getDate()}</p>
                {count > 0 && (
                  <span className={`text-[9px] font-bold px-1.5 py-0.5 rounded-full ${
                    isSelected ? 'bg-white/20 text-white' : 'bg-teal-100 text-teal-700'
                  }`}>{count}</span>
                )}
              </button>
            )
          })}
        </div>
      </div>

      {/* Filtros de estado */}
      <div className="flex flex-wrap gap-1.5">
        <button onClick={() => setFiltroEstado('todas')}
          className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${filtroEstado === 'todas' ? 'bg-slate-800 text-white' : 'bg-slate-100 text-slate-600'}`}>
          Todas
        </button>
        {Object.entries(estados).map(([key, val]) => (
          <button key={key} onClick={() => setFiltroEstado(key)}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1 ${
              filtroEstado === key ? `${val.color} text-white` : `${val.bg} ${val.text} border`
            }`}>
            <val.icon className="w-3 h-3" /> {val.label}
          </button>
        ))}
      </div>

      {/* Lista de citas del día */}
      <div className="space-y-2">
        <p className="text-xs font-bold text-slate-400 uppercase">
          Citas para el {new Date(fechaSeleccionada + 'T12:00:00').toLocaleDateString('es-VE', { weekday: 'long', day: 'numeric', month: 'long' })}
        </p>

        {citasDelDia.length === 0 ? (
          <div className="card-box text-center py-12 text-slate-400">
            <CalIcon className="w-10 h-10 mx-auto mb-2 opacity-30" />
            <p className="font-medium text-sm">Sin citas para este día</p>
            <p className="text-xs mt-1">Haz clic en "Agendar Cita" para programar una</p>
          </div>
        ) : (
          citasDelDia.map(c => {
            const est = estados[c.estado] || estados.programada
            const hora = new Date(c.fecha).toLocaleTimeString('es-VE', { hour: '2-digit', minute: '2-digit' })

            return (
              <div key={c.id} className={`card-box p-4 border-l-4 ${est.bg} transition-all`}>
                <div className="flex items-center justify-between flex-wrap gap-3">
                  <div className="flex items-center gap-3">
                    <div className="text-center">
                      <p className="text-lg font-bold text-slate-800">{hora}</p>
                      <p className="text-[10px] text-slate-400">{c.duracion_min} min</p>
                    </div>
                    <div className={`w-1 h-12 rounded-full ${est.color}`} />
                    <div>
                      <h3 className="font-bold text-sm text-slate-800 flex items-center gap-1.5">
                        <User className="w-3.5 h-3.5 text-slate-400" />
                        {c.pacientes?.nombres} {c.pacientes?.apellidos}
                      </h3>
                      <p className="text-xs text-teal-700 font-semibold">{c.tratamientos?.nombre || 'Consulta General'}</p>
                      {c.tratamientos?.precio > 0 && <p className="text-[11px] text-slate-400">${c.tratamientos.precio} USD</p>}
                      {c.notas && <p className="text-[11px] text-slate-400 mt-1 italic">"{c.notas}"</p>}
                    </div>
                  </div>

                  <div className="flex items-center gap-2">
                    <span className={`badge ${est.bg} ${est.text} border`}>
                      <est.icon className="w-3 h-3" /> {est.label}
                    </span>

                    {c.estado === 'programada' && (
                      <div className="flex gap-1">
                        <button onClick={() => setStatus(c.id, 'confirmada')} title="Confirmar" className="p-1.5 bg-teal-50 text-teal-600 rounded-lg hover:bg-teal-100"><Check className="w-4 h-4" /></button>
                        <button onClick={() => setStatus(c.id, 'cancelada')} title="Cancelar" className="p-1.5 bg-rose-50 text-rose-500 rounded-lg hover:bg-rose-100"><X className="w-4 h-4" /></button>
                      </div>
                    )}
                    {c.estado === 'confirmada' && (
                      <button onClick={() => setStatus(c.id, 'completada')} className="p-1.5 bg-emerald-50 text-emerald-600 rounded-lg hover:bg-emerald-100" title="Completar">
                        <Check className="w-4 h-4" />
                      </button>
                    )}
                    {(c.estado === 'programada' || c.estado === 'cancelada') && (
                      <button onClick={() => del(c.id)} className="p-1.5 text-slate-300 hover:text-rose-500 rounded-lg" title="Eliminar">
                        <X className="w-3.5 h-3.5" />
                      </button>
                    )}
                  </div>
                </div>
              </div>
            )
          })
        )}
      </div>

      {/* Modal Agendar */}
      {modal && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-4 shadow-2xl">
            <h2 className="font-bold text-base text-slate-800 flex items-center gap-2"><CalIcon className="w-5 h-5 text-teal-600" /> Agendar Cita</h2>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Paciente *</label>
              <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
                <option value="">Buscar y seleccionar paciente...</option>
                {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos} — {p.cedula || 'S/C'}</option>)}
              </select>
            </div>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Tratamiento / Motivo</label>
              <select className="input-field" value={form.tratamiento_id} onChange={e => seleccionarTratamiento(e.target.value)}>
                <option value="">Consulta General</option>
                {trats.map(t => <option key={t.id} value={t.id}>{t.nombre} — ${t.precio} ({t.duracion_min} min)</option>)}
              </select>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Fecha y Hora *</label>
                <input required type="datetime-local" className="input-field" value={form.fecha} onChange={e => setForm({...form, fecha: e.target.value})} />
              </div>
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Duración</label>
                <select className="input-field" value={form.duracion_min} onChange={e => setForm({...form, duracion_min: parseInt(e.target.value)})}>
                  <option value={15}>15 min</option>
                  <option value={30}>30 min</option>
                  <option value={45}>45 min</option>
                  <option value={60}>1 hora</option>
                  <option value={90}>1.5 horas</option>
                  <option value={120}>2 horas</option>
                </select>
              </div>
            </div>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Notas</label>
              <textarea className="input-field" value={form.notas} onChange={e => setForm({...form, notas: e.target.value})} placeholder="Motivo de consulta, indicaciones previas..." rows={2} />
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <button type="button" onClick={() => setModal(false)} className="btn-secondary">Cancelar</button>
              <button type="submit" className="btn-primary"><Check className="w-3.5 h-3.5" /> Confirmar Cita</button>
            </div>
          </form>
        </div>
      )}
    </div>
  )
}
