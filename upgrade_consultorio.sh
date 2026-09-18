#!/bin/bash
set -e

echo "🦷 Reconstruyendo módulo de Consultorio con UX profesional..."

# ============================================
# PACIENTES - Fichas visuales con búsqueda inteligente
# ============================================
cat > src/components/Consultorio/Pacientes.jsx << 'PACIENTES_EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import {
  Plus, Search, Trash2, Phone, Mail, AlertTriangle,
  User, Calendar, Heart, Pill, MapPin, X, Edit3, Save
} from 'lucide-react'
import toast from 'react-hot-toast'

const calcularEdad = (fecha) => {
  if (!fecha) return null
  const hoy = new Date()
  const nac = new Date(fecha)
  let edad = hoy.getFullYear() - nac.getFullYear()
  if (hoy.getMonth() < nac.getMonth() || (hoy.getMonth() === nac.getMonth() && hoy.getDate() < nac.getDate())) edad--
  return edad
}

const getInicial = (n, a) => `${(n||'?')[0]}${(a||'?')[0]}`.toUpperCase()

const colores = ['bg-teal-500', 'bg-blue-500', 'bg-violet-500', 'bg-rose-500', 'bg-amber-500', 'bg-emerald-500', 'bg-indigo-500', 'bg-pink-500']
const getColor = (id) => colores[Math.abs(id?.charCodeAt(0) || 0) % colores.length]

