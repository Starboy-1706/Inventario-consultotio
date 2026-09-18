import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import PriceBox from '../UI/PriceBox'
import { Plus, FileText, CheckCircle2 } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Historial() {
  const [list, setList] = useState([])
  const [pacs, setPacs] = useState([])
  const [modal, setModal] = useState(false)
  const [form, setForm] = useState({ paciente_id: '', diagnostico: '', procedimiento: '', dientes_tratados: '', monto_usd: 0, pagado: true })

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
    toast.success('Consulta registrada en el expediente')
    setModal(false); load()
  }

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Historial Clínico</h1>
          <p className="text-xs text-slate-400">Tratamientos realizados y evolución</p>
        </div>
        <button onClick={() => setModal(true)} className="btn-primary"><Plus className="w-4 h-4" /> Registrar Consulta</button>
      </div>

      <div className="space-y-3">
        {list.map(h => (
          <div key={h.id} className="card-box flex justify-between items-center p-4 flex-wrap gap-4">
            <div className="flex items-start gap-3">
              <div className="w-10 h-10 rounded-xl bg-teal-50 text-teal-600 flex items-center justify-center shrink-0">
                <FileText className="w-5 h-5" />
              </div>
              <div>
                <h3 className="font-bold text-sm text-slate-800">{h.pacientes?.nombres} {h.pacientes?.apellidos}</h3>
                <p className="text-xs text-teal-700 font-bold">{h.procedimiento}</p>
                <p className="text-xs text-slate-500 mt-1">Dx: {h.diagnostico}</p>
                {h.dientes_tratados && <span className="badge bg-slate-100 text-slate-700 mt-2">Dientes: {h.dientes_tratados}</span>}
              </div>
            </div>

            <div className="text-right">
              <PriceBox usd={h.monto_usd} showAll />
              <div className="mt-2">
                <span className="badge bg-emerald-50 text-emerald-700 border border-emerald-100">
                  <CheckCircle2 className="w-3 h-3" /> Cobrado
                </span>
              </div>
            </div>
          </div>
        ))}
      </div>

      {modal && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-4 shadow-2xl">
            <h2 className="font-bold text-base text-slate-800">Registrar Procedimiento Clínico</h2>
            <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
              <option value="">Seleccione Paciente</option>
              {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
            </select>
            <input required placeholder="Procedimiento (ej. Resina Fotocurada #14)" className="input-field" value={form.procedimiento} onChange={e => setForm({...form, procedimiento: e.target.value})} />
            <input placeholder="Dientes Tratados (ej. 14, 15, 21)" className="input-field" value={form.dientes_tratados} onChange={e => setForm({...form, dientes_tratados: e.target.value})} />
            <textarea placeholder="Diagnóstico e indicaciones" className="input-field" value={form.diagnostico} onChange={e => setForm({...form, diagnostico: e.target.value})} />
            <input type="number" step="0.01" placeholder="Monto cobrado ($ USD)" className="input-field" value={form.monto_usd} onChange={e => setForm({...form, monto_usd: e.target.value})} />

            <div className="flex justify-end gap-2 pt-2">
              <button type="button" onClick={() => setModal(false)} className="btn-secondary">Cancelar</button>
              <button type="submit" className="btn-primary">Guardar Ficha</button>
            </div>
          </form>
        </div>
      )}
    </div>
  )
}
