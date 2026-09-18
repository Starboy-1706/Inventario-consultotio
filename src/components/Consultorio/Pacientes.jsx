import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { Plus, User, Search, Trash2 } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Pacientes() {
  const [list, setList] = useState([])
  const [q, setQ] = useState('')
  const [modal, setModal] = useState(false)
  const [form, setForm] = useState({ nombres: '', apellidos: '', cedula: '', telefono: '', alergias: '' })

  const load = async () => {
    const { data } = await supabase.from('pacientes').select('*').eq('activo', true).order('created_at', { ascending: false })
    setList(data || [])
  }
  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    await supabase.from('pacientes').insert([form])
    toast.success('Paciente registrado')
    setModal(false); setForm({ nombres: '', apellidos: '', cedula: '', telefono: '', alergias: '' }); load()
  }

  const del = async (id) => {
    if (confirm('¿Eliminar paciente?')) {
      await supabase.from('pacientes').update({ activo: false }).eq('id', id)
      toast.success('Paciente eliminado'); load()
    }
  }

  const filtered = list.filter(p => `${p.nombres} ${p.apellidos} ${p.cedula}`.toLowerCase().includes(q.toLowerCase()))

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <div><h1 className="text-xl font-bold">Pacientes del Consultorio</h1><p className="text-xs text-slate-400">Control clínico</p></div>
        <button onClick={() => setModal(true)} className="btn-primary"><Plus className="w-4 h-4" /> Nuevo Paciente</button>
      </div>

      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
        <input placeholder="Buscar por nombre o cédula..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-9" />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
        {filtered.map(p => (
          <div key={p.id} className="card-box space-y-2 relative">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-teal-50 text-teal-700 flex items-center justify-center font-bold"><User className="w-5 h-5" /></div>
              <div><h3 className="font-bold text-sm">{p.nombres} {p.apellidos}</h3><p className="text-xs text-slate-400">CI: {p.cedula || 'S/N'}</p></div>
            </div>
            <div className="text-xs space-y-1 text-slate-600 border-t pt-2">
              <p>📞 {p.telefono || 'Sin teléfono'}</p>
              <p className={p.alergias ? 'text-rose-600 font-bold' : ''}>⚠️ Alergias: {p.alergias || 'Ninguna'}</p>
            </div>
            <button onClick={() => del(p.id)} className="absolute top-4 right-4 text-slate-300 hover:text-rose-600"><Trash2 className="w-4 h-4" /></button>
          </div>
        ))}
      </div>

      {modal && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-3">
            <h2 className="font-bold text-base">Registrar Paciente</h2>
            <input required placeholder="Nombres" value={form.nombres} onChange={e => setForm({...form, nombres: e.target.value})} className="input-field" />
            <input required placeholder="Apellidos" value={form.apellidos} onChange={e => setForm({...form, apellidos: e.target.value})} className="input-field" />
            <input placeholder="Cédula" value={form.cedula} onChange={e => setForm({...form, cedula: e.target.value})} className="input-field" />
            <input placeholder="Teléfono" value={form.telefono} onChange={e => setForm({...form, telefono: e.target.value})} className="input-field" />
            <textarea placeholder="Alergias o condiciones" value={form.alergias} onChange={e => setForm({...form, alergias: e.target.value})} className="input-field" rows={2} />
            <div className="flex justify-end gap-2 pt-2">
              <button type="button" onClick={() => setModal(false)} className="btn-secondary">Cancelar</button>
              <button type="submit" className="btn-primary">Guardar</button>
            </div>
          </form>
        </div>
      )}
    </div>
  )
}
