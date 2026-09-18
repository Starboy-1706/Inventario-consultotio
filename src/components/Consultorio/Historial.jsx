import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { formatCurrency } from '../../utils/helpers'
import { Plus } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Historial() {
  const [list, setList] = useState([])
  const [pacs, setPacs] = useState([])
  const [modal, setModal] = useState(false)
  const [form, setForm] = useState({ paciente_id: '', diagnostico: '', procedimiento: '', monto_usd: 0 })

  const load = async () => {
    const [h, p] = await Promise.all([
      supabase.from('historial_clinico').select('*, pacientes(nombres, apellidos)').order('created_at', { ascending: false }),
      supabase.from('pacientes').select('id, nombres, apellidos').eq('activo', true)
    ])
    setList(h.data || []); setPacs(p.data || [])
  }
  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    await supabase.from('historial_clinico').insert([form])
    toast.success('Procedimiento guardado')
    setModal(false); load()
  }

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <div><h1 className="text-xl font-bold">Historial Clínico</h1><p className="text-xs text-slate-400">Consultas y procedimientos</p></div>
        <button onClick={() => setModal(true)} className="btn-primary"><Plus className="w-4 h-4" /> Registrar Consulta</button>
      </div>

      <div className="space-y-3">
        {list.map(h => (
          <div key={h.id} className="card-box flex justify-between items-center p-4">
            <div>
              <h3 className="font-bold text-sm">{h.pacientes?.nombres} {h.pacientes?.apellidos}</h3>
              <p className="text-xs text-slate-600 font-semibold">{h.procedimiento}</p>
              <p className="text-xs text-slate-400">Dx: {h.diagnostico}</p>
            </div>
            <div className="text-right">
              <span className="font-bold text-sm text-teal-700">{formatCurrency(h.monto_usd)}</span>
              <p className="text-[10px] text-slate-400">{new Date(h.fecha).toLocaleDateString()}</p>
            </div>
          </div>
        ))}
      </div>

      {modal && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-3">
            <h2 className="font-bold text-base">Registrar Consulta</h2>
            <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
              <option value="">Seleccione Paciente</option>
              {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
            </select>
            <input required placeholder="Procedimiento (ej. Limpieza, Resina)" className="input-field" value={form.procedimiento} onChange={e => setForm({...form, procedimiento: e.target.value})} />
            <textarea placeholder="Diagnóstico clínico" className="input-field" value={form.diagnostico} onChange={e => setForm({...form, diagnostico: e.target.value})} />
            <input type="number" step="0.01" placeholder="Monto cobrado ($)" className="input-field" value={form.monto_usd} onChange={e => setForm({...form, monto_usd: e.target.value})} />
            <div className="flex justify-end gap-2 pt-2"><button type="button" onClick={() => setModal(false)} className="btn-secondary">Cancelar</button><button type="submit" className="btn-primary">Guardar</button></div>
          </form>
        </div>
      )}
    </div>
  )
}
