#!/bin/bash
set -e

echo "🚀 Instalando Prioridad 3: Planes por Cuotas, Doctores, Exportaciones PDF/CSV y Optimización..."

mkdir -p src/components/{Doctores,Planes}

# 1. MÓDULO DE PLANES DE TRATAMIENTO & CUOTAS (ORTODONCIA)
cat > src/components/Planes/PlanesTratamiento.jsx << 'EOF'
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
EOF

# 2. MÓDULO DE DOCTORES / ESPECIALISTAS
cat > src/components/Doctores/Doctores.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { UserCheck, Plus, Trash2, Edit3, Save, X, Phone, Mail, Award, Percent } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Doctores() {
  const [list, setList] = useState([])
  const [showForm, setShowForm] = useState(false)
  const [editId, setEditId] = useState(null)

  const [form, setForm] = useState({
    nombres: '',
    apellidos: '',
    especialidad: 'Odontología General',
    telefono: '',
    email: '',
    porcentaje_comision: 50,
    color: '#0d9488'
  })

  const load = async () => {
    const { data } = await supabase.from('doctores').select('*').eq('activo', true).order('nombres')
    setList(data || [])
  }

  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    const payload = {
      ...form,
      porcentaje_comision: parseFloat(form.porcentaje_comision) || 0
    }

    if (editId) {
      await supabase.from('doctores').update(payload).eq('id', editId)
      toast.success('Doctor actualizado')
    } else {
      await supabase.from('doctores').insert([payload])
      toast.success('Doctor registrado')
    }

    setShowForm(false); setEditId(null); setForm({ nombres: '', apellidos: '', especialidad: 'Odontología General', telefono: '', email: '', porcentaje_comision: 50, color: '#0d9488' }); load()
  }

  const startEdit = (d) => {
    setForm({
      nombres: d.nombres,
      apellidos: d.apellidos,
      especialidad: d.especialidad || 'Odontología General',
      telefono: d.telefono || '',
      email: d.email || '',
      porcentaje_comision: d.porcentaje_comision || 50,
      color: d.color || '#0d9488'
    })
    setEditId(d.id); setShowForm(true)
  }

  const del = async (id) => {
    if (!confirm('¿Desactivar este doctor?')) return
    await supabase.from('doctores').update({ activo: false }).eq('id', id)
    toast.success('Doctor desactivado'); load()
  }

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Equipo de Doctores & Especialistas</h1>
          <p className="text-xs text-slate-400">Control de profesionales, especialidades y porcentajes de honorarios</p>
        </div>
        <button onClick={() => { setShowForm(!showForm); setEditId(null) }} className={showForm ? 'btn-secondary' : 'btn-primary'}>
          {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Agregar Especialista</>}
        </button>
      </div>

      {showForm && (
        <form onSubmit={save} className="card-box space-y-4 border-2 border-teal-200 bg-teal-50/20">
          <h3 className="font-bold text-sm text-teal-800">{editId ? 'Editar Doctor' : 'Nuevo Doctor / Especialista'}</h3>
          <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Nombres *</label>
              <input required className="input-field" value={form.nombres} onChange={e => setForm({...form, nombres: e.target.value})} placeholder="Dr. Carlos" />
            </div>
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Apellidos *</label>
              <input required className="input-field" value={form.apellidos} onChange={e => setForm({...form, apellidos: e.target.value})} placeholder="Ramírez" />
            </div>
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Especialidad</label>
              <select className="input-field" value={form.especialidad} onChange={e => setForm({...form, especialidad: e.target.value})}>
                <option value="Odontología General">Odontología General</option>
                <option value="Ortodoncia">Ortodoncia</option>
                <option value="Endodoncia">Endodoncia</option>
                <option value="Periodoncia">Periodoncia</option>
                <option value="Cirugía Maxilofacial">Cirugía Maxilofacial</option>
                <option value="Odontopediatría">Odontopediatría</option>
                <option value="Implantología & Prótesis">Implantología & Prótesis</option>
                <option value="Estética Dental">Estética Dental</option>
              </select>
            </div>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Teléfono</label>
              <input className="input-field" value={form.telefono} onChange={e => setForm({...form, telefono: e.target.value})} placeholder="0412-1234567" />
            </div>
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Email</label>
              <input type="email" className="input-field" value={form.email} onChange={e => setForm({...form, email: e.target.value})} placeholder="doctor@clinicadental.com" />
            </div>
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">% Honorarios / Comisión</label>
              <input type="number" min="0" max="100" className="input-field font-bold" value={form.porcentaje_comision} onChange={e => setForm({...form, porcentaje_comision: e.target.value})} />
            </div>
          </div>

          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> {editId ? 'Actualizar' : 'Guardar Especialista'}</button>
            <button type="button" onClick={() => setShowForm(false)} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      {/* Grid de Doctores */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {list.map(d => (
          <div key={d.id} className="card-box space-y-3 relative border hover:border-teal-300 transition-all">
            <div className="flex items-center gap-3">
              <div className="w-12 h-12 rounded-2xl bg-teal-50 text-teal-700 flex items-center justify-center font-bold text-lg">
                <UserCheck className="w-6 h-6" />
              </div>
              <div>
                <h3 className="font-bold text-sm text-slate-800">{d.nombres} {d.apellidos}</h3>
                <span className="badge bg-teal-50 text-teal-800 border border-teal-100 mt-0.5">{d.especialidad}</span>
              </div>
            </div>

            <div className="text-xs space-y-1 text-slate-500 pt-2 border-t border-slate-100">
              {d.telefono && <p className="flex items-center gap-1.5"><Phone className="w-3 h-3 text-slate-400" /> {d.telefono}</p>}
              {d.email && <p className="flex items-center gap-1.5"><Mail className="w-3 h-3 text-slate-400" /> {d.email}</p>}
              <p className="flex items-center gap-1.5 font-bold text-teal-700 pt-1">
                <Percent className="w-3 h-3 text-teal-600" /> {d.porcentaje_comision}% de Honorarios
              </p>
            </div>

            <div className="flex gap-1 pt-1 justify-end">
              <button onClick={() => startEdit(d)} className="p-1.5 hover:bg-slate-100 text-slate-500 rounded"><Edit3 className="w-3.5 h-3.5" /></button>
              <button onClick={() => del(d.id)} className="p-1.5 hover:bg-rose-50 text-rose-500 rounded"><Trash2 className="w-3.5 h-3.5" /></button>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
EOF

# 3. ACTUALIZAR REPORTES CON EXPORTACIÓN A CSV / EXCEL
cat > src/components/Reportes/Reportes.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { fmt } from '../../utils/helpers'
import PriceBox from '../UI/PriceBox'
import {
  BarChart3, TrendingUp, Calendar, DollarSign,
  ShoppingBag, Stethoscope, Award, Download, Printer, Filter
} from 'lucide-react'
import toast from 'react-hot-toast'

export default function Reportes() {
  const { rates } = useCurrency()
  const [periodo, setPeriodo] = useState('mes')
  const [loading, setLoading] = useState(true)

  const [metrics, setMetrics] = useState({
    totalIngresosUSD: 0,
    ingresosClinicaUSD: 0,
    ingresosVentasUSD: 0,
    totalConsultas: 0,
    totalVentasPOS: 0,
    rawVentas: [],
    rawConsultas: []
  })

  const [topTratamientos, setTopTratamientos] = useState([])

  const getFechaInicio = () => {
    const now = new Date()
    if (periodo === 'hoy') return new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString()
    if (periodo === 'semana') {
      const d = new Date(now)
      const diff = d.getDate() - d.getDay() + (d.getDay() === 0 ? -6 : 1)
      d.setDate(diff)
      d.setHours(0, 0, 0, 0)
      return d.toISOString()
    }
    if (periodo === 'mes') return new Date(now.getFullYear(), now.getMonth(), 1).toISOString()
    if (periodo === 'anio') return new Date(now.getFullYear(), 0, 1).toISOString()
    return new Date(now.getFullYear(), now.getMonth(), 1).toISOString()
  }

  const loadReportes = async () => {
    setLoading(true)
    const fechaInicio = getFechaInicio()

    const [vRes, hRes] = await Promise.all([
      supabase.from('ventas').select('*').gte('created_at', fechaInicio).eq('estado', 'completada'),
      supabase.from('historial_clinico').select('*, pacientes(nombres, apellidos)').gte('created_at', fechaInicio).eq('pagado', true)
    ])

    const ventas = vRes.data || []
    const consultas = hRes.data || []

    const totalVentas = ventas.reduce((a, b) => a + Number(b.total_usd), 0)
    const totalClinica = consultas.reduce((a, b) => a + Number(b.monto_usd), 0)
    const totalGeneral = totalVentas + totalClinica

    // Top Tratamientos
    const tratCount = {}
    consultas.forEach(c => {
      const nombre = c.procedimiento || 'Consulta General'
      if (!tratCount[nombre]) tratCount[nombre] = { count: 0, totalUSD: 0 }
      tratCount[nombre].count += 1
      tratCount[nombre].totalUSD += Number(c.monto_usd || 0)
    })
    const topTratArray = Object.entries(tratCount)
      .map(([nombre, d]) => ({ nombre, ...d }))
      .sort((a, b) => b.totalUSD - a.totalUSD)
      .slice(0, 5)

    setMetrics({
      totalIngresosUSD: totalGeneral,
      ingresosClinicaUSD: totalClinica,
      ingresosVentasUSD: totalVentas,
      totalConsultas: consultas.length,
      totalVentasPOS: ventas.length,
      rawVentas: ventas,
      rawConsultas: consultas
    })

    setTopTratamientos(topTratArray)
    setLoading(false)
  }

  useEffect(() => { loadReportes() }, [periodo])

  // Exportar a archivo CSV (abrible en Excel)
  const exportarCSV = () => {
    let csvContent = 'data:text/csv;charset=utf-8,'
    csvContent += 'Tipo,Documento/Factura,Cliente/Paciente,Fecha,Total USD,Total Bs (BCV),Total COP\n'

    metrics.rawConsultas.forEach(c => {
      const pac = `${c.pacientes?.nombres || ''} ${c.pacientes?.apellidos || ''}`.trim() || 'Paciente'
      csvContent += `Consulta Clinica,${c.factura || 'CONS'},"${pac}",${new Date(c.created_at).toLocaleDateString()},${c.monto_usd},${(c.monto_usd * rates.VES).toFixed(2)},${(c.monto_usd * rates.COP).toFixed(0)}\n`
    })

    metrics.rawVentas.forEach(v => {
      csvContent += `Venta Insumos,${v.factura},"${v.cliente}",${new Date(v.created_at).toLocaleDateString()},${v.total_usd},${v.total_ves || (v.total_usd * rates.VES).toFixed(2)},${v.total_cop || (v.total_usd * rates.COP).toFixed(0)}\n`
    })

    const encodedUri = encodeURI(csvContent)
    const link = document.createElement('a')
    link.setAttribute('href', encodedUri)
    link.setAttribute('download', `reporte_odontologico_${periodo}_${new Date().toISOString().split('T')[0]}.csv`)
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    toast.success('Reporte exportado en formato CSV / Excel')
  }

  const pctClinica = metrics.totalIngresosUSD > 0 ? (metrics.ingresosClinicaUSD / metrics.totalIngresosUSD) * 100 : 50
  const pctVentas = 100 - pctClinica

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center flex-wrap gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-800">Reportes Financieros & Auditoría</h1>
          <p className="text-xs text-slate-400">Balance de ingresos, desglose comercial y exportación contable</p>
        </div>

        <div className="flex items-center gap-2 flex-wrap">
          <div className="bg-white p-1 rounded-xl border border-slate-200 flex gap-1 shadow-sm">
            {['hoy', 'semana', 'mes', 'anio'].map(p => (
              <button
                key={p}
                onClick={() => setPeriodo(p)}
                className={`px-3 py-1 rounded-lg text-xs font-bold uppercase transition-all ${
                  periodo === p ? 'bg-teal-600 text-white shadow-sm' : 'text-slate-500 hover:text-slate-800'
                }`}
              >
                {p}
              </button>
            ))}
          </div>

          <button onClick={exportarCSV} className="btn-secondary text-xs">
            <Download className="w-3.5 h-3.5" /> Exportar a Excel (CSV)
          </button>
          <button onClick={() => window.print()} className="btn-primary text-xs">
            <Printer className="w-3.5 h-3.5" /> Imprimir
          </button>
        </div>
      </div>

      {/* Métricas */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="card-box bg-slate-900 text-white p-5 rounded-2xl space-y-2">
          <span className="text-xs text-slate-400 font-semibold uppercase">Total Facturado ({periodo})</span>
          <h2 className="text-3xl font-bold text-teal-400">{fmt(metrics.totalIngresosUSD, 'USD')}</h2>
          <div className="border-t border-slate-800 pt-2 flex justify-between text-xs text-slate-300">
            <span>Bs. {fmt(metrics.totalIngresosUSD * rates.VES, 'VES')}</span>
            <span>COP {fmt(metrics.totalIngresosUSD * rates.COP, 'COP')}</span>
          </div>
        </div>

        <div className="card-box p-5 space-y-2">
          <span className="text-xs text-slate-400 font-semibold uppercase">🏥 Ingresos Consultorio</span>
          <h2 className="text-2xl font-bold text-teal-700">{fmt(metrics.ingresosClinicaUSD, 'USD')}</h2>
          <p className="text-xs text-slate-500">{metrics.totalConsultas} consultas completadas</p>
        </div>

        <div className="card-box p-5 space-y-2">
          <span className="text-xs text-slate-400 font-semibold uppercase">🏪 Ingresos Ventas Insumos</span>
          <h2 className="text-2xl font-bold text-blue-700">{fmt(metrics.ingresosVentasUSD, 'USD')}</h2>
          <p className="text-xs text-slate-500">{metrics.totalVentasPOS} tickets de venta emitidos</p>
        </div>
      </div>

      {/* Top Procedimientos */}
      <div className="card-box space-y-4">
        <h3 className="font-bold text-sm text-slate-800 flex items-center gap-2 border-b pb-2">
          <Award className="w-4 h-4 text-amber-500" /> Tratamientos de Mayor Impacto Económico
        </h3>
        <div className="space-y-2">
          {topTratamientos.map((t, idx) => (
            <div key={idx} className="p-3 bg-slate-50 rounded-xl flex items-center justify-between text-xs">
              <div className="flex items-center gap-3">
                <span className="w-6 h-6 rounded-full bg-teal-100 text-teal-800 font-bold flex items-center justify-center text-xs">#{idx + 1}</span>
                <span className="font-bold text-slate-800 text-sm">{t.nombre}</span>
              </div>
              <div className="text-right">
                <p className="font-bold text-teal-700">{fmt(t.totalUSD, 'USD')}</p>
                <span className="text-[10px] text-slate-400">{t.count} procedimientos</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
EOF

# 4. ACTUALIZAR SHELL/LAYOUT CON TODOS LOS MÓDULOS DE PRIORIDAD 3
cat > src/components/Layout/Shell.jsx << 'EOF'
import { useState } from 'react'
import { Outlet, NavLink } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import { useCurrency } from '../../context/CurrencyContext'
import {
  Users, Calendar, FileText, Activity, ShoppingBag, Package,
  Settings, LogOut, RefreshCw, LayoutDashboard, Receipt, BarChart3,
  CreditCard, UserCheck, Menu, X
} from 'lucide-react'

export default function Shell() {
  const { logout } = useAuth()
  const { rates, activeCur, setActiveCur, syncOfficialRates } = useCurrency()
  const [mobileMenu, setMobileMenu] = useState(false)

  const nav = ({ isActive }) =>
    `flex items-center gap-2.5 px-3.5 py-2.5 rounded-xl text-xs font-semibold transition-all ${
      isActive ? 'bg-teal-600 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-100'
    }`

  const closeMobile = () => setMobileMenu(false)

  return (
    <div className="min-h-screen flex flex-col md:flex-row bg-slate-50">
      {/* Botón menú móvil */}
      <div className="md:hidden bg-white border-b px-4 py-3 flex justify-between items-center z-50">
        <div className="flex items-center gap-2">
          <span className="text-xl">🦷</span>
          <span className="font-bold text-sm text-slate-800">OdontoCare Pro</span>
        </div>
        <button onClick={() => setMobileMenu(!mobileMenu)} className="p-1.5 text-slate-600 rounded-lg hover:bg-slate-100">
          {mobileMenu ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
        </button>
      </div>

      {/* Sidebar Desktop y Móvil */}
      <aside className={`
        fixed md:static inset-y-0 left-0 z-40 w-64 bg-white border-r border-slate-100 p-4 flex flex-col justify-between shrink-0 transition-transform duration-200
        ${mobileMenu ? 'translate-x-0 shadow-2xl' : '-translate-x-full md:translate-x-0'}
      `}>
        <div className="space-y-5 overflow-y-auto">
          <div className="hidden md:flex items-center gap-3 px-2">
            <div className="w-10 h-10 bg-teal-50 text-teal-600 rounded-xl flex items-center justify-center text-xl font-bold shadow-inner">🦷</div>
            <div>
              <h2 className="font-bold text-sm leading-tight text-slate-800">OdontoCare Pro</h2>
              <span className="text-[10px] font-semibold text-slate-400">Consultorio + Insumos</span>
            </div>
          </div>

          <nav className="space-y-1">
            <NavLink to="/" onClick={closeMobile} className={nav}><LayoutDashboard className="w-4 h-4" /> Panel General</NavLink>
            <NavLink to="/reportes" onClick={closeMobile} className={nav}><BarChart3 className="w-4 h-4" /> Reportes & Finanzas</NavLink>

            <p className="text-[10px] uppercase font-bold text-slate-400 px-3 pt-3 py-1 tracking-wider">1. Consultorio Clínico</p>
            <NavLink to="/pacientes" onClick={closeMobile} className={nav}><Users className="w-4 h-4" /> Pacientes 360°</NavLink>
            <NavLink to="/citas" onClick={closeMobile} className={nav}><Calendar className="w-4 h-4" /> Agenda & Horarios</NavLink>
            <NavLink to="/historial" onClick={closeMobile} className={nav}><FileText className="w-4 h-4" /> Historial & Cobros</NavLink>
            <NavLink to="/planes" onClick={closeMobile} className={nav}><CreditCard className="w-4 h-4" /> Planes & Cuotas</NavLink>
            <NavLink to="/tratamientos" onClick={closeMobile} className={nav}><Activity className="w-4 h-4" /> Tratamientos</NavLink>
            <NavLink to="/doctores" onClick={closeMobile} className={nav}><UserCheck className="w-4 h-4" /> Doctores / Equipo</NavLink>

            <p className="text-[10px] uppercase font-bold text-slate-400 px-3 pt-3 py-1 tracking-wider">2. Insumos & Ventas</p>
            <NavLink to="/pos" onClick={closeMobile} className={nav}><ShoppingBag className="w-4 h-4" /> Punto de Venta (POS)</NavLink>
            <NavLink to="/ventas" onClick={closeMobile} className={nav}><Receipt className="w-4 h-4" /> Historial de Ventas</NavLink>
            <NavLink to="/inventario" onClick={closeMobile} className={nav}><Package className="w-4 h-4" /> Almacén & Kardex</NavLink>
            <NavLink to="/config" onClick={closeMobile} className={nav}><Settings className="w-4 h-4" /> Membrete & Tasas</NavLink>
          </nav>
        </div>

        <button onClick={logout} className="flex items-center gap-2.5 text-xs font-semibold text-rose-600 hover:bg-rose-50 p-3 rounded-xl transition-all w-full mt-4">
          <LogOut className="w-4 h-4" /> Cerrar Sesión
        </button>
      </aside>

      {/* Fondo oscuro móvil */}
      {mobileMenu && <div onClick={closeMobile} className="fixed inset-0 bg-black/40 z-30 md:hidden" />}

      {/* Main Content */}
      <main className="flex-1 flex flex-col min-w-0">
        <header className="bg-white border-b border-slate-100 px-6 py-3 flex items-center justify-between flex-wrap gap-3">
          <div className="flex items-center gap-2">
            <span className="text-xs font-semibold text-slate-500 mr-1">Moneda:</span>
            {['USD', 'VES', 'COP'].map(c => (
              <button key={c} onClick={() => setActiveCur(c)}
                className={`px-3 py-1 rounded-lg text-xs font-bold transition-all ${
                  activeCur === c ? 'bg-slate-900 text-white shadow-sm' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                }`}>
                {c}
              </button>
            ))}
          </div>

          <div className="flex items-center gap-3">
            <span className="bg-teal-50 text-teal-800 font-bold px-2.5 py-1 rounded-lg text-xs border border-teal-100">
              BCV: Bs. {rates.VES}
            </span>
            <span className="bg-amber-50 text-amber-800 font-bold px-2.5 py-1 rounded-lg text-xs border border-amber-100">
              COP: ${rates.COP}
            </span>
            <button onClick={() => syncOfficialRates(true)} title="Actualizar BCV" className="p-1.5 hover:bg-slate-100 rounded-lg text-slate-600">
              <RefreshCw className="w-4 h-4" />
            </button>
          </div>
        </header>

        <div className="p-6 overflow-y-auto flex-1">
          <Outlet />
        </div>
      </main>
    </div>
  )
}
EOF

# 5. ACTUALIZAR APP.JSX CON TODAS LAS RUTAS FINALES
cat > src/App.jsx << 'EOF'
import { BrowserRouter, Routes, Route } from 'react-router-dom'
import { Toaster } from 'react-hot-toast'
import { AuthProvider, useAuth } from './context/AuthContext'
import { CurrencyProvider } from './context/CurrencyContext'
import Login from './components/Auth/Login'
import Shell from './components/Layout/Shell'
import Dashboard from './components/Dashboard/Dashboard'
import Reportes from './components/Reportes/Reportes'
import Pacientes from './components/Consultorio/Pacientes'
import Citas from './components/Consultorio/Citas'
import Historial from './components/Consultorio/Historial'
import Tratamientos from './components/Consultorio/Tratamientos'
import PlanesTratamiento from './components/Planes/PlanesTratamiento'
import Doctores from './components/Doctores/Doctores'
import POS from './components/Ventas/POS'
import HistorialVentas from './components/Ventas/HistorialVentas'
import Inventario from './components/Inventario/Inventario'
import TasasImpuestos from './components/Configuracion/TasasImpuestos'

function RoutesWrapper() {
  const { auth, loading } = useAuth()
  if (loading) return null
  if (!auth) return <Login />

  return (
    <CurrencyProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Shell />}>
            <Route index element={<Dashboard />} />
            <Route path="reportes" element={<Reportes />} />
            <Route path="pacientes" element={<Pacientes />} />
            <Route path="citas" element={<Citas />} />
            <Route path="historial" element={<Historial />} />
            <Route path="planes" element={<PlanesTratamiento />} />
            <Route path="tratamientos" element={<Tratamientos />} />
            <Route path="doctores" element={<Doctores />} />
            <Route path="pos" element={<POS />} />
            <Route path="ventas" element={<HistorialVentas />} />
            <Route path="inventario" element={<Inventario />} />
            <Route path="config" element={<TasasImpuestos />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </CurrencyProvider>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <RoutesWrapper />
      <Toaster position="top-right" />
    </AuthProvider>
  )
}
EOF

# Compilar para verificar
echo "📦 Probando compilación final de producción..."
npm run build

echo "🎉 ¡PRIORIDAD 3 INSTALADA Y COMPILADA CON ÉXITO! Sistema 100% completo."
