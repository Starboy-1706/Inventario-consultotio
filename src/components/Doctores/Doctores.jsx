import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { UserCheck, Plus, Trash2, Edit3, Save, X, Phone, Mail, Award, Percent } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Doctores() {
  const [list, setList] = useState([])
  const [showForm, setShowForm] = useState(false)
  const [editId, setEditId] = useState(null)

  const [form, setForm] = useState({
    nombres: '',
    apellidos: '',
    especialidad: 'Odontología General',
    telefono: '',
    email: '',
    porcentaje_comision: 50,
    color: '#0d9488'
  })

  const load = async () => {
    const { data } = await supabase.from('doctores').select('*').eq('activo', true).order('nombres')
    setList(data || [])
  }

  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    const payload = {
      ...form,
      porcentaje_comision: parseFloat(form.porcentaje_comision) || 0
    }

    if (editId) {
      await supabase.from('doctores').update(payload).eq('id', editId)
      toast.success('Doctor actualizado')
    } else {
      await supabase.from('doctores').insert([payload])
      toast.success('Doctor registrado')
    }

    setShowForm(false); setEditId(null); setForm({ nombres: '', apellidos: '', especialidad: 'Odontología General', telefono: '', email: '', porcentaje_comision: 50, color: '#0d9488' }); load()
  }

  const startEdit = (d) => {
    setForm({
      nombres: d.nombres,
      apellidos: d.apellidos,
      especialidad: d.especialidad || 'Odontología General',
      telefono: d.telefono || '',
      email: d.email || '',
      porcentaje_comision: d.porcentaje_comision || 50,
      color: d.color || '#0d9488'
    })
    setEditId(d.id); setShowForm(true)
  }

  const del = async (id) => {
    if (!confirm('¿Desactivar este doctor?')) return
    await supabase.from('doctores').update({ activo: false }).eq('id', id)
    toast.success('Doctor desactivado'); load()
  }

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Equipo de Doctores & Especialistas</h1>
          <p className="text-xs text-slate-400">Control de profesionales, especialidades y porcentajes de honorarios</p>
        </div>
        <button onClick={() => { setShowForm(!showForm); setEditId(null) }} className={showForm ? 'btn-secondary' : 'btn-primary'}>
          {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Agregar Especialista</>}
        </button>
      </div>

      {showForm && (
        <form onSubmit={save} className="card-box space-y-4 border-2 border-teal-200 bg-teal-50/20">
          <h3 className="font-bold text-sm text-teal-800">{editId ? 'Editar Doctor' : 'Nuevo Doctor / Especialista'}</h3>
          <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Nombres *</label>
              <input required className="input-field" value={form.nombres} onChange={e => setForm({...form, nombres: e.target.value})} placeholder="Dr. Carlos" />
            </div>
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Apellidos *</label>
              <input required className="input-field" value={form.apellidos} onChange={e => setForm({...form, apellidos: e.target.value})} placeholder="Ramírez" />
            </div>
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Especialidad</label>
              <select className="input-field" value={form.especialidad} onChange={e => setForm({...form, especialidad: e.target.value})}>
                <option value="Odontología General">Odontología General</option>
                <option value="Ortodoncia">Ortodoncia</option>
                <option value="Endodoncia">Endodoncia</option>
                <option value="Periodoncia">Periodoncia</option>
                <option value="Cirugía Maxilofacial">Cirugía Maxilofacial</option>
                <option value="Odontopediatría">Odontopediatría</option>
                <option value="Implantología & Prótesis">Implantología & Prótesis</option>
                <option value="Estética Dental">Estética Dental</option>
              </select>
            </div>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Teléfono</label>
              <input className="input-field" value={form.telefono} onChange={e => setForm({...form, telefono: e.target.value})} placeholder="0412-1234567" />
            </div>
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Email</label>
              <input type="email" className="input-field" value={form.email} onChange={e => setForm({...form, email: e.target.value})} placeholder="doctor@clinicadental.com" />
            </div>
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">% Honorarios / Comisión</label>
              <input type="number" min="0" max="100" className="input-field font-bold" value={form.porcentaje_comision} onChange={e => setForm({...form, porcentaje_comision: e.target.value})} />
            </div>
          </div>

          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> {editId ? 'Actualizar' : 'Guardar Especialista'}</button>
            <button type="button" onClick={() => setShowForm(false)} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      {/* Grid de Doctores */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {list.map(d => (
          <div key={d.id} className="card-box space-y-3 relative border hover:border-teal-300 transition-all">
            <div className="flex items-center gap-3">
              <div className="w-12 h-12 rounded-2xl bg-teal-50 text-teal-700 flex items-center justify-center font-bold text-lg">
                <UserCheck className="w-6 h-6" />
              </div>
              <div>
                <h3 className="font-bold text-sm text-slate-800">{d.nombres} {d.apellidos}</h3>
                <span className="badge bg-teal-50 text-teal-800 border border-teal-100 mt-0.5">{d.especialidad}</span>
              </div>
            </div>

            <div className="text-xs space-y-1 text-slate-500 pt-2 border-t border-slate-100">
              {d.telefono && <p className="flex items-center gap-1.5"><Phone className="w-3 h-3 text-slate-400" /> {d.telefono}</p>}
              {d.email && <p className="flex items-center gap-1.5"><Mail className="w-3 h-3 text-slate-400" /> {d.email}</p>}
              <p className="flex items-center gap-1.5 font-bold text-teal-700 pt-1">
                <Percent className="w-3 h-3 text-teal-600" /> {d.porcentaje_comision}% de Honorarios
              </p>
            </div>

            <div className="flex gap-1 pt-1 justify-end">
              <button onClick={() => startEdit(d)} className="p-1.5 hover:bg-slate-100 text-slate-500 rounded"><Edit3 className="w-3.5 h-3.5" /></button>
              <button onClick={() => del(d.id)} className="p-1.5 hover:bg-rose-50 text-rose-500 rounded"><Trash2 className="w-3.5 h-3.5" /></button>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
