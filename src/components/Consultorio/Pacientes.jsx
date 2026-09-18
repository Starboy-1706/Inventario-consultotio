import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { Plus, User, Search, Trash2, Phone, AlertCircle } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Pacientes() {
  const [list, setList] = useState([])
  const [q, setQ] = useState('')
  const [modal, setModal] = useState(false)
  const [form, setForm] = useState({ nombres: '', apellidos: '', cedula: '', telefono: '', email: '', alergias: '', antecedentes: '' })

  const load = async () => {
    const { data } = await supabase.from('pacientes').select('*').eq('activo', true).order('created_at', { ascending: false })
    setList(data || [])
  }
  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    await supabase.from('pacientes').insert([form])
    toast.success('Paciente registrado con éxito')
    setModal(false); setForm({ nombres: '', apellidos: '', cedula: '', telefono: '', email: '', alergias: '', antecedentes: '' }); load()
  }

  const del = async (id) => {
    if (confirm('¿Desea desactivar este paciente?')) {
      await supabase.from('pacientes').update({ activo: false }).eq('id', id)
      toast.success('Paciente desactivado'); load()
    }
  }

  const filtered = list.filter(p => `${p.nombres} ${p.apellidos} ${p.cedula}`.toLowerCase().includes(q.toLowerCase()))

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Fichas de Pacientes</h1>
          <p className="text-xs text-slate-400">Expedientes clínicos y antecedentes</p>
        </div>
        <button onClick={() => setModal(true)} className="btn-primary"><Plus className="w-4 h-4" /> Nuevo Paciente</button>
      </div>

      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input placeholder="Buscar por nombre o cédula..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {filtered.map(p => (
          <div key={p.id} className="card-box space-y-3 relative">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-teal-50 text-teal-600 flex items-center justify-center font-bold">
                <User className="w-5 h-5" />
              </div>
              <div>
                <h3 className="font-bold text-sm text-slate-800">{p.nombres} {p.apellidos}</h3>
                <p className="text-xs text-slate-400">CI: {p.cedula || 'Sin registrar'}</p>
              </div>
            </div>

            <div className="text-xs space-y-1.5 text-slate-600 border-t border-slate-100 pt-3">
              <p className="flex items-center gap-1.5"><Phone className="w-3.5 h-3.5 text-slate-400" /> {p.telefono || 'Sin teléfono'}</p>
              {p.alergias && (
                <div className="p-2 bg-rose-50 border border-rose-100 rounded-lg text-rose-700 font-medium flex items-center gap-1.5">
                  <AlertCircle className="w-4 h-4 shrink-0" /> Alergias: {p.alergias}
                </div>
              )}
            </div>

            <button onClick={() => del(p.id)} className="absolute top-4 right-4 text-slate-300 hover:text-rose-600 transition-colors">
              <Trash2 className="w-4 h-4" />
            </button>
          </div>
        ))}
      </div>

      {modal && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-4 shadow-2xl">
            <h2 className="font-bold text-base text-slate-800">Registrar Nuevo Paciente</h2>
            <div className="grid grid-cols-2 gap-3">
              <input required placeholder="Nombres" value={form.nombres} onChange={e => setForm({...form, nombres: e.target.value})} className="input-field" />
              <input required placeholder="Apellidos" value={form.apellidos} onChange={e => setForm({...form, apellidos: e.target.value})} className="input-field" />
            </div>
            <input placeholder="Cédula / Documento" value={form.cedula} onChange={e => setForm({...form, cedula: e.target.value})} className="input-field" />
            <input placeholder="Teléfono" value={form.telefono} onChange={e => setForm({...form, telefono: e.target.value})} className="input-field" />
            <textarea placeholder="Alergias conocidas (ej. Penicilina, Látex)" value={form.alergias} onChange={e => setForm({...form, alergias: e.target.value})} className="input-field" rows={2} />
            <textarea placeholder="Antecedentes médicos (ej. Hipertensión)" value={form.antecedentes} onChange={e => setForm({...form, antecedentes: e.target.value})} className="input-field" rows={2} />

            <div className="flex justify-end gap-2 pt-2">
              <button type="button" onClick={() => setModal(false)} className="btn-secondary">Cancelar</button>
              <button type="submit" className="btn-primary">Guardar Paciente</button>
            </div>
          </form>
        </div>
      )}
    </div>
  )
}
