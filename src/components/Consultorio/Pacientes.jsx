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
