import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { fmt } from '../../utils/helpers'
import PriceBox from '../UI/PriceBox'
import { Plus, Save, X, Clock, Trash2, Edit3, Package, ChevronDown, ChevronUp, Calculator } from 'lucide-react'
import toast from 'react-hot-toast'

const catIcons = { 'General':'🔍','Preventivo':'🛡️','Restauración':'🦷','Cirugía':'⚕️','Endodoncia':'🔬','Estético':'✨','Ortodoncia':'😁','Prótesis':'👑','Diagnóstico':'📷' }

export default function Tratamientos() {
  const [list, setList] = useState([])
  const [prods, setProds] = useState([])
  const [insumosTrat, setInsumosTrat] = useState({})
  const [showForm, setShowForm] = useState(false)
  const [editId, setEditId] = useState(null)
  const [expanded, setExpanded] = useState(null)
  const { rates } = useCurrency()

  const [form, setForm] = useState({ nombre: '', descripcion: '', precio: '', duracion_min: 30, categoria: 'General' })
  const [formInsumos, setFormInsumos] = useState([])

  const load = async () => {
    const [t, p, ti] = await Promise.all([
      supabase.from('tratamientos').select('*').eq('activo', true).order('categoria').order('nombre'),
      supabase.from('productos').select('*').eq('activo', true).order('nombre'),
      supabase.from('tratamiento_insumos').select('*, productos(nombre, precio_venta)').catch(() => ({ data: [] }))
    ])
    setList(t.data || [])
    setProds(p.data || [])

    const map = {}
    ;(ti.data || []).forEach(i => {
      if (!map[i.tratamiento_id]) map[i.tratamiento_id] = []
      map[i.tratamiento_id].push(i)
    })
    setInsumosTrat(map)
  }
  useEffect(() => { load() }, [])

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
      await supabase.from('tratamiento_insumos').delete().eq('tratamiento_id', editId)
      toast.success('Tratamiento actualizado')
    } else {
      const { data } = await supabase.from('tratamientos').insert([payload]).select().single()
      tratId = data?.id
      toast.success('Tratamiento creado')
    }

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
    const existing = insumosTrat[t.id] || []
    setFormInsumos(existing.map(i => ({ producto_id: i.producto_id, cantidad: i.cantidad })))
    setEditId(t.id); setShowForm(true); setExpanded(null)
  }

  const del = async id => { if (!confirm('¿Desactivar?')) return; await supabase.from('tratamientos').update({ activo: false }).eq('id', id); toast.success('Desactivado'); load() }

  const grouped = {}
  list.forEach(t => { const c = t.categoria || 'General'; if (!grouped[c]) grouped[c] = []; grouped[c].push(t) })

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div><h1 className="text-xl font-bold text-slate-800">Catálogo de Procedimientos</h1><p className="text-xs text-slate-400">Cálculo automático: Mano de Obra + Insumos Utilizados</p></div>
        <button onClick={() => { setShowForm(!showForm); setEditId(null); setForm({ nombre: '', descripcion: '', precio: '', duracion_min: 30, categoria: 'General' }); setFormInsumos([]) }} className={showForm ? 'btn-secondary' : 'btn-primary'}>
          {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Nuevo Tratamiento</>}
        </button>
      </div>

      {showForm && (
        <form onSubmit={save} className="card-box space-y-4 border-2 border-teal-200 bg-teal-50/20">
          <h3 className="font-bold text-sm text-teal-800 flex items-center gap-1.5"><Calculator className="w-4 h-4" /> {editId ? 'Editar Tratamiento' : 'Crear Tratamiento con Cálculo de Insumos'}</h3>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Nombre *</label>
              <input required className="input-field" value={form.nombre} onChange={e => setForm({...form, nombre: e.target.value})} placeholder="Ej: Resina Fotocurada" />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Honorarios / Mano de Obra ($) *</label>
              <input required type="number" step="0.01" min="0" className="input-field font-bold text-teal-700" value={form.precio} onChange={e => setForm({...form, precio: e.target.value})} placeholder="20.00" />
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
            <input className="input-field" value={form.descripcion} onChange={e => setForm({...form, descripcion: e.target.value})} placeholder="Indicaciones del tratamiento..." />
          </div>

          <div className="border-t border-slate-200 pt-3 space-y-2">
            <div className="flex justify-between items-center">
              <p className="text-xs font-bold text-slate-700 flex items-center gap-1.5"><Package className="w-3.5 h-3.5 text-teal-600" /> Insumos / Materiales del Almacén Utilizados</p>
              <button type="button" onClick={addInsumo} className="text-xs font-bold text-teal-600 hover:underline flex items-center gap-1"><Plus className="w-3 h-3" /> Añadir Material</button>
            </div>

            {formInsumos.map((fi, idx) => {
              const prod = prods.find(p => p.id === fi.producto_id)
              const subtotal = (prod?.precio_venta || 0) * (fi.cantidad || 0)
              return (
                <div key={idx} className="flex items-center gap-2 bg-white p-2.5 rounded-xl border border-slate-200">
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
          </div>

          <div className="bg-slate-900 text-white p-4 rounded-xl space-y-1.5 text-sm">
            <div className="flex justify-between text-xs text-slate-400"><span>Honorarios Profesionales:</span><span>{fmt(precioServicio)}</span></div>
            <div className="flex justify-between text-xs text-slate-400"><span>Costo Materiales ({formInsumos.length} items):</span><span>{fmt(costoInsumos)}</span></div>
            <div className="flex justify-between text-base font-bold border-t border-slate-700 pt-2"><span>PRECIO FINAL TOTAL USD:</span><span className="text-teal-400">{fmt(precioTotal)}</span></div>
            <div className="flex justify-between text-xs font-semibold text-slate-300"><span>Precio en Bs. (BCV):</span><span>{fmt(precioTotal * rates.VES, 'VES')}</span></div>
            <div className="flex justify-between text-xs font-semibold text-amber-300"><span>Precio en COP:</span><span>{fmt(precioTotal * rates.COP, 'COP')}</span></div>
          </div>

          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> {editId ? 'Actualizar' : 'Guardar Tratamiento'}</button>
            <button type="button" onClick={() => { setShowForm(false); setEditId(null) }} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      {Object.entries(grouped).map(([cat, items]) => (
        <div key={cat} className="space-y-2">
          <h2 className="text-sm font-bold text-slate-600 flex items-center gap-2">{catIcons[cat] || '🦷'} {cat} <span className="text-[10px] bg-slate-100 px-2 py-0.5 rounded-full font-mono">{items.length}</span></h2>

          {items.map(t => {
            const insT = insumosTrat[t.id] || []
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
                    {insT.length > 0 && <span className="badge bg-teal-50 text-teal-700 font-bold"><Package className="w-3 h-3" /> {insT.length} insumos</span>}
                    {isExp ? <ChevronUp className="w-4 h-4 text-slate-400" /> : <ChevronDown className="w-4 h-4 text-slate-400" />}
                  </div>
                </button>

                {isExp && (
                  <div className="border-t bg-slate-50 p-4 space-y-3">
                    <div className="text-xs"><PriceBox usd={t.precio} showAll /></div>

                    {insT.length > 0 && (
                      <div className="space-y-1.5">
                        <p className="text-[11px] font-bold text-slate-500 uppercase">Insumos vinculados para este procedimiento:</p>
                        {insT.map(i => (
                          <div key={i.id} className="flex justify-between text-xs bg-white p-2 rounded-lg border">
                            <span className="flex items-center gap-1.5"><Package className="w-3 h-3 text-teal-600" /> {i.productos?.nombre}</span>
                            <span className="font-bold">{i.cantidad} x ${i.productos?.precio_venta}</span>
                          </div>
                        ))}
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
