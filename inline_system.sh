#!/bin/bash
set -e

echo "🦷 Reconstruyendo sistema sin ventanas emergentes y con cálculo automático..."

# 1. Actualizar SQL - Tabla para vincular insumos a tratamientos
cat > supabase/tratamiento_insumos.sql << 'SQLEOF'
-- TABLA DE INSUMOS POR TRATAMIENTO (para cálculo automático de costos)
CREATE TABLE IF NOT EXISTS tratamiento_insumos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tratamiento_id UUID REFERENCES tratamientos(id) ON DELETE CASCADE,
  producto_id UUID REFERENCES productos(id) ON DELETE CASCADE,
  cantidad INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE tratamiento_insumos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "acc_ti" ON tratamiento_insumos;
CREATE POLICY "acc_ti" ON tratamiento_insumos FOR ALL USING (true) WITH CHECK (true);
SQLEOF

echo "⚠️  IMPORTANTE: Ejecuta el contenido de supabase/tratamiento_insumos.sql en Supabase SQL Editor"

# 2. PACIENTES - Todo inline, sin modales
cat > src/components/Consultorio/Pacientes.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { Plus, Search, Trash2, Phone, Mail, AlertTriangle, User, ChevronDown, ChevronUp, Save, X, Edit3 } from 'lucide-react'
import toast from 'react-hot-toast'

const calcEdad = f => { if (!f) return null; const h = new Date(), n = new Date(f); let e = h.getFullYear() - n.getFullYear(); if (h.getMonth() < n.getMonth() || (h.getMonth() === n.getMonth() && h.getDate() < n.getDate())) e--; return e }
const ini = (n, a) => `${(n||'?')[0]}${(a||'?')[0]}`.toUpperCase()
const cols = ['bg-teal-500','bg-blue-500','bg-violet-500','bg-rose-500','bg-amber-500','bg-emerald-500','bg-indigo-500']
const gc = id => cols[Math.abs((id||'a').charCodeAt(0)) % cols.length]

const blank = { nombres:'', apellidos:'', cedula:'', telefono:'', email:'', fecha_nacimiento:'', alergias:'', antecedentes:'' }

