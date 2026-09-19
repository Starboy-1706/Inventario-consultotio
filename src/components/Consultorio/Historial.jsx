import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { fmt } from '../../utils/helpers'
import PriceBox from '../UI/PriceBox'
import Odontograma from './Odontograma'
import {
  Plus, FileText, CheckCircle2, Clock, Search, User, Save,
  X, Printer, Receipt, DollarSign, Package, AlertCircle
} from 'lucide-react'
import toast from 'react-hot-toast'

export default function Historial() {
  const { rates, taxes } = useCurrency()
  const [list, setList] = useState([])
  const [pacs, setPacs] = useState([])
  const [trats, setTrats] = useState([])
  const [prods, setProds] = useState([])
  const [showForm, setShowForm] = useState(false)
  const [q, setQ] = useState('')
  const [dientesSel, setDientesSel] = useState([])
  const [ticketClinico, setTicketClinico] = useState(null)

  const [form, setForm] = useState({
    paciente_id: '',
    tratamiento_id: '',
    diagnostico: '',
    procedimiento: '',
    monto_usd: 0,
    impuesto_id: '',
    pagado: true,
    metodo_pago: 'efectivo_usd'
  })

  const load = async () => {
    const [h, p, t, pr] = await Promise.all([
      supabase.from('historial_clinico').select('*, pacientes(nombres, apellidos, cedula, telefono)').order('created_at', { ascending: false }),
      supabase.from('pacientes').select('id, nombres, apellidos').eq('activo', true).order('nombres'),
      supabase.from('tratamientos').select('id, nombre, precio').eq('activo', true),
      supabase.from('productos').select('*').eq('activo', true)
    ])
    setList(h.data || [])
    setPacs(p.data || [])
    setTrats(t.data || [])
    setProds(pr.data || [])
  }

  useEffect(() => { load() }, [])

  // Al seleccionar un tratamiento del catálogo, carga automáticamente el precio y nombre
  const seleccionarTratamiento = (id) => {
    const t = trats.find(x => x.id === id)
    if (t) {
      setForm(prev => ({
        ...prev,
        tratamiento_id: id,
        procedimiento: t.nombre,
        monto_usd: Number(t.precio)
      }))
    }
  }

  const selectedTax = taxes.find(t => t.id === form.impuesto_id)
  const taxPct = selectedTax ? selectedTax.porcentaje : 0
  const subtotalUSD = Number(form.monto_usd || 0)
  const taxUSD = subtotalUSD * (taxPct / 100)
  const totalUSD = subtotalUSD + taxUSD

  const save = async (e) => {
    e.preventDefault()
    const fac = `CONS-${Date.now().toString().slice(-6)}`

    const payload = {
      ...form,
      factura: fac,
      dientes_tratados: dientesSel.join(', '),
      subtotal_usd: subtotalUSD,
      impuesto_usd: taxUSD,
      monto_usd: totalUSD,
      total_ves: totalUSD * rates.VES,
      total_cop: totalUSD * rates.COP,
      tasa_ves: rates.VES,
      tasa_cop: rates.COP
    }

    const { data: nuevaConsulta, error } = await supabase.from('historial_clinico').insert([payload]).select().single()

    if (error) return toast.error('Error al guardar consulta')

    // Descontar automáticamente insumos si el tratamiento tenía insumos vinculados
    if (form.tratamiento_id) {
      const { data: insumosVinculados } = await supabase.from('tratamiento_insumos').select('*').eq('tratamiento_id', form.tratamiento_id)
      if (insumosVinculados && insumosVinculados.length > 0) {
        for (const item of insumosVinculados) {
          const prodActual = prods.find(p => p.id === item.producto_id)
          if (prodActual) {
            const nuevoStock = Math.max(0, prodActual.stock - item.cantidad)
            await supabase.from('productos').update({ stock: nuevoStock }).eq('id', item.producto_id)
            await supabase.from('movimientos').insert({
              producto_id: item.producto_id,
              tipo: 'uso_consultorio',
              cantidad: -item.cantidad,
              stock_antes: prodActual.stock,
              stock_despues: nuevoStock,
              referencia: `Consulta: ${fac} (${form.procedimiento})`
            })
          }
        }
      }
    }

    toast.success(`Consulta ${fac} registrada y cobrada`)
    setTicketClinico({ ...payload, paciente: pacs.find(p => p.id === form.paciente_id) })
    setShowForm(false)
    setDientesSel([])
    setForm({ paciente_id: '', tratamiento_id: '', diagnostico: '', procedimiento: '', monto_usd: 0, impuesto_id: '', pagado: true, metodo_pago: 'efectivo_usd' })
    load()
  }

  const metodoLabel = m => ({
    efectivo_usd: 'Efectivo $', efectivo_ves: 'Efectivo Bs.', efectivo_cop: 'Efectivo COP',
    transferencia: 'Transferencia', pago_movil: 'Pago Móvil', zelle: 'Zelle', tarjeta: 'Tarjeta', mixto: 'Mixto'
  }[m] || m)

  const filtered = list.filter(h =>
    `${h.pacientes?.nombres} ${h.pacientes?.apellidos} ${h.procedimiento} ${h.diagnostico} ${h.factura}`.toLowerCase().includes(q.toLowerCase())
  )

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Historial Clínico & Cobros</h1>
          <p className="text-xs text-slate-400">Consultas realizadas, emisión de recibos y registro odontológico</p>
        </div>
        <button onClick={() => setShowForm(!showForm)} className={showForm ? 'btn-secondary' : 'btn-primary'}>
          {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Registrar Consulta</>}
        </button>
      </div>

      {/* Formulario de Facturación y Consulta Clínica */}
      {showForm && (
        <form onSubmit={save} className="card-box space-y-4 border-2 border-teal-200 bg-teal-50/20">
          <h3 className="font-bold text-sm text-teal-800 flex items-center gap-1.5">
            <Receipt className="w-4 h-4" /> Registrar Procedimiento y Cobro
          </h3>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Paciente *</label>
              <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
                <option value="">Seleccionar paciente...</option>
                {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
              </select>
            </div>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Cargar Tratamiento del Catálogo</label>
              <select className="input-field" value={form.tratamiento_id} onChange={e => seleccionarTratamiento(e.target.value)}>
                <option value="">Personalizado / Otro</option>
                {trats.map(t => <option key={t.id} value={t.id}>{t.nombre} — ${t.precio}</option>)}
              </select>
            </div>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Nombre del Procedimiento *</label>
              <input required className="input-field" value={form.procedimiento} onChange={e => setForm({...form, procedimiento: e.target.value})} placeholder="Ej: Resina Fotocurada #14" />
            </div>
          </div>

          {/* Odontograma interactivo */}
          <Odontograma selected={dientesSel} onChange={setDientesSel} />

          <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Honorarios / Monto Base ($ USD) *</label>
              <input required type="number" step="0.01" min="0" className="input-field font-bold text-teal-700" value={form.monto_usd} onChange={e => setForm({...form, monto_usd: e.target.value})} />
            </div>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Impuesto Aplicable</label>
              <select className="input-field" value={form.impuesto_id} onChange={e => setForm({...form, impuesto_id: e.target.value})}>
                <option value="">Exento de Impuestos</option>
                {taxes.map(t => <option key={t.id} value={t.id}>{t.nombre} ({t.porcentaje}%)</option>)}
              </select>
            </div>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Método de Pago</label>
              <select className="input-field" value={form.metodo_pago} onChange={e => setForm({...form, metodo_pago: e.target.value})}>
                {['efectivo_usd','efectivo_ves','efectivo_cop','transferencia','pago_movil','zelle','tarjeta','mixto'].map(m => <option key={m} value={m}>{metodoLabel(m)}</option>)}
              </select>
            </div>
          </div>

          <div>
            <label className="text-[11px] font-semibold text-slate-500 block mb-1">Diagnóstico & Observaciones</label>
            <textarea className="input-field" value={form.diagnostico} onChange={e => setForm({...form, diagnostico: e.target.value})} placeholder="Detalles de la intervención..." rows={2} />
          </div>

          {/* Totales en vivo */}
          <div className="p-3.5 bg-slate-900 text-white rounded-xl text-xs space-y-1">
            <div className="flex justify-between text-slate-400"><span>Subtotal:</span><span>{fmt(subtotalUSD, 'USD')}</span></div>
            {taxPct > 0 && <div className="flex justify-between text-teal-400"><span>Impuesto ({taxPct}%):</span><span>{fmt(taxUSD, 'USD')}</span></div>}
            <div className="flex justify-between text-sm font-bold border-t border-slate-700 pt-1.5"><span>Total a Cobrar USD:</span><span className="text-teal-400">{fmt(totalUSD, 'USD')}</span></div>
            <div className="flex justify-between text-slate-300"><span>Total en Bs. (BCV):</span><span>{fmt(totalUSD * rates.VES, 'VES')}</span></div>
            <div className="flex justify-between text-amber-300"><span>Total en COP:</span><span>{fmt(totalUSD * rates.COP, 'COP')}</span></div>
          </div>

          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> Guardar y Emitir Recibo</button>
            <button type="button" onClick={() => setShowForm(false)} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      {/* Barra de búsqueda */}
      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input placeholder="Buscar por paciente, procedimiento o factura..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
      </div>

      {/* Lista de Registros Clínicos */}
      <div className="space-y-3">
        {filtered.map(h => (
          <div key={h.id} className="card-box space-y-2.5">
            <div className="flex justify-between items-start flex-wrap gap-2">
              <div>
                <span className="text-[10px] font-mono font-bold text-teal-700 bg-teal-50 px-2 py-0.5 rounded">{h.factura || 'CONSULTA'}</span>
                <h3 className="font-bold text-sm text-slate-800 mt-1">{h.pacientes?.nombres} {h.pacientes?.apellidos}</h3>
                <p className="text-xs font-bold text-teal-700">{h.procedimiento}</p>
                <p className="text-[11px] text-slate-400">{new Date(h.fecha || h.created_at).toLocaleDateString('es-VE')}</p>
              </div>
              <div className="text-right">
                <PriceBox usd={h.monto_usd} showAll />
                <button
                  onClick={() => setTicketClinico({ ...h, paciente: h.pacientes })}
                  className="btn-secondary text-xs py-1 px-2 mt-2 inline-flex items-center gap-1"
                >
                  <Printer className="w-3.5 h-3.5" /> Recibo
                </button>
              </div>
            </div>

            {h.diagnostico && (
              <p className="text-xs text-slate-600 bg-slate-50 p-2.5 rounded-xl border border-slate-100">
                <span className="font-bold text-slate-400">Dx:</span> {h.diagnostico}
              </p>
            )}

            <div className="flex items-center gap-2 flex-wrap text-xs pt-1 border-t border-slate-100">
              {h.dientes_tratados && <span className="badge bg-teal-50 text-teal-800 font-bold border border-teal-100">🦷 Dientes: {h.dientes_tratados}</span>}
              <span className="badge bg-slate-100 text-slate-600">{metodoLabel(h.metodo_pago)}</span>
              <span className="badge bg-emerald-50 text-emerald-700 border border-emerald-100">✓ Cobrado</span>
            </div>
          </div>
        ))}
      </div>

      {/* Recibo Clínico Imprimible */}
      {ticketClinico && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-3xl p-6 w-full max-w-sm shadow-2xl space-y-4 text-center">
            <div className="flex justify-between items-center border-b pb-2">
              <span className="text-xs font-bold text-slate-400">RECIBO DE ATENCIÓN ODONTOLÓGICA</span>
              <button onClick={() => setTicketClinico(null)} className="p-1 hover:bg-slate-100 rounded-lg text-slate-500"><X className="w-4 h-4" /></button>
            </div>

            <div className="space-y-1">
              <div className="text-3xl">🦷</div>
              <h2 className="font-bold text-base text-slate-800">CONSULTORIO ODONTOLÓGICO</h2>
              <p className="text-[11px] text-slate-400">Atención Odontológica & Especialidades</p>
              <p className="text-xs font-mono font-bold text-teal-700 pt-1">{ticketClinico.factura || 'RECIBO MÉDICO'}</p>
              <p className="text-[10px] text-slate-400">{new Date().toLocaleString('es-VE')}</p>
            </div>

            <div className="text-left text-xs bg-slate-50 p-3 rounded-xl space-y-1">
              <p><span className="text-slate-400">Paciente:</span> <b>{ticketClinico.paciente?.nombres} {ticketClinico.paciente?.apellidos}</b></p>
              {ticketClinico.paciente?.cedula && <p><span className="text-slate-400">Cédula:</span> <b>{ticketClinico.paciente.cedula}</b></p>}
              <p><span className="text-slate-400">Procedimiento:</span> <b>{ticketClinico.procedimiento}</b></p>
              {ticketClinico.dientes_tratados && <p><span className="text-slate-400">Dientes:</span> <b>{ticketClinico.dientes_tratados}</b></p>}
            </div>

            <div className="space-y-1 text-xs border-t border-b py-2 text-left">
              <div className="flex justify-between font-bold text-sm text-slate-900 pt-1">
                <span>TOTAL USD:</span><span>{fmt(ticketClinico.monto_usd, 'USD')}</span>
              </div>
              <div className="flex justify-between font-bold text-teal-700">
                <span>TOTAL BS:</span><span>{fmt(ticketClinico.monto_usd * rates.VES, 'VES')}</span>
              </div>
              <div className="flex justify-between font-bold text-amber-700">
                <span>TOTAL COP:</span><span>{fmt(ticketClinico.monto_usd * rates.COP, 'COP')}</span>
              </div>
            </div>

            <div className="flex gap-2">
              <button onClick={() => setTicketClinico(null)} className="w-1/2 btn-secondary justify-center">Cerrar</button>
              <button onClick={() => window.print()} className="w-1/2 btn-primary justify-center"><Printer className="w-4 h-4" /> Imprimir</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
