import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { fmt } from '../../utils/helpers'
import PriceBox from '../UI/PriceBox'
import {
  CreditCard, Plus, CheckCircle2, Clock, AlertCircle,
  User, DollarSign, Save, X, Printer, Receipt, ChevronDown, ChevronUp
} from 'lucide-react'
import toast from 'react-hot-toast'

export default function PlanesTratamiento() {
  const { rates } = useCurrency()
  const [planes, setPlanes] = useState([])
  const [pacs, setPacs] = useState([])
  const [docs, setDocs] = useState([])
  const [showForm, setShowForm] = useState(false)
  const [expanded, setExpanded] = useState(null)
  const [abonosPorPlan, setAbonosPorPlan] = useState({})
  const [ticketAbono, setTicketAbono] = useState(null)

  // Formulario nuevo plan
  const [form, setForm] = useState({
    paciente_id: '',
    doctor_id: '',
    titulo: '',
    monto_total_usd: '',
    cuotas_total: 6,
    abono_inicial_usd: 0,
    metodo_pago_inicial: 'efectivo_usd',
    notas: ''
  })

  // Formulario nuevo abono
  const [abonoForm, setAbonoForm] = useState({
    plan_id: '',
    monto_usd: '',
    metodo_pago: 'efectivo_usd',
    notas: ''
  })

  const load = async () => {
    const [ptRes, pRes, dRes, caRes] = await Promise.all([
      supabase.from('planes_tratamiento').select('*, pacientes(nombres, apellidos, cedula, telefono), doctores(nombres, apellidos, especialidad)').order('created_at', { ascending: false }),
      supabase.from('pacientes').select('id, nombres, apellidos').eq('activo', true).order('nombres'),
      supabase.from('doctores').select('id, nombres, apellidos, especialidad').eq('activo', true),
      supabase.from('cuotas_abonos').select('*').order('created_at', { ascending: true })
    ])

    setPlanes(ptRes.data || [])
    setPacs(pRes.data || [])
    setDocs(dRes.data || [])

    // Agrupar abonos
    const map = {}
    ;(caRes.data || []).forEach(a => {
      if (!map[a.plan_id]) map[a.plan_id] = []
      map[a.plan_id].push(a)
    })
    setAbonosPorPlan(map)
  }

  useEffect(() => { load() }, [])

  const savePlan = async (e) => {
    e.preventDefault()
    const totalUSD = parseFloat(form.monto_total_usd) || 0
    const inicialUSD = parseFloat(form.abono_inicial_usd) || 0
    const saldo = Math.max(0, totalUSD - inicialUSD)
    const cuotasPagadas = inicialUSD > 0 ? 1 : 0

    const { data: newPlan, error } = await supabase.from('planes_tratamiento').insert([{
      paciente_id: form.paciente_id,
      doctor_id: form.doctor_id || null,
      titulo: form.titulo,
      monto_total_usd: totalUSD,
      cuotas_total: parseInt(form.cuotas_total) || 1,
      cuotas_pagadas: cuotasPagadas,
      saldo_pendiente_usd: saldo,
      estado: saldo === 0 ? 'completado' : 'activo',
      notas: form.notas
    }]).select().single()

    if (error) return toast.error('Error al crear plan')

    // Si hubo abono inicial, registrarlo
    if (inicialUSD > 0 && newPlan) {
      const rec = `REC-AB-${Date.now().toString().slice(-6)}`
      await supabase.from('cuotas_abonos').insert({
        plan_id: newPlan.id,
        paciente_id: form.paciente_id,
        numero_cuota: 1,
        monto_usd: inicialUSD,
        metodo_pago: form.metodo_pago_inicial,
        recibo: rec,
        notas: 'Abono inicial / Inicial de tratamiento'
      })
    }

    toast.success('Plan de tratamiento registrado con éxito')
    setShowForm(false)
    setForm({ paciente_id: '', doctor_id: '', titulo: '', monto_total_usd: '', cuotas_total: 6, abono_inicial_usd: 0, metodo_pago_inicial: 'efectivo_usd', notas: '' })
    load()
  }

  const registrarAbono = async (plan) => {
    const monto = parseFloat(abonoForm.monto_usd)
    if (!monto || monto <= 0) return toast.error('Ingresa un monto válido')
    if (monto > plan.saldo_pendiente_usd) return toast.error(`El monto supera el saldo deudor (${fmt(plan.saldo_pendiente_usd)})`)

    const nuevoSaldo = Math.max(0, plan.saldo_pendiente_usd - monto)
    const nuevasCuotas = plan.cuotas_pagadas + 1
    const estadoNuevo = nuevoSaldo === 0 ? 'completado' : 'activo'
    const rec = `REC-AB-${Date.now().toString().slice(-6)}`

    await supabase.from('cuotas_abonos').insert({
      plan_id: plan.id,
      paciente_id: plan.paciente_id,
      numero_cuota: nuevasCuotas,
      monto_usd: monto,
      metodo_pago: abonoForm.metodo_pago,
      recibo: rec,
      notas: abonoForm.notas || `Cuota #${nuevasCuotas}`
    })

    await supabase.from('planes_tratamiento').update({
      saldo_pendiente_usd: nuevoSaldo,
      cuotas_pagadas: nuevasCuotas,
      estado: estadoNuevo
    }).eq('id', plan.id)

    toast.success(`Abono ${rec} registrado exitosamente`)
    setTicketAbono({
      recibo: rec,
      paciente: plan.pacientes,
      planTitulo: plan.titulo,
      cuotaNum: nuevasCuotas,
      monto_usd: monto,
      saldoRestante: nuevoSaldo,
      metodo_pago: abonoForm.metodo_pago
    })
    setAbonoForm({ plan_id: '', monto_usd: '', metodo_pago: 'efectivo_usd', notas: '' })
    load()
  }

  const cuotaMensualSugerida = (p) => {
    const restantes = Math.max(1, p.cuotas_total - p.cuotas_pagadas)
    return p.saldo_pendiente_usd / restantes
  }

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Planes de Tratamiento & Cuotas</h1>
          <p className="text-xs text-slate-400">Control de tratamientos a plazos (Ortodoncia, Implantes, Prótesis)</p>
        </div>
        <button onClick={() => setShowForm(!showForm)} className={showForm ? 'btn-secondary' : 'btn-primary'}>
          {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Nuevo Plan de Tratamiento</>}
        </button>
      </div>

      {/* Formulario nuevo plan */}
      {showForm && (
        <form onSubmit={savePlan} className="card-box space-y-4 border-2 border-teal-200 bg-teal-50/20">
          <h3 className="font-bold text-sm text-teal-800 flex items-center gap-1.5">
            <CreditCard className="w-4 h-4" /> Crear Plan de Tratamiento a Plazos
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
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Doctor / Especialista</label>
              <select className="input-field" value={form.doctor_id} onChange={e => setForm({...form, doctor_id: e.target.value})}>
                <option value="">Cualquier profesional</option>
                {docs.map(d => <option key={d.id} value={d.id}>{d.nombres} {d.apellidos} ({d.especialidad})</option>)}
              </select>
            </div>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Título del Plan *</label>
              <input required className="input-field" value={form.titulo} onChange={e => setForm({...form, titulo: e.target.value})} placeholder="Ej: Ortodoncia Brackets MBT" />
            </div>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Monto Total ($ USD) *</label>
              <input required type="number" step="0.01" min="1" className="input-field font-bold text-teal-700" value={form.monto_total_usd} onChange={e => setForm({...form, monto_total_usd: e.target.value})} placeholder="600.00" />
            </div>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Nº de Cuotas Estimadas</label>
              <select className="input-field" value={form.cuotas_total} onChange={e => setForm({...form, cuotas_total: e.target.value})}>
                {[2, 3, 4, 6, 8, 10, 12, 18, 24].map(n => <option key={n} value={n}>{n} cuotas mensuales</option>)}
              </select>
            </div>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Abono Inicial / Inicial ($ USD)</label>
              <input type="number" step="0.01" min="0" className="input-field" value={form.abono_inicial_usd} onChange={e => setForm({...form, abono_inicial_usd: e.target.value})} placeholder="100.00" />
            </div>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Método de Pago Inicial</label>
              <select className="input-field" value={form.metodo_pago_inicial} onChange={e => setForm({...form, metodo_pago_inicial: e.target.value})}>
                <option value="efectivo_usd">Efectivo $ USD</option>
                <option value="efectivo_ves">Efectivo Bs.</option>
                <option value="pago_movil">Pago Móvil</option>
                <option value="zelle">Zelle</option>
                <option value="transferencia">Transferencia</option>
              </select>
            </div>
          </div>

          <div>
            <label className="text-[11px] font-semibold text-slate-500 block mb-1">Notas / Condiciones</label>
            <input className="input-field" value={form.notas} onChange={e => setForm({...form, notas: e.target.value})} placeholder="Incluye controles mensuales y cambio de arcos..." />
          </div>

          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> Crear Plan de Tratamiento</button>
            <button type="button" onClick={() => setShowForm(false)} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      {/* Lista de Planes Activos */}
      <div className="space-y-3">
        {planes.length === 0 ? (
          <div className="card-box text-center py-12 text-slate-400">
            <CreditCard className="w-10 h-10 mx-auto mb-2 opacity-30" />
            <p className="font-medium text-sm">Sin planes de tratamiento registrados</p>
            <p className="text-xs mt-1">Crea uno para tratamientos a largo plazo como Ortodoncia o Implantes</p>
          </div>
        ) : (
          planes.map(p => {
            const abonos = abonosPorPlan[p.id] || []
            const isExp = expanded === p.id
            const pct = p.monto_total_usd > 0 ? (((p.monto_total_usd - p.saldo_pendiente_usd) / p.monto_total_usd) * 100) : 100

            return (
              <div key={p.id} className="card-box p-0 overflow-hidden border">
                {/* Cabecera del plan */}
                <div className="p-4 flex items-center justify-between flex-wrap gap-3">
                  <div>
                    <div className="flex items-center gap-2">
                      <h3 className="font-bold text-sm text-slate-800">{p.titulo}</h3>
                      <span className={`badge ${p.estado === 'completado' ? 'bg-emerald-100 text-emerald-800' : 'bg-blue-100 text-blue-800'}`}>
                        {p.estado === 'completado' ? '✓ Liquidado' : '⏳ En Curso'}
                      </span>
                    </div>
                    <p className="text-xs text-slate-500 mt-0.5 font-medium">
                      Paciente: <b>{p.pacientes?.nombres} {p.pacientes?.apellidos}</b> {p.doctores ? `• Dr. ${p.doctores.nombres} ${p.doctores.apellidos}` : ''}
                    </p>
                  </div>

                  {/* Saldo y Progreso */}
                  <div className="flex items-center gap-4">
                    <div className="text-right">
                      <p className="text-[10px] text-slate-400 uppercase font-bold">Saldo Deudor</p>
                      <p className={`text-base font-bold ${p.saldo_pendiente_usd > 0 ? 'text-rose-600' : 'text-emerald-600'}`}>
                        {fmt(p.saldo_pendiente_usd, 'USD')}
                      </p>
                      <p className="text-[10px] text-slate-400 font-mono">Total: {fmt(p.monto_total_usd, 'USD')}</p>
                    </div>

                    <button
                      onClick={() => setExpanded(isExp ? null : p.id)}
                      className="btn-secondary text-xs py-1.5 px-3 flex items-center gap-1"
                    >
                      {isExp ? <ChevronUp className="w-3.5 h-3.5" /> : <ChevronDown className="w-3.5 h-3.5" />}
                      {isExp ? 'Ocultar' : 'Abonar / Detalle'}
                    </button>
                  </div>
                </div>

                {/* Barra de progreso */}
                <div className="w-full bg-slate-100 h-1.5">
                  <div style={{ width: `${pct}%` }} className="bg-teal-500 h-full transition-all" />
                </div>

                {/* Panel expandido para abonar y ver cuotas */}
                {isExp && (
                  <div className="border-t bg-slate-50/60 p-5 space-y-4">
                    {/* Formulario rápido de abono si tiene deuda */}
                    {p.saldo_pendiente_usd > 0 && (
                      <div className="p-3.5 bg-white rounded-xl border border-teal-200 space-y-2">
                        <p className="text-xs font-bold text-teal-900 flex items-center gap-1.5">
                          <DollarSign className="w-3.5 h-3.5 text-teal-600" /> Registrar Nueva Cuota / Abono (Sugerido: ~{fmt(cuotaMensualSugerida(p), 'USD')})
                        </p>
                        <div className="flex flex-wrap gap-2">
                          <input
                            type="number"
                            step="0.01"
                            max={p.saldo_pendiente_usd}
                            placeholder="Monto ($ USD)"
                            className="input-field w-32 text-xs font-bold text-teal-700"
                            value={abonoForm.plan_id === p.id ? abonoForm.monto_usd : ''}
                            onChange={e => setAbonoForm({ ...abonoForm, plan_id: p.id, monto_usd: e.target.value })}
                          />
                          <select
                            className="input-field w-36 text-xs"
                            value={abonoForm.plan_id === p.id ? abonoForm.metodo_pago : 'efectivo_usd'}
                            onChange={e => setAbonoForm({ ...abonoForm, plan_id: p.id, metodo_pago: e.target.value })}
                          >
                            <option value="efectivo_usd">Efectivo $</option>
                            <option value="efectivo_ves">Efectivo Bs.</option>
                            <option value="pago_movil">Pago Móvil</option>
                            <option value="zelle">Zelle</option>
                            <option value="transferencia">Transferencia</option>
                          </select>
                          <input
                            placeholder="Notas de la cuota (ej. Control mes 3)"
                            className="input-field flex-1 text-xs"
                            value={abonoForm.plan_id === p.id ? abonoForm.notas : ''}
                            onChange={e => setAbonoForm({ ...abonoForm, plan_id: p.id, notas: e.target.value })}
                          />
                          <button
                            type="button"
                            onClick={() => registrarAbono(p)}
                            className="btn-primary text-xs shrink-0 py-1.5"
                          >
                            <Save className="w-3.5 h-3.5" /> Cobrar Cuota
                          </button>
                        </div>
                      </div>
                    )}

                    {/* Historial de Abonos */}
                    <div className="space-y-1.5">
                      <p className="text-[11px] font-bold text-slate-500 uppercase">Historial de Cuotas y Abonos Realizados:</p>
                      {abonos.length === 0 ? (
                        <p className="text-xs text-slate-400 italic">Sin abonos registrados.</p>
                      ) : (
                        abonos.map(a => (
                          <div key={a.id} className="p-2.5 bg-white rounded-xl border border-slate-200 text-xs flex justify-between items-center">
                            <div>
                              <span className="font-bold text-slate-800 font-mono mr-2">{a.recibo}</span>
                              <span className="text-slate-500">{a.notas || `Cuota #${a.numero_cuota}`} • {new Date(a.created_at).toLocaleDateString('es-VE')}</span>
                            </div>
                            <div className="flex items-center gap-3">
                              <span className="font-bold text-teal-700">{fmt(a.monto_usd, 'USD')}</span>
                              <button
                                onClick={() => setTicketAbono({
                                  recibo: a.recibo,
                                  paciente: p.pacientes,
                                  planTitulo: p.titulo,
                                  cuotaNum: a.numero_cuota,
                                  monto_usd: a.monto_usd,
                                  saldoRestante: p.saldo_pendiente_usd,
                                  metodo_pago: a.metodo_pago
                                })}
                                className="p-1 text-slate-400 hover:text-teal-600 rounded"
                                title="Imprimir Recibo de Cuota"
                              >
                                <Printer className="w-3.5 h-3.5" />
                              </button>
                            </div>
                          </div>
                        ))
                      )}
                    </div>
                  </div>
                )}
              </div>
            )
          })
        )}
      </div>

      {/* Modal Recibo de Abono Imprimible */}
      {ticketAbono && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-3xl p-6 w-full max-w-sm shadow-2xl space-y-4 text-center">
            <div className="flex justify-between items-center border-b pb-2">
              <span className="text-xs font-bold text-slate-400">RECIBO DE CUOTA / ABONO</span>
              <button onClick={() => setTicketAbono(null)} className="p-1 hover:bg-slate-100 rounded-lg text-slate-500"><X className="w-4 h-4" /></button>
            </div>

            <div className="space-y-1">
              <div className="text-3xl">🦷</div>
              <h2 className="font-bold text-base text-slate-800">CONSULTORIO DENTAL</h2>
              <p className="text-[11px] text-slate-400">Tratamientos a Plazos & Ortodoncia</p>
              <p className="text-xs font-mono font-bold text-teal-700 pt-1">{ticketAbono.recibo}</p>
              <p className="text-[10px] text-slate-400">{new Date().toLocaleString('es-VE')}</p>
            </div>

            <div className="text-left text-xs bg-slate-50 p-3 rounded-xl space-y-1">
              <p><span className="text-slate-400">Paciente:</span> <b>{ticketAbono.paciente?.nombres} {ticketAbono.paciente?.apellidos}</b></p>
              <p><span className="text-slate-400">Tratamiento:</span> <b>{ticketAbono.planTitulo}</b></p>
              <p><span className="text-slate-400">Cuota Número:</span> <b>#{ticketAbono.cuotaNum}</b></p>
            </div>

            <div className="space-y-1 text-xs border-t border-b py-2 text-left">
              <div className="flex justify-between font-bold text-sm text-slate-900 pt-1">
                <span>MONTO ABONADO:</span><span className="text-teal-700">{fmt(ticketAbono.monto_usd, 'USD')}</span>
              </div>
              <div className="flex justify-between font-bold text-slate-600">
                <span>EN BOLÍVARES (BCV):</span><span>{fmt(ticketAbono.monto_usd * rates.VES, 'VES')}</span>
              </div>
              <div className="flex justify-between font-bold text-amber-700">
                <span>EN COP:</span><span>{fmt(ticketAbono.monto_usd * rates.COP, 'COP')}</span>
              </div>
              <div className="flex justify-between text-slate-400 pt-1 border-t text-[11px]">
                <span>Saldo Deudor Restante:</span><span className="font-bold text-rose-600">{fmt(ticketAbono.saldoRestante, 'USD')}</span>
              </div>
            </div>

            <div className="flex gap-2">
              <button onClick={() => setTicketAbono(null)} className="w-1/2 btn-secondary justify-center">Cerrar</button>
              <button onClick={() => window.print()} className="w-1/2 btn-primary justify-center"><Printer className="w-4 h-4" /> Imprimir</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