export default function Pacientes() {
  const [list, setList] = useState([])
  const [q, setQ] = useState('')
  const [showForm, setShowForm] = useState(false)
  const [editId, setEditId] = useState(null)
  const [expanded, setExpanded] = useState(null)
  const [form, setForm] = useState(blank)

  const load = async () => { const { data } = await supabase.from('pacientes').select('*').eq('activo', true).order('created_at', { ascending: false }); setList(data || []) }
  useEffect(() => { load() }, [])

  const save = async e => {
    e.preventDefault()
    if (editId) { await supabase.from('pacientes').update(form).eq('id', editId); toast.success('Paciente actualizado') }
    else { await supabase.from('pacientes').insert([form]); toast.success('Paciente registrado') }
    setShowForm(false); setEditId(null); setForm(blank); load()
  }

  const startEdit = p => {
    setForm({ nombres: p.nombres, apellidos: p.apellidos, cedula: p.cedula||'', telefono: p.telefono||'', email: p.email||'', fecha_nacimiento: p.fecha_nacimiento||'', alergias: p.alergias||'', antecedentes: p.antecedentes||'' })
    setEditId(p.id); setShowForm(true); setExpanded(null)
  }

  const del = async id => { if (!confirm('¿Desactivar?')) return; await supabase.from('pacientes').update({ activo: false }).eq('id', id); toast.success('Desactivado'); setExpanded(null); load() }

  const filtered = list.filter(p => `${p.nombres} ${p.apellidos} ${p.cedula} ${p.telefono}`.toLowerCase().includes(q.toLowerCase()))

  const F = ({ label, children }) => <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">{label}</label>{children}</div>

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div><h1 className="text-xl font-bold text-slate-800">Pacientes</h1><p className="text-xs text-slate-400">{list.length} activos</p></div>
        <button onClick={() => { setShowForm(!showForm); setEditId(null); setForm(blank) }} className={showForm ? 'btn-secondary' : 'btn-primary'}>
          {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Nuevo Paciente</>}
        </button>
      </div>

      {/* FORMULARIO INLINE */}
      {showForm && (
        <form onSubmit={save} className="card-box space-y-3 border-2 border-teal-200 bg-teal-50/30">
          <h3 className="font-bold text-sm text-teal-800">{editId ? 'Editar Paciente' : 'Registrar Nuevo Paciente'}</h3>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <F label="Nombres *"><input required className="input-field" value={form.nombres} onChange={e => setForm({...form, nombres: e.target.value})} placeholder="María" /></F>
            <F label="Apellidos *"><input required className="input-field" value={form.apellidos} onChange={e => setForm({...form, apellidos: e.target.value})} placeholder="González" /></F>
            <F label="Cédula"><input className="input-field" value={form.cedula} onChange={e => setForm({...form, cedula: e.target.value})} placeholder="V-12345678" /></F>
            <F label="Nacimiento"><input type="date" className="input-field" value={form.fecha_nacimiento} onChange={e => setForm({...form, fecha_nacimiento: e.target.value})} /></F>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <F label="Teléfono"><input className="input-field" value={form.telefono} onChange={e => setForm({...form, telefono: e.target.value})} placeholder="0412-1234567" /></F>
            <F label="Email"><input type="email" className="input-field" value={form.email} onChange={e => setForm({...form, email: e.target.value})} placeholder="correo@email.com" /></F>
            <F label="⚠️ Alergias"><input className="input-field" value={form.alergias} onChange={e => setForm({...form, alergias: e.target.value})} placeholder="Penicilina, Látex..." /></F>
            <F label="🏥 Antecedentes"><input className="input-field" value={form.antecedentes} onChange={e => setForm({...form, antecedentes: e.target.value})} placeholder="Diabetes, HTA..." /></F>
          </div>
          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> {editId ? 'Actualizar' : 'Guardar'}</button>
            <button type="button" onClick={() => { setShowForm(false); setEditId(null) }} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      {/* BÚSQUEDA */}
      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input placeholder="Buscar por nombre, cédula o teléfono..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
      </div>

      {/* LISTA EXPANDIBLE */}
      <div className="space-y-2">
        {filtered.map(p => (
          <div key={p.id} className="card-box p-0 overflow-hidden">
            {/* Fila principal */}
            <button onClick={() => setExpanded(expanded === p.id ? null : p.id)} className="w-full flex items-center justify-between p-4 hover:bg-slate-50 transition-all text-left">
              <div className="flex items-center gap-3">
                <div className={`w-10 h-10 rounded-xl ${gc(p.id)} text-white flex items-center justify-center font-bold text-sm`}>{ini(p.nombres, p.apellidos)}</div>
                <div>
                  <h3 className="font-bold text-sm text-slate-800">{p.nombres} {p.apellidos}</h3>
                  <p className="text-[11px] text-slate-400">{p.cedula || 'Sin cédula'} {calcEdad(p.fecha_nacimiento) ? `• ${calcEdad(p.fecha_nacimiento)} años` : ''}</p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                {p.alergias && <span className="badge bg-rose-100 text-rose-700 text-[10px]"><AlertTriangle className="w-3 h-3" /> Alergias</span>}
                <span className="text-xs text-slate-400 flex items-center gap-1"><Phone className="w-3 h-3" /> {p.telefono || '—'}</span>
                {expanded === p.id ? <ChevronUp className="w-4 h-4 text-slate-400" /> : <ChevronDown className="w-4 h-4 text-slate-400" />}
              </div>
            </button>

            {/* Detalle expandido */}
            {expanded === p.id && (
              <div className="border-t bg-slate-50 p-4 space-y-3">
                <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-xs">
                  <div><p className="text-slate-400 font-semibold">Teléfono</p><p className="font-bold text-slate-700 flex items-center gap-1"><Phone className="w-3 h-3" /> {p.telefono || '—'}</p></div>
                  <div><p className="text-slate-400 font-semibold">Email</p><p className="font-bold text-slate-700 flex items-center gap-1"><Mail className="w-3 h-3" /> {p.email || '—'}</p></div>
                  <div><p className="text-slate-400 font-semibold">Nacimiento</p><p className="font-bold text-slate-700">{p.fecha_nacimiento ? new Date(p.fecha_nacimiento).toLocaleDateString('es-VE') : '—'}</p></div>
                  <div><p className="text-slate-400 font-semibold">Cédula</p><p className="font-bold text-slate-700">{p.cedula || '—'}</p></div>
                </div>

                {p.alergias && (
                  <div className="p-2.5 bg-rose-50 border border-rose-200 rounded-xl text-rose-700 text-xs font-semibold flex items-center gap-2">
                    <AlertTriangle className="w-4 h-4 shrink-0" /> Alergias: {p.alergias}
                  </div>
                )}

                {p.antecedentes && (
                  <div className="p-2.5 bg-amber-50 border border-amber-200 rounded-xl text-amber-700 text-xs">
                    🏥 Antecedentes: {p.antecedentes}
                  </div>
                )}

                <div className="flex gap-2 pt-1">
                  <button onClick={() => startEdit(p)} className="btn-secondary text-xs"><Edit3 className="w-3.5 h-3.5" /> Editar</button>
                  <button onClick={() => del(p.id)} className="btn-danger text-xs"><Trash2 className="w-3.5 h-3.5" /> Desactivar</button>
                </div>
              </div>
            )}
          </div>
        ))}

        {filtered.length === 0 && (
          <div className="text-center py-12 text-slate-400">
            <User className="w-10 h-10 mx-auto mb-2 opacity-30" />
            <p className="text-sm font-medium">Sin resultados</p>
          </div>
        )}
      </div>
    </div>
  )
}
EOF

# 3. CITAS - Inline sin modal
cat > src/components/Consultorio/Citas.jsx << 'EOF'
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

  const setStatus = async (id, est) => { await supabase.from('citas').update({ estado: est }).eq('id', id); toast.success(estados[est]?.label); load() }
  const del = async id => { if (!confirm('¿Eliminar?')) return; await supabase.from('citas').delete().eq('id', id); toast.success('Eliminada'); load() }

  const hoy = new Date().toISOString().split('T')[0]
  const citasDia = citas.filter(c => { const f = c.fecha?.split('T')[0]; return f === fecha && (filtro === 'todas' || c.estado === filtro) })

  const navSemana = d => { const dt = new Date(fecha); dt.setDate(dt.getDate() + d * 7); setFecha(dt.toISOString().split('T')[0]) }
  const getDias = () => { const base = new Date(fecha); const ds = base.getDay(); const ini = new Date(base); ini.setDate(base.getDate() - (ds === 0 ? 6 : ds - 1)); return Array.from({ length: 7 }, (_, i) => { const d = new Date(ini); d.setDate(ini.getDate() + i); return d }) }
  const dias = getDias()
  const nombresD = ['L', 'M', 'X', 'J', 'V', 'S', 'D']

  const citasPorDia = {}
  citas.forEach(c => { const d = c.fecha?.split('T')[0]; if (d) citasPorDia[d] = (citasPorDia[d] || 0) + 1 })

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div><h1 className="text-xl font-bold text-slate-800">Agenda Odontológica</h1><p className="text-xs text-slate-400">{citas.length} citas totales</p></div>
        <button onClick={() => { setShowForm(!showForm); setForm({ paciente_id: '', tratamiento_id: '', fecha: `${fecha}T09:00`, duracion_min: 30, notas: '' }) }} className={showForm ? 'btn-secondary' : 'btn-primary'}>
          {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Agendar Cita</>}
        </button>
      </div>

      {/* FORMULARIO INLINE */}
      {showForm && (
        <form onSubmit={save} className="card-box space-y-3 border-2 border-teal-200 bg-teal-50/30">
          <h3 className="font-bold text-sm text-teal-800">Nueva Cita</h3>
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

      {/* MINI CALENDARIO */}
      <div className="card-box p-3">
        <div className="flex items-center justify-between mb-2">
          <button onClick={() => navSemana(-1)} className="p-1.5 hover:bg-slate-100 rounded-lg"><ChevronLeft className="w-4 h-4" /></button>
          <button onClick={() => setFecha(hoy)} className="text-xs font-bold text-teal-600 hover:underline">Hoy</button>
          <button onClick={() => navSemana(1)} className="p-1.5 hover:bg-slate-100 rounded-lg"><ChevronRight className="w-4 h-4" /></button>
        </div>
        <div className="grid grid-cols-7 gap-1.5">
          {dias.map((d, i) => {
            const fs = d.toISOString().split('T')[0]
            const sel = fs === fecha, today = fs === hoy, cnt = citasPorDia[fs] || 0
            return (
              <button key={i} onClick={() => setFecha(fs)} className={`py-2 rounded-xl text-center transition-all ${sel ? 'bg-teal-600 text-white shadow' : today ? 'bg-teal-50 border-2 border-teal-300' : 'hover:bg-slate-50'}`}>
                <p className={`text-[10px] font-bold ${sel ? 'text-teal-100' : 'text-slate-400'}`}>{nombresD[i]}</p>
                <p className={`text-sm font-bold ${sel ? 'text-white' : today ? 'text-teal-700' : 'text-slate-700'}`}>{d.getDate()}</p>
                {cnt > 0 && <span className={`text-[8px] font-bold px-1 rounded-full ${sel ? 'bg-white/20 text-white' : 'bg-teal-100 text-teal-700'}`}>{cnt}</span>}
              </button>
            )
          })}
        </div>
      </div>

      {/* FILTROS */}
      <div className="flex flex-wrap gap-1.5">
        <button onClick={() => setFiltro('todas')} className={`px-2.5 py-1 rounded-lg text-xs font-semibold ${filtro === 'todas' ? 'bg-slate-800 text-white' : 'bg-slate-100 text-slate-600'}`}>Todas</button>
        {Object.entries(estados).map(([k, v]) => (
          <button key={k} onClick={() => setFiltro(k)} className={`px-2.5 py-1 rounded-lg text-xs font-semibold ${filtro === k ? 'bg-slate-800 text-white' : `${v.bg} ${v.text}`}`}>{v.label}</button>
        ))}
      </div>

      {/* CITAS DEL DÍA */}
      <div className="space-y-2">
        {citasDia.length === 0 ? (
          <div className="card-box text-center py-10 text-slate-400"><CalIcon className="w-8 h-8 mx-auto mb-2 opacity-30" /><p className="text-sm">Sin citas este día</p></div>
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
                    <button onClick={() => setStatus(c.id, 'confirmada')} className="p-1.5 bg-teal-50 text-teal-600 rounded-lg hover:bg-teal-100" title="Confirmar"><Check className="w-4 h-4" /></button>
                    <button onClick={() => setStatus(c.id, 'cancelada')} className="p-1.5 bg-rose-50 text-rose-500 rounded-lg hover:bg-rose-100" title="Cancelar"><X className="w-4 h-4" /></button>
                  </>}
                  {c.estado === 'confirmada' && <button onClick={() => setStatus(c.id, 'completada')} className="p-1.5 bg-emerald-50 text-emerald-600 rounded-lg" title="Completar"><Check className="w-4 h-4" /></button>}
                </div>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
EOF

# 4. TRATAMIENTOS - Con selección de insumos y cálculo automático de precio
cat > src/components/Consultorio/Tratamientos.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { fmt } from '../../utils/helpers'
import PriceBox from '../UI/PriceBox'
import { Plus, Save, X, Clock, Trash2, Edit3, Package, ChevronDown, ChevronUp } from 'lucide-react'
import toast from 'react-hot-toast'

const catIcons = { 'General':'🔍','Preventivo':'🛡️','Restauración':'🦷','Cirugía':'⚕️','Endodoncia':'🔬','Estético':'✨','Ortodoncia':'😁','Prótesis':'👑','Diagnóstico':'📷' }

export default function Tratamientos() {
  const [list, setList] = useState([])
  const [prods, setProds] = useState([])
  const [insumosTrat, setInsumosTrat] = useState({}) // { tratamiento_id: [ { producto_id, cantidad, producto } ] }
  const [showForm, setShowForm] = useState(false)
  const [editId, setEditId] = useState(null)
  const [expanded, setExpanded] = useState(null)
  const { rates } = useCurrency()

  const [form, setForm] = useState({ nombre: '', descripcion: '', precio: '', duracion_min: 30, categoria: 'General' })
  const [formInsumos, setFormInsumos] = useState([]) // [{ producto_id, cantidad }]

  const load = async () => {
    const [t, p, ti] = await Promise.all([
      supabase.from('tratamientos').select('*').eq('activo', true).order('categoria').order('nombre'),
      supabase.from('productos').select('*').eq('activo', true).order('nombre'),
      supabase.from('tratamiento_insumos').select('*, productos(nombre, precio_venta)').catch(() => ({ data: [] }))
    ])
    setList(t.data || [])
    setProds(p.data || [])

    // Agrupar insumos por tratamiento
    const map = {}
    ;(ti.data || []).forEach(i => {
      if (!map[i.tratamiento_id]) map[i.tratamiento_id] = []
      map[i.tratamiento_id].push(i)
    })
    setInsumosTrat(map)
  }
  useEffect(() => { load() }, [])

  // Calcular costo de insumos seleccionados
  const costoInsumos = formInsumos.reduce((acc, fi) => {
    const prod = prods.find(p => p.id === fi.producto_id)
    return acc + ((prod?.precio_venta || 0) * (fi.cantidad || 0))
  }, 0)

  const precioServicio = parseFloat(form.precio) || 0
  const precioTotal = precioServicio + costoInsumos

  const addInsumo = () => setFormInsumos([...formInsumos, { producto_id: '', cantidad: 1 }])
  const removeInsumo = i => setFormInsumos(formInsumos.filter((_, idx) => idx !== i))
  const updateInsumo = (i, field, val) => setFormInsumos(formInsumos.map((fi, idx) => idx === i ? { ...fi, [field]: val } : fi))

  const save = async e => {
    e.preventDefault()
    const payload = { ...form, precio: precioTotal, duracion_min: parseInt(form.duracion_min) }

    let tratId
    if (editId) {
      await supabase.from('tratamientos').update(payload).eq('id', editId)
      tratId = editId
      // Borrar insumos anteriores
      await supabase.from('tratamiento_insumos').delete().eq('tratamiento_id', editId)
      toast.success('Tratamiento actualizado')
    } else {
      const { data } = await supabase.from('tratamientos').insert([payload]).select().single()
      tratId = data?.id
      toast.success('Tratamiento creado')
    }

    // Guardar insumos vinculados
    if (tratId && formInsumos.length > 0) {
      const validInsumos = formInsumos.filter(fi => fi.producto_id && fi.cantidad > 0)
      if (validInsumos.length > 0) {
        await supabase.from('tratamiento_insumos').insert(
          validInsumos.map(fi => ({ tratamiento_id: tratId, producto_id: fi.producto_id, cantidad: parseInt(fi.cantidad) }))
        )
      }
    }

    setShowForm(false); setEditId(null); setFormInsumos([]); load()
  }

  const startEdit = async t => {
    setForm({ nombre: t.nombre, descripcion: t.descripcion || '', precio: t.precio, duracion_min: t.duracion_min, categoria: t.categoria || 'General' })
    // Cargar insumos existentes
    const existing = insumosTrat[t.id] || []
    setFormInsumos(existing.map(i => ({ producto_id: i.producto_id, cantidad: i.cantidad })))
    setEditId(t.id); setShowForm(true); setExpanded(null)
  }

  const del = async id => { if (!confirm('¿Desactivar?')) return; await supabase.from('tratamientos').update({ activo: false }).eq('id', id); toast.success('Desactivado'); load() }

  // Calcular costo de insumos de un tratamiento existente
  const getCostoInsumosTrat = (tratId) => {
    const ins = insumosTrat[tratId] || []
    return ins.reduce((acc, i) => acc + ((i.productos?.precio_venta || 0) * i.cantidad), 0)
  }

  // Agrupar por categoría
  const grouped = {}
  list.forEach(t => { const c = t.categoria || 'General'; if (!grouped[c]) grouped[c] = []; grouped[c].push(t) })

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div><h1 className="text-xl font-bold text-slate-800">Catálogo de Tratamientos</h1><p className="text-xs text-slate-400">Precios = Servicio + Insumos Automáticos</p></div>
        <button onClick={() => { setShowForm(!showForm); setEditId(null); setForm({ nombre: '', descripcion: '', precio: '', duracion_min: 30, categoria: 'General' }); setFormInsumos([]) }} className={showForm ? 'btn-secondary' : 'btn-primary'}>
          {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Nuevo Tratamiento</>}
        </button>
      </div>

      {/* FORMULARIO INLINE CON SELECTOR DE INSUMOS */}
      {showForm && (
        <form onSubmit={save} className="card-box space-y-4 border-2 border-teal-200 bg-teal-50/30">
          <h3 className="font-bold text-sm text-teal-800">{editId ? 'Editar Tratamiento' : 'Crear Tratamiento'}</h3>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Nombre *</label>
              <input required className="input-field" value={form.nombre} onChange={e => setForm({...form, nombre: e.target.value})} placeholder="Ej: Resina Estética" />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Precio Servicio ($) *</label>
              <input required type="number" step="0.01" min="0" className="input-field" value={form.precio} onChange={e => setForm({...form, precio: e.target.value})} placeholder="30.00" />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Duración</label>
              <select className="input-field" value={form.duracion_min} onChange={e => setForm({...form, duracion_min: e.target.value})}>
                {[15,30,45,60,90,120].map(m => <option key={m} value={m}>{m} min</option>)}
              </select>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Categoría</label>
              <select className="input-field" value={form.categoria} onChange={e => setForm({...form, categoria: e.target.value})}>
                {Object.keys(catIcons).map(c => <option key={c}>{c}</option>)}
              </select>
            </div>
          </div>

          <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Descripción</label>
            <input className="input-field" value={form.descripcion} onChange={e => setForm({...form, descripcion: e.target.value})} placeholder="Detalles del procedimiento..." />
          </div>

          {/* SELECTOR DE INSUMOS */}
          <div className="border-t pt-3 space-y-2">
            <div className="flex justify-between items-center">
              <p className="text-xs font-bold text-slate-600 flex items-center gap-1.5"><Package className="w-3.5 h-3.5 text-teal-600" /> Insumos / Materiales que Usa</p>
              <button type="button" onClick={addInsumo} className="text-xs font-bold text-teal-600 hover:underline flex items-center gap-1"><Plus className="w-3 h-3" /> Añadir Insumo</button>
            </div>

            {formInsumos.map((fi, idx) => {
              const prod = prods.find(p => p.id === fi.producto_id)
              const subtotal = (prod?.precio_venta || 0) * (fi.cantidad || 0)
              return (
                <div key={idx} className="flex items-center gap-2 bg-white p-2 rounded-xl border border-slate-200">
                  <select className="input-field flex-1" value={fi.producto_id} onChange={e => updateInsumo(idx, 'producto_id', e.target.value)}>
                    <option value="">Seleccionar insumo...</option>
                    {prods.map(p => <option key={p.id} value={p.id}>{p.nombre} — ${p.precio_venta} (Stock: {p.stock})</option>)}
                  </select>
                  <input type="number" min="1" className="input-field w-20 text-center" value={fi.cantidad} onChange={e => updateInsumo(idx, 'cantidad', e.target.value)} />
                  <span className="text-xs font-bold text-teal-700 w-20 text-right">{fmt(subtotal)}</span>
                  <button type="button" onClick={() => removeInsumo(idx)} className="p-1 text-rose-400 hover:text-rose-600"><Trash2 className="w-3.5 h-3.5" /></button>
                </div>
              )
            })}

            {formInsumos.length === 0 && <p className="text-xs text-slate-400 italic py-2">Sin insumos vinculados. El precio será solo el del servicio.</p>}
          </div>

          {/* RESUMEN DE PRECIO AUTOMÁTICO */}
          <div className="bg-slate-800 text-white p-4 rounded-xl space-y-1.5 text-sm">
            <div className="flex justify-between"><span className="text-slate-300">Precio del Servicio:</span><span>{fmt(precioServicio)}</span></div>
            <div className="flex justify-between"><span className="text-slate-300">Costo de Insumos ({formInsumos.length}):</span><span>{fmt(costoInsumos)}</span></div>
            <div className="flex justify-between text-base font-bold border-t border-slate-600 pt-2"><span>Precio Total USD:</span><span className="text-teal-400">{fmt(precioTotal)}</span></div>
            <div className="flex justify-between text-xs"><span className="text-slate-400">Total Bs. BCV:</span><span className="text-slate-300">{fmt(precioTotal * rates.VES, 'VES')}</span></div>
            <div className="flex justify-between text-xs"><span className="text-slate-400">Total COP:</span><span className="text-amber-300">{fmt(precioTotal * rates.COP, 'COP')}</span></div>
          </div>

          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> {editId ? 'Actualizar' : 'Crear Tratamiento'}</button>
            <button type="button" onClick={() => { setShowForm(false); setEditId(null) }} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      {/* CATÁLOGO VISUAL */}
      {Object.entries(grouped).map(([cat, items]) => (
        <div key={cat} className="space-y-2">
          <h2 className="text-sm font-bold text-slate-600 flex items-center gap-2">{catIcons[cat] || '🦷'} {cat} <span className="text-[10px] bg-slate-100 px-2 py-0.5 rounded-full">{items.length}</span></h2>

          {items.map(t => {
            const insT = insumosTrat[t.id] || []
            const costoIns = getCostoInsumosTrat(t.id)
            const isExp = expanded === t.id

            return (
              <div key={t.id} className="card-box p-0 overflow-hidden">
                <button onClick={() => setExpanded(isExp ? null : t.id)} className="w-full flex items-center justify-between p-4 hover:bg-slate-50 text-left">
                  <div className="flex items-center gap-3">
                    <span className="text-xl">{catIcons[t.categoria] || '🦷'}</span>
                    <div>
                      <h3 className="font-bold text-sm text-slate-800">{t.nombre}</h3>
                      {t.descripcion && <p className="text-[11px] text-slate-400">{t.descripcion}</p>}
                    </div>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className="text-xs text-slate-400 flex items-center gap-1"><Clock className="w-3 h-3" /> {t.duracion_min}m</span>
                    <PriceBox usd={t.precio} />
                    {insT.length > 0 && <span className="badge bg-violet-50 text-violet-700"><Package className="w-3 h-3" /> {insT.length}</span>}
                    {isExp ? <ChevronUp className="w-4 h-4 text-slate-400" /> : <ChevronDown className="w-4 h-4 text-slate-400" />}
                  </div>
                </button>

                {isExp && (
                  <div className="border-t bg-slate-50 p-4 space-y-3">
                    <div className="text-xs"><PriceBox usd={t.precio} showAll /></div>

                    {insT.length > 0 && (
                      <div className="space-y-1.5">
                        <p className="text-[11px] font-bold text-slate-500 uppercase">Insumos Vinculados:</p>
                        {insT.map(i => (
                          <div key={i.id} className="flex justify-between text-xs bg-white p-2 rounded-lg border">
                            <span className="flex items-center gap-1.5"><Package className="w-3 h-3 text-teal-600" /> {i.productos?.nombre}</span>
                            <span className="font-bold">x{i.cantidad} = {fmt((i.productos?.precio_venta || 0) * i.cantidad)}</span>
                          </div>
                        ))}
                        <div className="flex justify-between text-xs font-bold p-2 bg-violet-50 rounded-lg text-violet-700">
                          <span>Costo Materiales:</span><span>{fmt(costoIns)}</span>
                        </div>
                      </div>
                    )}

                    <div className="flex gap-2 pt-1">
                      <button onClick={() => startEdit(t)} className="btn-secondary text-xs"><Edit3 className="w-3.5 h-3.5" /> Editar</button>
                      <button onClick={() => del(t.id)} className="btn-danger text-xs"><Trash2 className="w-3.5 h-3.5" /> Desactivar</button>
                    </div>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      ))}
    </div>
  )
}
EOF

# 5. HISTORIAL CLÍNICO - Inline
cat > src/components/Consultorio/Historial.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import PriceBox from '../UI/PriceBox'
import { Plus, FileText, CheckCircle2, Clock, Search, User, Save, X } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Historial() {
  const [list, setList] = useState([])
  const [pacs, setPacs] = useState([])
  const [showForm, setShowForm] = useState(false)
  const [q, setQ] = useState('')
  const [filtroPac, setFiltroPac] = useState('')
  const [form, setForm] = useState({ paciente_id: '', diagnostico: '', procedimiento: '', dientes_tratados: '', monto_usd: 0, pagado: true, metodo_pago: 'efectivo_usd' })

  const load = async () => {
    const [h, p] = await Promise.all([
      supabase.from('historial_clinico').select('*, pacientes(nombres, apellidos)').order('created_at', { ascending: false }),
      supabase.from('pacientes').select('id, nombres, apellidos').eq('activo', true).order('nombres')
    ])
    setList(h.data || []); setPacs(p.data || [])
  }
  useEffect(() => { load() }, [])

  const save = async e => {
    e.preventDefault()
    await supabase.from('historial_clinico').insert([{ ...form, monto_usd: parseFloat(form.monto_usd) || 0 }])
    toast.success('Procedimiento registrado'); setShowForm(false); load()
  }

  const metodoLabel = m => ({ efectivo_usd:'Efectivo $', efectivo_ves:'Efectivo Bs.', efectivo_cop:'Efectivo COP', transferencia:'Transferencia', pago_movil:'Pago Móvil', zelle:'Zelle', tarjeta:'Tarjeta', mixto:'Mixto' }[m] || m)

  const filtered = list.filter(h => {
    const mq = `${h.pacientes?.nombres} ${h.pacientes?.apellidos} ${h.procedimiento} ${h.diagnostico}`.toLowerCase().includes(q.toLowerCase())
    const mp = !filtroPac || h.paciente_id === filtroPac
    return mq && mp
  })

  const grouped = {}
  filtered.forEach(h => { const k = h.paciente_id; if (!grouped[k]) grouped[k] = { pac: h.pacientes, items: [] }; grouped[k].items.push(h) })

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div><h1 className="text-xl font-bold text-slate-800">Historial Clínico</h1><p className="text-xs text-slate-400">{list.length} procedimientos</p></div>
        <button onClick={() => setShowForm(!showForm)} className={showForm ? 'btn-secondary' : 'btn-primary'}>
          {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Registrar Procedimiento</>}
        </button>
      </div>

      {showForm && (
        <form onSubmit={save} className="card-box space-y-3 border-2 border-teal-200 bg-teal-50/30">
          <h3 className="font-bold text-sm text-teal-800">Nuevo Procedimiento</h3>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Paciente *</label>
              <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
                <option value="">Seleccionar...</option>{pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
              </select>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Procedimiento *</label>
              <input required className="input-field" value={form.procedimiento} onChange={e => setForm({...form, procedimiento: e.target.value})} placeholder="Resina #14" />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">🦷 Dientes</label>
              <input className="input-field" value={form.dientes_tratados} onChange={e => setForm({...form, dientes_tratados: e.target.value})} placeholder="14, 15, 21" />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Monto $</label>
              <input type="number" step="0.01" min="0" className="input-field" value={form.monto_usd} onChange={e => setForm({...form, monto_usd: e.target.value})} />
            </div>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Diagnóstico</label>
              <input className="input-field" value={form.diagnostico} onChange={e => setForm({...form, diagnostico: e.target.value})} placeholder="Hallazgos..." />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Método Pago</label>
              <select className="input-field" value={form.metodo_pago} onChange={e => setForm({...form, metodo_pago: e.target.value})}>
                {['efectivo_usd','efectivo_ves','efectivo_cop','transferencia','pago_movil','zelle','tarjeta','mixto'].map(m => <option key={m} value={m}>{metodoLabel(m)}</option>)}
              </select>
            </div>
            <div className="flex items-end">
              <label className="flex items-center gap-2 cursor-pointer"><input type="checkbox" checked={form.pagado} onChange={e => setForm({...form, pagado: e.target.checked})} className="w-4 h-4 rounded" /><span className="text-sm font-medium">Cobrado</span></label>
            </div>
          </div>
          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> Guardar</button>
            <button type="button" onClick={() => setShowForm(false)} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      <div className="flex gap-3 flex-wrap">
        <div className="relative flex-1 min-w-[200px]"><Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" /><input placeholder="Buscar..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" /></div>
        <select value={filtroPac} onChange={e => setFiltroPac(e.target.value)} className="input-field w-auto min-w-[180px]">
          <option value="">Todos los pacientes</option>{pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
        </select>
      </div>

      <div className="space-y-4">
        {Object.values(grouped).length === 0 && <div className="text-center py-12 text-slate-400"><FileText className="w-10 h-10 mx-auto mb-2 opacity-30" /><p className="text-sm">Sin registros</p></div>}

        {Object.values(grouped).map((g, i) => (
          <div key={i} className="card-box space-y-3">
            <div className="flex items-center gap-3 pb-2 border-b">
              <div className="w-8 h-8 rounded-lg bg-teal-50 text-teal-600 flex items-center justify-center"><User className="w-4 h-4" /></div>
              <div><h3 className="font-bold text-sm">{g.pac?.nombres} {g.pac?.apellidos}</h3><p className="text-[11px] text-slate-400">{g.items.length} procedimiento{g.items.length !== 1 ? 's' : ''}</p></div>
            </div>

            <div className="relative pl-5 space-y-3">
              <div className="absolute left-[7px] top-1 bottom-1 w-0.5 bg-slate-200" />
              {g.items.map(h => (
                <div key={h.id} className="relative">
                  <div className={`absolute -left-5 top-1 w-3.5 h-3.5 rounded-full border-2 ${h.pagado ? 'bg-emerald-500 border-emerald-300' : 'bg-amber-400 border-amber-200'}`} />
                  <div className="bg-slate-50 rounded-xl p-3 space-y-2">
                    <div className="flex justify-between items-start flex-wrap gap-2">
                      <div>
                        <p className="font-bold text-sm text-teal-700">{h.procedimiento}</p>
                        <p className="text-[11px] text-slate-400">{new Date(h.fecha).toLocaleDateString('es-VE', { day: 'numeric', month: 'short', year: 'numeric' })}</p>
                      </div>
                      <PriceBox usd={h.monto_usd} showAll />
                    </div>
                    {h.diagnostico && <p className="text-xs text-slate-600 bg-white p-2 rounded-lg border"><span className="font-bold text-slate-500">Dx:</span> {h.diagnostico}</p>}
                    <div className="flex items-center gap-2 flex-wrap text-[11px]">
                      {h.dientes_tratados && <span className="badge bg-violet-50 text-violet-700">🦷 {h.dientes_tratados}</span>}
                      <span className={`badge ${h.pagado ? 'bg-emerald-50 text-emerald-700' : 'bg-amber-50 text-amber-700'}`}>{h.pagado ? '✓ Cobrado' : '⏳ Pendiente'}</span>
                      <span className="badge bg-slate-100 text-slate-500">{metodoLabel(h.metodo_pago)}</span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
EOF

echo "📦 Reinstalando dependencias y probando build..."
npm install
npm run build

echo "✅ ¡BUILD EXITOSO! Sistema sin modales y con cálculo automático listo."
