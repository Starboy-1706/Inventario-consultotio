import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import PriceBox from '../UI/PriceBox'
import {
  Plus, FileText, CheckCircle2, Clock, Search,
  User, Activity, Sparkles
} from 'lucide-react'
import toast from 'react-hot-toast'

export default function Historial() {
  const [list, setList] = useState([])
  const [pacs, setPacs] = useState([])
  const [modal, setModal] = useState(false)
  const [q, setQ] = useState('')
  const [filtroPac, setFiltroPac] = useState('')
  const [form, setForm] = useState({
    paciente_id: '', diagnostico: '', procedimiento: '',
    dientes_tratados: '', monto_usd: 0, pagado: true, metodo_pago: 'efectivo_usd'
  })

  const load = async () => {
    const [h, p] = await Promise.all([
      supabase.from('historial_clinico').select('*, pacientes(nombres, apellidos, cedula)').order('created_at', { ascending: false }),
      supabase.from('pacientes').select('id, nombres, apellidos').eq('activo', true).order('nombres')
    ])
    setList(h.data || []); setPacs(p.data || [])
  }
  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    await supabase.from('historial_clinico').insert([{ ...form, monto_usd: parseFloat(form.monto_usd) || 0 }])
    toast.success('Procedimiento registrado en expediente')
    setModal(false); load()
  }

  const filtered = list.filter(h => {
    const matchQ = `${h.pacientes?.nombres} ${h.pacientes?.apellidos} ${h.procedimiento} ${h.diagnostico}`.toLowerCase().includes(q.toLowerCase())
    const matchPac = !filtroPac || h.paciente_id === filtroPac
    return matchQ && matchPac
  })

  const grouped = {}
  filtered.forEach(h => {
    const key = h.paciente_id
    if (!grouped[key]) grouped[key] = { paciente: h.pacientes, items: [] }
    grouped[key].items.push(h)
  })

  const metodoLabel = (m) => ({
    efectivo_usd: 'Efectivo $', efectivo_ves: 'Efectivo Bs.', efectivo_cop: 'Efectivo COP',
    transferencia: 'Transferencia', pago_movil: 'Pago Móvil', zelle: 'Zelle', tarjeta: 'Tarjeta', mixto: 'Mixto'
  }[m] || m)

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Historial Clínico</h1>
          <p className="text-xs text-slate-400">{list.length} procedimientos registrados</p>
        </div>
        <button onClick={() => setModal(true)} className="btn-primary"><Plus className="w-4 h-4" /> Registrar Procedimiento</button>
      </div>

      <div className="flex gap-3 flex-wrap">
        <div className="relative flex-1 min-w-[200px]">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input placeholder="Buscar procedimiento, diagnóstico..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
        </div>
        <select value={filtroPac} onChange={e => setFiltroPac(e.target.value)} className="input-field w-auto min-w-[180px]">
          <option value="">Todos los pacientes</option>
          {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
        </select>
      </div>

      <div className="space-y-6">
        {Object.values(grouped).length === 0 && (
          <div className="text-center py-16 text-slate-400">
            <FileText className="w-12 h-12 mx-auto mb-3 opacity-30" />
            <p className="font-medium">Sin registros clínicos</p>
          </div>
        )}

        {Object.values(grouped).map((g, gi) => (
          <div key={gi} className="card-box space-y-4">
            <div className="flex items-center gap-3 pb-3 border-b border-slate-100">
              <div className="w-10 h-10 rounded-xl bg-teal-50 text-teal-600 flex items-center justify-center font-bold text-sm">
                <User className="w-5 h-5" />
              </div>
              <div>
                <h3 className="font-bold text-sm text-slate-800">{g.paciente?.nombres} {g.paciente?.apellidos}</h3>
                <p className="text-[11px] text-slate-400">{g.items.length} procedimiento{g.items.length !== 1 ? 's' : ''}</p>
              </div>
            </div>

            <div className="relative pl-6 space-y-4">
              <div className="absolute left-[9px] top-2 bottom-2 w-0.5 bg-slate-200" />

              {g.items.map((h) => (
                <div key={h.id} className="relative">
                  <div className={`absolute -left-6 top-1 w-[18px] h-[18px] rounded-full border-2 flex items-center justify-center ${
                    h.pagado ? 'bg-emerald-500 border-emerald-300' : 'bg-amber-400 border-amber-200'
                  }`}>
                    {h.pagado ? <CheckCircle2 className="w-2.5 h-2.5 text-white" /> : <Clock className="w-2.5 h-2.5 text-white" />}
                  </div>

                  <div className="bg-slate-50 rounded-xl p-4 space-y-2">
                    <div className="flex justify-between items-start flex-wrap gap-2">
                      <div>
                        <p className="font-bold text-sm text-teal-700">{h.procedimiento}</p>
                        <p className="text-xs text-slate-500 mt-0.5">
                          {new Date(h.fecha).toLocaleDateString('es-VE', { day: 'numeric', month: 'short', year: 'numeric' })}
                        </p>
                      </div>
                      <PriceBox usd={h.monto_usd} showAll />
                    </div>

                    {h.diagnostico && (
                      <p className="text-xs text-slate-600 bg-white p-2 rounded-lg border border-slate-100">
                        <span className="font-bold text-slate-500">Dx:</span> {h.diagnostico}
                      </p>
                    )}

                    <div className="flex items-center gap-3 flex-wrap">
                      {h.dientes_tratados && (
                        <span className="badge bg-violet-50 text-violet-700 border border-violet-100">
                          🦷 Dientes: {h.dientes_tratados}
                        </span>
                      )}
                      <span className={`badge ${h.pagado ? 'bg-emerald-50 text-emerald-700 border-emerald-100' : 'bg-amber-50 text-amber-700 border-amber-100'}`}>
                        {h.pagado ? '✓ Cobrado' : '⏳ Pendiente'}
                      </span>
                      <span className="badge bg-slate-100 text-slate-500">{metodoLabel(h.metodo_pago)}</span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>

      {modal && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-4 shadow-2xl">
            <h2 className="font-bold text-base text-slate-800">Registrar Procedimiento</h2>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Paciente *</label>
              <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
                <option value="">Seleccionar paciente...</option>
                {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
              </select>
            </div>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Procedimiento Realizado *</label>
              <input required className="input-field" value={form.procedimiento} onChange={e => setForm({...form, procedimiento: e.target.value})} placeholder="Ej: Resina Fotocurada #14, Limpieza" />
            </div>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">🦷 Dientes Tratados</label>
              <input className="input-field" value={form.dientes_tratados} onChange={e => setForm({...form, dientes_tratados: e.target.value})} placeholder="Ej: 14, 15, 21, 36" />
            </div>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Diagnóstico</label>
              <textarea className="input-field" value={form.diagnostico} onChange={e => setForm({...form, diagnostico: e.target.value})} placeholder="Hallazgos clínicos, observaciones..." rows={2} />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Monto ($ USD)</label>
                <input type="number" step="0.01" min="0" className="input-field" value={form.monto_usd} onChange={e => setForm({...form, monto_usd: e.target.value})} />
              </div>
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Método de Pago</label>
                <select className="input-field" value={form.metodo_pago} onChange={e => setForm({...form, metodo_pago: e.target.value})}>
                  <option value="efectivo_usd">Efectivo $</option>
                  <option value="efectivo_ves">Efectivo Bs.</option>
                  <option value="efectivo_cop">Efectivo COP</option>
                  <option value="transferencia">Transferencia</option>
                  <option value="pago_movil">Pago Móvil</option>
                  <option value="zelle">Zelle</option>
                  <option value="tarjeta">Tarjeta</option>
                  <option value="mixto">Mixto</option>
                </select>
              </div>
            </div>

            <label className="flex items-center gap-2 cursor-pointer">
              <input type="checkbox" checked={form.pagado} onChange={e => setForm({...form, pagado: e.target.checked})} className="w-4 h-4 rounded text-teal-600" />
              <span className="text-sm font-medium text-slate-700">Marcar como cobrado</span>
            </label>

            <div className="flex justify-end gap-2 pt-2">
              <button type="button" onClick={() => setModal(false)} className="btn-secondary">Cancelar</button>
              <button type="submit" className="btn-primary">Guardar en Expediente</button>
            </div>
          </form>
        </div>
      )}
    </div>
  )
}