export default function Pacientes() {
  const [list, setList] = useState([])
  const [q, setQ] = useState('')
  const [modal, setModal] = useState(false)
  const [ficha, setFicha] = useState(null)
  const [tab, setTab] = useState('datos')
  const [editando, setEditando] = useState(false)
  const [form, setForm] = useState({ nombres: '', apellidos: '', cedula: '', telefono: '', email: '', fecha_nacimiento: '', alergias: '', antecedentes: '' })

  const load = async () => {
    const { data } = await supabase.from('pacientes').select('*').eq('activo', true).order('created_at', { ascending: false })
    setList(data || [])
  }
  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    if (editando && ficha) {
      await supabase.from('pacientes').update(form).eq('id', ficha.id)
      toast.success('Paciente actualizado')
      setFicha({ ...ficha, ...form })
    } else {
      await supabase.from('pacientes').insert([form])
      toast.success('Paciente registrado')
    }
    setModal(false); setEditando(false)
    setForm({ nombres: '', apellidos: '', cedula: '', telefono: '', email: '', fecha_nacimiento: '', alergias: '', antecedentes: '' })
    load()
  }

  const del = async (id) => {
    if (!confirm('¿Desactivar este paciente del sistema?')) return
    await supabase.from('pacientes').update({ activo: false }).eq('id', id)
    toast.success('Paciente desactivado'); setFicha(null); load()
  }

  const openEdit = (p) => {
    setForm({ nombres: p.nombres, apellidos: p.apellidos, cedula: p.cedula || '', telefono: p.telefono || '', email: p.email || '', fecha_nacimiento: p.fecha_nacimiento || '', alergias: p.alergias || '', antecedentes: p.antecedentes || '' })
    setFicha(p); setEditando(true); setModal(true); setTab('datos')
  }

  const filtered = list.filter(p =>
    `${p.nombres} ${p.apellidos} ${p.cedula} ${p.telefono}`.toLowerCase().includes(q.toLowerCase())
  )

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Pacientes</h1>
          <p className="text-xs text-slate-400">{list.length} expedientes activos</p>
        </div>
        <button onClick={() => { setForm({ nombres: '', apellidos: '', cedula: '', telefono: '', email: '', fecha_nacimiento: '', alergias: '', antecedentes: '' }); setEditando(false); setModal(true) }} className="btn-primary">
          <Plus className="w-4 h-4" /> Nuevo Paciente
        </button>
      </div>

      {/* Búsqueda inteligente */}
      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input placeholder="Buscar por nombre, cédula o teléfono..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
        {q && (
          <span className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-slate-400">
            {filtered.length} resultado{filtered.length !== 1 ? 's' : ''}
          </span>
        )}
      </div>

      {/* Grid de tarjetas de pacientes */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        {filtered.map(p => (
          <button key={p.id} onClick={() => { setFicha(p); setTab('datos'); setEditando(false) }}
            className="card-box text-left space-y-3 hover:shadow-md hover:border-teal-200 transition-all group cursor-pointer">
            <div className="flex items-center gap-3">
              <div className={`w-12 h-12 rounded-2xl ${getColor(p.id)} text-white flex items-center justify-center font-bold text-sm shadow-sm`}>
                {getInicial(p.nombres, p.apellidos)}
              </div>
              <div className="flex-1 min-w-0">
                <h3 className="font-bold text-sm text-slate-800 truncate group-hover:text-teal-700">{p.nombres} {p.apellidos}</h3>
                <p className="text-[11px] text-slate-400">{p.cedula || 'Sin cédula'} {calcularEdad(p.fecha_nacimiento) ? `• ${calcularEdad(p.fecha_nacimiento)} años` : ''}</p>
              </div>
            </div>

            <div className="space-y-1.5 text-xs text-slate-500">
              <p className="flex items-center gap-1.5 truncate"><Phone className="w-3 h-3 text-slate-300" /> {p.telefono || 'Sin teléfono'}</p>
              {p.email && <p className="flex items-center gap-1.5 truncate"><Mail className="w-3 h-3 text-slate-300" /> {p.email}</p>}
            </div>

            {p.alergias && (
              <div className="flex items-center gap-1.5 p-2 bg-rose-50 border border-rose-100 rounded-xl text-rose-600 text-[11px] font-semibold">
                <AlertTriangle className="w-3.5 h-3.5 shrink-0" /> {p.alergias}
              </div>
            )}
          </button>
        ))}
      </div>

      {filtered.length === 0 && (
        <div className="text-center py-16 text-slate-400">
          <User className="w-12 h-12 mx-auto mb-3 opacity-30" />
          <p className="font-medium">No se encontraron pacientes</p>
          <p className="text-xs mt-1">Intenta con otro término de búsqueda</p>
        </div>
      )}

      {/* FICHA COMPLETA DEL PACIENTE */}
      {ficha && !modal && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-3xl w-full max-w-lg shadow-2xl overflow-hidden animate-fadeIn">
            {/* Header de ficha */}
            <div className="bg-gradient-to-r from-teal-600 to-teal-700 p-6 text-white relative">
              <button onClick={() => setFicha(null)} className="absolute top-4 right-4 p-1.5 bg-white/20 rounded-lg hover:bg-white/30">
                <X className="w-4 h-4" />
              </button>
              <div className="flex items-center gap-4">
                <div className={`w-16 h-16 rounded-2xl ${getColor(ficha.id)} text-white flex items-center justify-center font-bold text-xl shadow-lg border-2 border-white/30`}>
                  {getInicial(ficha.nombres, ficha.apellidos)}
                </div>
                <div>
                  <h2 className="text-lg font-bold">{ficha.nombres} {ficha.apellidos}</h2>
                  <p className="text-teal-100 text-sm">{ficha.cedula || 'Sin cédula'} {calcularEdad(ficha.fecha_nacimiento) ? `• ${calcularEdad(ficha.fecha_nacimiento)} años` : ''}</p>
                  <div className="flex items-center gap-3 mt-1 text-xs text-teal-200">
                    {ficha.telefono && <span className="flex items-center gap-1"><Phone className="w-3 h-3" />{ficha.telefono}</span>}
                    {ficha.email && <span className="flex items-center gap-1"><Mail className="w-3 h-3" />{ficha.email}</span>}
                  </div>
                </div>
              </div>
            </div>

            {/* Tabs */}
            <div className="flex border-b bg-slate-50">
              {[
                { id: 'datos', label: 'Datos', icon: User },
                { id: 'medico', label: 'Médico', icon: Heart },
                { id: 'acciones', label: 'Acciones', icon: Calendar }
              ].map(t => (
                <button key={t.id} onClick={() => setTab(t.id)}
                  className={`flex-1 py-3 text-xs font-semibold flex items-center justify-center gap-1.5 transition-all ${
                    tab === t.id ? 'text-teal-700 border-b-2 border-teal-600 bg-white' : 'text-slate-400 hover:text-slate-600'
                  }`}>
                  <t.icon className="w-3.5 h-3.5" /> {t.label}
                </button>
              ))}
            </div>

            {/* Contenido de tabs */}
            <div className="p-6 space-y-4 max-h-[50vh] overflow-y-auto">
              {tab === 'datos' && (
                <div className="space-y-3">
                  <InfoRow icon={User} label="Nombre Completo" value={`${ficha.nombres} ${ficha.apellidos}`} />
                  <InfoRow icon={User} label="Cédula" value={ficha.cedula || 'No registrada'} />
                  <InfoRow icon={Calendar} label="Fecha de Nacimiento" value={ficha.fecha_nacimiento ? new Date(ficha.fecha_nacimiento).toLocaleDateString('es-VE') : 'No registrada'} />
                  <InfoRow icon={Phone} label="Teléfono" value={ficha.telefono || 'No registrado'} />
                  <InfoRow icon={Mail} label="Email" value={ficha.email || 'No registrado'} />
                </div>
              )}

              {tab === 'medico' && (
                <div className="space-y-4">
                  <div>
                    <p className="text-xs font-bold text-slate-500 uppercase mb-2 flex items-center gap-1.5"><AlertTriangle className="w-3.5 h-3.5 text-rose-500" /> Alergias</p>
                    {ficha.alergias ? (
                      <div className="p-3 bg-rose-50 border border-rose-200 rounded-xl text-rose-700 text-sm font-medium">{ficha.alergias}</div>
                    ) : (
                      <p className="text-sm text-slate-400 italic">Sin alergias registradas</p>
                    )}
                  </div>
                  <div>
                    <p className="text-xs font-bold text-slate-500 uppercase mb-2 flex items-center gap-1.5"><Heart className="w-3.5 h-3.5 text-red-500" /> Antecedentes Médicos</p>
                    {ficha.antecedentes ? (
                      <div className="p-3 bg-amber-50 border border-amber-200 rounded-xl text-amber-800 text-sm">{ficha.antecedentes}</div>
                    ) : (
                      <p className="text-sm text-slate-400 italic">Sin antecedentes registrados</p>
                    )}
                  </div>
                </div>
              )}

              {tab === 'acciones' && (
                <div className="space-y-3">
                  <p className="text-xs text-slate-400 mb-2">Acciones rápidas para este paciente:</p>
                  <button onClick={() => { setFicha(null); window.location.hash = '#/citas' }} className="w-full btn-primary justify-center py-3">
                    <Calendar className="w-4 h-4" /> Agendar Cita
                  </button>
                  <button onClick={() => { setFicha(null); window.location.hash = '#/historial' }} className="w-full btn-secondary justify-center py-3">
                    <Heart className="w-4 h-4" /> Ver Historial Clínico
                  </button>
                </div>
              )}
            </div>

            {/* Footer de acciones */}
            <div className="p-4 border-t bg-slate-50 flex gap-2">
              <button onClick={() => openEdit(ficha)} className="flex-1 btn-secondary justify-center">
                <Edit3 className="w-3.5 h-3.5" /> Editar
              </button>
              <button onClick={() => del(ficha.id)} className="btn-danger">
                <Trash2 className="w-3.5 h-3.5" /> Desactivar
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal Crear / Editar */}
      {modal && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-4 shadow-2xl">
            <h2 className="font-bold text-base text-slate-800">{editando ? 'Editar Paciente' : 'Nuevo Paciente'}</h2>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Nombres *</label>
                <input required value={form.nombres} onChange={e => setForm({...form, nombres: e.target.value})} className="input-field" placeholder="Ej: María" />
              </div>
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Apellidos *</label>
                <input required value={form.apellidos} onChange={e => setForm({...form, apellidos: e.target.value})} className="input-field" placeholder="Ej: González" />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Cédula</label>
                <input value={form.cedula} onChange={e => setForm({...form, cedula: e.target.value})} className="input-field" placeholder="V-12345678" />
              </div>
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Fecha Nacimiento</label>
                <input type="date" value={form.fecha_nacimiento} onChange={e => setForm({...form, fecha_nacimiento: e.target.value})} className="input-field" />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Teléfono</label>
                <input value={form.telefono} onChange={e => setForm({...form, telefono: e.target.value})} className="input-field" placeholder="0412-1234567" />
              </div>
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Email</label>
                <input type="email" value={form.email} onChange={e => setForm({...form, email: e.target.value})} className="input-field" placeholder="correo@email.com" />
              </div>
            </div>
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">⚠️ Alergias</label>
              <textarea value={form.alergias} onChange={e => setForm({...form, alergias: e.target.value})} className="input-field" rows={2} placeholder="Penicilina, Látex, Anestesia..." />
            </div>
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">🏥 Antecedentes Médicos</label>
              <textarea value={form.antecedentes} onChange={e => setForm({...form, antecedentes: e.target.value})} className="input-field" rows={2} placeholder="Diabetes, Hipertensión, Cardiopatía..." />
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <button type="button" onClick={() => { setModal(false); setEditando(false) }} className="btn-secondary">Cancelar</button>
              <button type="submit" className="btn-primary"><Save className="w-3.5 h-3.5" /> {editando ? 'Actualizar' : 'Registrar'}</button>
            </div>
          </form>
        </div>
      )}
    </div>
  )
}

