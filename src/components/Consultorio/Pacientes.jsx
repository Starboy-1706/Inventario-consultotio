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

  const load = async () => {
    const { data } = await supabase.from('pacientes').select('*').eq('activo', true).order('created_at', { ascending: false })
    setList(data || [])
  }
  useEffect(() => { load() }, [])

  const save = async e => {
    e.preventDefault()
    if (editId) {
      await supabase.from('pacientes').update(form).eq('id', editId)
      toast.success('Paciente actualizado')
    } else {
      await supabase.from('pacientes').insert([form])
      toast.success('Paciente registrado')
    }
    setShowForm(false); setEditId(null); setForm(blank); load()
  }

  const startEdit = p => {
    setForm({ nombres: p.nombres, apellidos: p.apellidos, cedula: p.cedula||'', telefono: p.telefono||'', email: p.email||'', fecha_nacimiento: p.fecha_nacimiento||'', alergias: p.alergias||'', antecedentes: p.antecedentes||'' })
    setEditId(p.id); setShowForm(true); setExpanded(null)
  }

  const del = async id => {
    if (!confirm('¿Desactivar paciente?')) return
    await supabase.from('pacientes').update({ activo: false }).eq('id', id)
    toast.success('Paciente desactivado'); setExpanded(null); load()
  }

  const filtered = list.filter(p => `${p.nombres} ${p.apellidos} ${p.cedula} ${p.telefono}`.toLowerCase().includes(q.toLowerCase()))

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div><h1 className="text-xl font-bold text-slate-800">Expedientes de Pacientes</h1><p className="text-xs text-slate-400">{list.length} pacientes activos</p></div>
        <button onClick={() => { setShowForm(!showForm); setEditId(null); setForm(blank) }} className={showForm ? 'btn-secondary' : 'btn-primary'}>
          {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Nuevo Paciente</>}
        </button>
      </div>

      {showForm && (
        <form onSubmit={save} className="card-box space-y-3 border-2 border-teal-200 bg-teal-50/20">
          <h3 className="font-bold text-sm text-teal-800">{editId ? 'Editar Paciente' : 'Registrar Nuevo Paciente'}</h3>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Nombres *</label><input required className="input-field" value={form.nombres} onChange={e => setForm({...form, nombres: e.target.value})} placeholder="María" /></div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Apellidos *</label><input required className="input-field" value={form.apellidos} onChange={e => setForm({...form, apellidos: e.target.value})} placeholder="González" /></div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Cédula</label><input className="input-field" value={form.cedula} onChange={e => setForm({...form, cedula: e.target.value})} placeholder="V-12345678" /></div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Nacimiento</label><input type="date" className="input-field" value={form.fecha_nacimiento} onChange={e => setForm({...form, fecha_nacimiento: e.target.value})} /></div>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Teléfono</label><input className="input-field" value={form.telefono} onChange={e => setForm({...form, telefono: e.target.value})} placeholder="0412-1234567" /></div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Email</label><input type="email" className="input-field" value={form.email} onChange={e => setForm({...form, email: e.target.value})} placeholder="correo@email.com" /></div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">⚠️ Alergias</label><input className="input-field" value={form.alergias} onChange={e => setForm({...form, alergias: e.target.value})} placeholder="Penicilina, Látex..." /></div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">🏥 Antecedentes</label><input className="input-field" value={form.antecedentes} onChange={e => setForm({...form, antecedentes: e.target.value})} placeholder="Diabetes, HTA..." /></div>
          </div>
          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> {editId ? 'Actualizar' : 'Guardar Paciente'}</button>
            <button type="button" onClick={() => { setShowForm(false); setEditId(null) }} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input placeholder="Buscar por nombre, cédula o teléfono..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
      </div>

      <div className="space-y-2">
        {filtered.map(p => (
          <div key={p.id} className="card-box p-0 overflow-hidden">
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

            {expanded === p.id && (
              <div className="border-t bg-slate-50 p-4 space-y-3">
                <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-xs">
                  <div><p className="text-slate-400 font-semibold">Teléfono</p><p className="font-bold text-slate-700">{p.telefono || '—'}</p></div>
                  <div><p className="text-slate-400 font-semibold">Email</p><p className="font-bold text-slate-700">{p.email || '—'}</p></div>
                  <div><p className="text-slate-400 font-semibold">Nacimiento</p><p className="font-bold text-slate-700">{p.fecha_nacimiento ? new Date(p.fecha_nacimiento).toLocaleDateString('es-VE') : '—'}</p></div>
                  <div><p className="text-slate-400 font-semibold">Cédula</p><p className="font-bold text-slate-700">{p.cedula || '—'}</p></div>
                </div>

                {p.alergias && (
                  <div className="p-2.5 bg-rose-50 border border-rose-200 rounded-xl text-rose-700 text-xs font-semibold flex items-center gap-2">
                    <AlertTriangle className="w-4 h-4 shrink-0" /> Alergias: {p.alergias}
                  </div>
                )}
                {p.antecedentes && (
                  <div className="p-2.5 bg-amber-50 border border-amber-200 rounded-xl text-amber-800 text-xs">
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
      </div>
    </div>
  )
}
