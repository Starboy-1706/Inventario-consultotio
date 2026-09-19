import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import PriceBox from '../UI/PriceBox'
import Odontograma from './Odontograma'
import { Plus, FileText, CheckCircle2, Clock, Search, User, Save, X } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Historial() {
  const [list, setList] = useState([])
  const [pacs, setPacs] = useState([])
  const [showForm, setShowForm] = useState(false)
  const [q, setQ] = useState('')
  const [dientesSel, setDientesSel] = useState([])
  const [form, setForm] = useState({ paciente_id: '', diagnostico: '', procedimiento: '', monto_usd: 0, pagado: true, metodo_pago: 'efectivo_usd' })

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
    await supabase.from('historial_clinico').insert([{
      ...form,
      dientes_tratados: dientesSel.join(', '),
      monto_usd: parseFloat(form.monto_usd) || 0
    }])
    toast.success('Procedimiento guardado en el expediente')
    setShowForm(false); setDientesSel([]); load()
  }

  const metodoLabel = m => ({ efectivo_usd:'Efectivo $', efectivo_ves:'Efectivo Bs.', efectivo_cop:'Efectivo COP', transferencia:'Transferencia', pago_movil:'Pago Móvil', zelle:'Zelle', tarjeta:'Tarjeta', mixto:'Mixto' }[m] || m)

  const filtered = list.filter(h => `${h.pacientes?.nombres} ${h.pacientes?.apellidos} ${h.procedimiento} ${h.diagnostico}`.toLowerCase().includes(q.toLowerCase()))

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div><h1 className="text-xl font-bold text-slate-800">Historial Clínico</h1><p className="text-xs text-slate-400">Expedientes odontológicos y odontogramas</p></div>
        <button onClick={() => setShowForm(!showForm)} className={showForm ? 'btn-secondary' : 'btn-primary'}>
          {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Registrar Consulta</>}
        </button>
      </div>

      {showForm && (
        <form onSubmit={save} className="card-box space-y-4 border-2 border-teal-200 bg-teal-50/20">
          <h3 className="font-bold text-sm text-teal-800">Nueva Consulta Odontológica</h3>

          <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Paciente *</label>
              <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
                <option value="">Seleccionar paciente...</option>
                {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
              </select>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Procedimiento *</label>
              <input required className="input-field" value={form.procedimiento} onChange={e => setForm({...form, procedimiento: e.target.value})} placeholder="Ej: Resina Compuesta" />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Monto Cobrado ($)</label>
              <input type="number" step="0.01" min="0" className="input-field font-bold text-teal-700" value={form.monto_usd} onChange={e => setForm({...form, monto_usd: e.target.value})} />
            </div>
          </div>

          <Odontograma selected={dientesSel} onChange={setDientesSel} />

          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Diagnóstico e Indicaciones</label>
              <textarea className="input-field" value={form.diagnostico} onChange={e => setForm({...form, diagnostico: e.target.value})} placeholder="Observaciones clínicas..." rows={2} />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Método de Pago</label>
              <select className="input-field" value={form.metodo_pago} onChange={e => setForm({...form, metodo_pago: e.target.value})}>
                {['efectivo_usd','efectivo_ves','efectivo_cop','transferencia','pago_movil','zelle','tarjeta','mixto'].map(m => <option key={m} value={m}>{metodoLabel(m)}</option>)}
              </select>
            </div>
          </div>

          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> Guardar Consulta</button>
            <button type="button" onClick={() => setShowForm(false)} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input placeholder="Buscar por paciente o diagnóstico..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
      </div>

      <div className="space-y-3">
        {filtered.map(h => (
          <div key={h.id} className="card-box space-y-2">
            <div className="flex justify-between items-start flex-wrap gap-2">
              <div>
                <h3 className="font-bold text-sm text-slate-800">{h.pacientes?.nombres} {h.pacientes?.apellidos}</h3>
                <p className="text-xs font-bold text-teal-700">{h.procedimiento}</p>
                <p className="text-[11px] text-slate-400">{new Date(h.fecha).toLocaleDateString('es-VE', { day: 'numeric', month: 'short', year: 'numeric' })}</p>
              </div>
              <PriceBox usd={h.monto_usd} showAll />
            </div>

            {h.diagnostico && <p className="text-xs text-slate-600 bg-slate-50 p-2.5 rounded-xl border border-slate-100"><span className="font-bold text-slate-400">Dx:</span> {h.diagnostico}</p>}

            <div className="flex items-center gap-2 flex-wrap text-xs">
              {h.dientes_tratados && <span className="badge bg-teal-50 text-teal-800 font-bold border border-teal-100">🦷 Dientes: {h.dientes_tratados}</span>}
              <span className="badge bg-slate-100 text-slate-600">{metodoLabel(h.metodo_pago)}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