function InfoRow({ icon: Icon, label, value }) {
  return (
    <div className="flex items-start gap-3 p-2.5 bg-slate-50 rounded-xl">
      <Icon className="w-4 h-4 text-slate-400 mt-0.5 shrink-0" />
      <div>
        <p className="text-[10px] font-bold text-slate-400 uppercase">{label}</p>
        <p className="text-sm text-slate-700 font-medium">{value}</p>
      </div>
    </div>
  )
}
PACIENTES_EOF

# ============================================
# CITAS - Agenda visual tipo calendario
# ============================================
cat > src/components/Consultorio/Citas.jsx << 'CITAS_EOF'
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
CITAS_EOF

# ============================================
# HISTORIAL CLÍNICO - Timeline visual
# ============================================
cat > src/components/Consultorio/Historial.jsx << 'HISTORIAL_EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import PriceBox from '../UI/PriceBox'
import {
  Plus, FileText, CheckCircle2, Clock, Search,
  Filter, User, Tooth
} from 'lucide-react'
import toast from 'react-hot-toast'

export default function Historial() {
  const [list, setList] = useState([])
  const [pacs, setPacs] = useState([])
  const [modal, setModal] = useState(false)
  const [q, setQ] = useState('')
  const [filtroPac, setFiltroPac] = useState('')
  const [form, setForm] = useState({
    paciente_id: '', diagnostico: '', procedimiento: '',
    dientes_tratados: '', monto_usd: 0, pagado: true, metodo_pago: 'efectivo_usd'
  })

  const load = async () => {
    const [h, p] = await Promise.all([
      supabase.from('historial_clinico').select('*, pacientes(nombres, apellidos, cedula)').order('created_at', { ascending: false }),
      supabase.from('pacientes').select('id, nombres, apellidos').eq('activo', true).order('nombres')
    ])
    setList(h.data || []); setPacs(p.data || [])
  }
  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    await supabase.from('historial_clinico').insert([{ ...form, monto_usd: parseFloat(form.monto_usd) || 0 }])
    toast.success('Procedimiento registrado en expediente')
    setModal(false); load()
  }

  const filtered = list.filter(h => {
    const matchQ = `${h.pacientes?.nombres} ${h.pacientes?.apellidos} ${h.procedimiento} ${h.diagnostico}`.toLowerCase().includes(q.toLowerCase())
    const matchPac = !filtroPac || h.paciente_id === filtroPac
    return matchQ && matchPac
  })

  // Agrupar por paciente para el timeline
  const grouped = {}
  filtered.forEach(h => {
    const key = h.paciente_id
    if (!grouped[key]) grouped[key] = { paciente: h.pacientes, items: [] }
    grouped[key].items.push(h)
  })

  const metodoLabel = (m) => ({
    efectivo_usd: 'Efectivo $', efectivo_ves: 'Efectivo Bs.', efectivo_cop: 'Efectivo COP',
    transferencia: 'Transferencia', pago_movil: 'Pago Móvil', zelle: 'Zelle', tarjeta: 'Tarjeta', mixto: 'Mixto'
  }[m] || m)

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Historial Clínico</h1>
          <p className="text-xs text-slate-400">{list.length} procedimientos registrados</p>
        </div>
        <button onClick={() => setModal(true)} className="btn-primary"><Plus className="w-4 h-4" /> Registrar Procedimiento</button>
      </div>

      {/* Filtros */}
      <div className="flex gap-3 flex-wrap">
        <div className="relative flex-1 min-w-[200px]">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input placeholder="Buscar procedimiento, diagnóstico..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
        </div>
        <select value={filtroPac} onChange={e => setFiltroPac(e.target.value)} className="input-field w-auto min-w-[180px]">
          <option value="">Todos los pacientes</option>
          {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
        </select>
      </div>

      {/* Timeline por paciente */}
      <div className="space-y-6">
        {Object.values(grouped).length === 0 && (
          <div className="text-center py-16 text-slate-400">
            <FileText className="w-12 h-12 mx-auto mb-3 opacity-30" />
            <p className="font-medium">Sin registros clínicos</p>
          </div>
        )}

        {Object.values(grouped).map((g, gi) => (
          <div key={gi} className="card-box space-y-4">
            {/* Header del paciente */}
            <div className="flex items-center gap-3 pb-3 border-b border-slate-100">
              <div className="w-10 h-10 rounded-xl bg-teal-50 text-teal-600 flex items-center justify-center font-bold text-sm">
                <User className="w-5 h-5" />
              </div>
              <div>
                <h3 className="font-bold text-sm text-slate-800">{g.paciente?.nombres} {g.paciente?.apellidos}</h3>
                <p className="text-[11px] text-slate-400">{g.items.length} procedimiento{g.items.length !== 1 ? 's' : ''}</p>
              </div>
            </div>

            {/* Timeline items */}
            <div className="relative pl-6 space-y-4">
              <div className="absolute left-[9px] top-2 bottom-2 w-0.5 bg-slate-200" />

              {g.items.map((h, hi) => (
                <div key={h.id} className="relative">
                  <div className={`absolute -left-6 top-1 w-[18px] h-[18px] rounded-full border-2 flex items-center justify-center ${
                    h.pagado ? 'bg-emerald-500 border-emerald-300' : 'bg-amber-400 border-amber-200'
                  }`}>
                    {h.pagado ? <CheckCircle2 className="w-2.5 h-2.5 text-white" /> : <Clock className="w-2.5 h-2.5 text-white" />}
                  </div>

                  <div className="bg-slate-50 rounded-xl p-4 space-y-2">
                    <div className="flex justify-between items-start flex-wrap gap-2">
                      <div>
                        <p className="font-bold text-sm text-teal-700">{h.procedimiento}</p>
                        <p className="text-xs text-slate-500 mt-0.5">
                          {new Date(h.fecha).toLocaleDateString('es-VE', { day: 'numeric', month: 'short', year: 'numeric' })}
                        </p>
                      </div>
                      <PriceBox usd={h.monto_usd} showAll />
                    </div>

                    {h.diagnostico && (
                      <p className="text-xs text-slate-600 bg-white p-2 rounded-lg border border-slate-100">
                        <span className="font-bold text-slate-500">Dx:</span> {h.diagnostico}
                      </p>
                    )}

                    <div className="flex items-center gap-3 flex-wrap">
                      {h.dientes_tratados && (
                        <span className="badge bg-violet-50 text-violet-700 border border-violet-100">
                          <Tooth className="w-3 h-3" /> Dientes: {h.dientes_tratados}
                        </span>
                      )}
                      <span className={`badge ${h.pagado ? 'bg-emerald-50 text-emerald-700 border-emerald-100' : 'bg-amber-50 text-amber-700 border-amber-100'}`}>
                        {h.pagado ? '✓ Cobrado' : '⏳ Pendiente'}
                      </span>
                      <span className="badge bg-slate-100 text-slate-500">{metodoLabel(h.metodo_pago)}</span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>

      {/* Modal */}
      {modal && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-4 shadow-2xl">
            <h2 className="font-bold text-base text-slate-800">Registrar Procedimiento</h2>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Paciente *</label>
              <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
                <option value="">Seleccionar paciente...</option>
                {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
              </select>
            </div>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Procedimiento Realizado *</label>
              <input required className="input-field" value={form.procedimiento} onChange={e => setForm({...form, procedimiento: e.target.value})} placeholder="Ej: Resina Fotocurada #14, Limpieza" />
            </div>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">🦷 Dientes Tratados</label>
              <input className="input-field" value={form.dientes_tratados} onChange={e => setForm({...form, dientes_tratados: e.target.value})} placeholder="Ej: 14, 15, 21, 36" />
            </div>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Diagnóstico</label>
              <textarea className="input-field" value={form.diagnostico} onChange={e => setForm({...form, diagnostico: e.target.value})} placeholder="Hallazgos clínicos, observaciones..." rows={2} />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Monto ($ USD)</label>
                <input type="number" step="0.01" min="0" className="input-field" value={form.monto_usd} onChange={e => setForm({...form, monto_usd: e.target.value})} />
              </div>
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Método de Pago</label>
                <select className="input-field" value={form.metodo_pago} onChange={e => setForm({...form, metodo_pago: e.target.value})}>
                  <option value="efectivo_usd">Efectivo $</option>
                  <option value="efectivo_ves">Efectivo Bs.</option>
                  <option value="efectivo_cop">Efectivo COP</option>
                  <option value="transferencia">Transferencia</option>
                  <option value="pago_movil">Pago Móvil</option>
                  <option value="zelle">Zelle</option>
                  <option value="tarjeta">Tarjeta</option>
                  <option value="mixto">Mixto</option>
                </select>
              </div>
            </div>

            <label className="flex items-center gap-2 cursor-pointer">
              <input type="checkbox" checked={form.pagado} onChange={e => setForm({...form, pagado: e.target.checked})} className="w-4 h-4 rounded text-teal-600" />
              <span className="text-sm font-medium text-slate-700">Marcar como cobrado</span>
            </label>

            <div className="flex justify-end gap-2 pt-2">
              <button type="button" onClick={() => setModal(false)} className="btn-secondary">Cancelar</button>
              <button type="submit" className="btn-primary">Guardar en Expediente</button>
            </div>
          </form>
        </div>
      )}
    </div>
  )
}
HISTORIAL_EOF

# ============================================
# TRATAMIENTOS - Catálogo visual con iconos
# ============================================
cat > src/components/Consultorio/Tratamientos.jsx << 'TRATAMIENTOS_EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import PriceBox from '../UI/PriceBox'
import { Plus, Clock, Edit3, Trash2, Search, Save, X } from 'lucide-react'
import toast from 'react-hot-toast'

const catIcons = {
  'General': '🔍', 'Preventivo': '🛡️', 'Restauración': '🦷',
  'Cirugía': '⚕️', 'Endodoncia': '🔬', 'Estético': '✨',
  'Ortodoncia': '😁', 'Prótesis': '👑', 'Diagnóstico': '📷'
}

const catColors = {
  'General': 'from-slate-500 to-slate-600',
  'Preventivo': 'from-emerald-500 to-emerald-600',
  'Restauración': 'from-blue-500 to-blue-600',
  'Cirugía': 'from-rose-500 to-rose-600',
  'Endodoncia': 'from-violet-500 to-violet-600',
  'Estético': 'from-pink-500 to-pink-600',
  'Ortodoncia': 'from-amber-500 to-amber-600',
  'Prótesis': 'from-indigo-500 to-indigo-600',
  'Diagnóstico': 'from-cyan-500 to-cyan-600'
}

export default function Tratamientos() {
  const [list, setList] = useState([])
  const [modal, setModal] = useState(false)
  const [editando, setEditando] = useState(null)
  const [q, setQ] = useState('')
  const [form, setForm] = useState({ nombre: '', precio: '', duracion_min: 30, categoria: 'General', descripcion: '' })

  const load = async () => {
    const { data } = await supabase.from('tratamientos').select('*').eq('activo', true).order('categoria').order('nombre')
    setList(data || [])
  }
  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    const payload = { ...form, precio: parseFloat(form.precio), duracion_min: parseInt(form.duracion_min) }
    if (editando) {
      await supabase.from('tratamientos').update(payload).eq('id', editando)
      toast.success('Tratamiento actualizado')
    } else {
      await supabase.from('tratamientos').insert([payload])
      toast.success('Tratamiento creado')
    }
    setModal(false); setEditando(null); load()
  }

  const del = async (id) => {
    if (!confirm('¿Desactivar este tratamiento?')) return
    await supabase.from('tratamientos').update({ activo: false }).eq('id', id)
    toast.success('Desactivado'); load()
  }

  const openEdit = (t) => {
    setForm({ nombre: t.nombre, precio: t.precio, duracion_min: t.duracion_min, categoria: t.categoria || 'General', descripcion: t.descripcion || '' })
    setEditando(t.id); setModal(true)
  }

  const filtered = list.filter(t =>
    `${t.nombre} ${t.categoria} ${t.descripcion}`.toLowerCase().includes(q.toLowerCase())
  )

  // Agrupar por categoría
  const grouped = {}
  filtered.forEach(t => {
    const cat = t.categoria || 'General'
    if (!grouped[cat]) grouped[cat] = []
    grouped[cat].push(t)
  })

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Catálogo de Tratamientos</h1>
          <p className="text-xs text-slate-400">Precios en USD, VES (BCV) y COP</p>
        </div>
        <button onClick={() => { setForm({ nombre: '', precio: '', duracion_min: 30, categoria: 'General', descripcion: '' }); setEditando(null); setModal(true) }} className="btn-primary">
          <Plus className="w-4 h-4" /> Nuevo Tratamiento
        </button>
      </div>

      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input placeholder="Buscar tratamiento..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
      </div>

      {/* Catálogo agrupado por categoría */}
      {Object.entries(grouped).map(([cat, items]) => (
        <div key={cat} className="space-y-3">
          <h2 className="text-sm font-bold text-slate-600 flex items-center gap-2">
            <span className="text-lg">{catIcons[cat] || '🦷'}</span> {cat}
            <span className="text-[10px] bg-slate-100 text-slate-500 px-2 py-0.5 rounded-full">{items.length}</span>
          </h2>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {items.map(t => (
              <div key={t.id} className="card-box space-y-3 hover:shadow-md transition-all group relative">
                <div className="flex items-start justify-between">
                  <div className={`w-10 h-10 rounded-xl bg-gradient-to-br ${catColors[t.categoria] || catColors.General} text-white flex items-center justify-center text-lg shadow-sm`}>
                    {catIcons[t.categoria] || '🦷'}
                  </div>
                  <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button onClick={() => openEdit(t)} className="p-1.5 hover:bg-slate-100 rounded-lg text-slate-400"><Edit3 className="w-3.5 h-3.5" /></button>
                    <button onClick={() => del(t.id)} className="p-1.5 hover:bg-rose-50 rounded-lg text-rose-400"><Trash2 className="w-3.5 h-3.5" /></button>
                  </div>
                </div>

                <div>
                  <h3 className="font-bold text-sm text-slate-800">{t.nombre}</h3>
                  {t.descripcion && <p className="text-[11px] text-slate-400 mt-0.5 line-clamp-2">{t.descripcion}</p>}
                </div>

                <div className="flex items-center gap-1.5 text-[11px] text-slate-400">
                  <Clock className="w-3 h-3" /> ~{t.duracion_min} minutos
                </div>

                <div className="pt-3 border-t border-slate-100">
                  <PriceBox usd={t.precio} showAll />
                </div>
              </div>
            ))}
          </div>
        </div>
      ))}

      {/* Modal */}
      {modal && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-4 shadow-2xl">
            <div className="flex justify-between items-center">
              <h2 className="font-bold text-base text-slate-800">{editando ? 'Editar' : 'Nuevo'} Tratamiento</h2>
              <button type="button" onClick={() => { setModal(false); setEditando(null) }} className="text-slate-400 hover:text-slate-600"><X className="w-4 h-4" /></button>
            </div>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Nombre del Tratamiento *</label>
              <input required className="input-field" value={form.nombre} onChange={e => setForm({...form, nombre: e.target.value})} placeholder="Ej: Resina Estética Anterior" />
            </div>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Descripción</label>
              <textarea className="input-field" value={form.descripcion} onChange={e => setForm({...form, descripcion: e.target.value})} placeholder="Detalles del procedimiento..." rows={2} />
            </div>

            <div className="grid grid-cols-3 gap-3">
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Precio USD *</label>
                <input required type="number" step="0.01" min="0" className="input-field" value={form.precio} onChange={e => setForm({...form, precio: e.target.value})} />
              </div>
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Duración</label>
                <select className="input-field" value={form.duracion_min} onChange={e => setForm({...form, duracion_min: e.target.value})}>
                  <option value={15}>15 min</option>
                  <option value={30}>30 min</option>
                  <option value={45}>45 min</option>
                  <option value={60}>1 hora</option>
                  <option value={90}>1.5 hrs</option>
                  <option value={120}>2 hrs</option>
                </select>
              </div>
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Categoría</label>
                <select className="input-field" value={form.categoria} onChange={e => setForm({...form, categoria: e.target.value})}>
                  {Object.keys(catIcons).map(c => <option key={c} value={c}>{catIcons[c]} {c}</option>)}
                </select>
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <button type="button" onClick={() => { setModal(false); setEditando(null) }} className="btn-secondary">Cancelar</button>
              <button type="submit" className="btn-primary"><Save className="w-3.5 h-3.5" /> {editando ? 'Actualizar' : 'Crear'}</button>
            </div>
          </form>
        </div>
      )}
    </div>
  )
}
TRATAMIENTOS_EOF

echo "✅ Módulo de Consultorio reconstruido con UX profesional!"
