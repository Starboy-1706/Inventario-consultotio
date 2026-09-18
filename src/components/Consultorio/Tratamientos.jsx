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
