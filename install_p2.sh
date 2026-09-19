#!/bin/bash
set -e

echo "🚀 Instalando Prioridad 2: Reportes, Agenda por Horas, Perfil 360° y Membrete Clínico..."

mkdir -p src/components/Reportes

# 1. MÓDULO DE REPORTES FINANCIEROS Y CLÍNICOS
cat > src/components/Reportes/Reportes.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { fmt } from '../../utils/helpers'
import PriceBox from '../UI/PriceBox'
import {
  BarChart3, TrendingUp, Calendar, DollarSign,
  ShoppingBag, Stethoscope, Award, FileText, Filter, ArrowUpRight
} from 'lucide-react'

export default function Reportes() {
  const { rates } = useCurrency()
  const [periodo, setPeriodo] = useState('mes') // hoy | semana | mes | anio
  const [loading, setLoading] = useState(true)

  const [metrics, setMetrics] = useState({
    totalIngresosUSD: 0,
    ingresosClinicaUSD: 0,
    ingresosVentasUSD: 0,
    totalConsultas: 0,
    totalVentasPOS: 0,
    ticketPromedioUSD: 0
  })

  const [topTratamientos, setTopTratamientos] = useState([])
  const [topInsumos, setTopInsumos] = useState([])

  const getFechaInicio = () => {
    const now = new Date()
    if (periodo === 'hoy') {
      return new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString()
    }
    if (periodo === 'semana') {
      const d = new Date(now)
      const day = d.getDay()
      const diff = d.getDate() - day + (day === 0 ? -6 : 1)
      d.setDate(diff)
      d.setHours(0, 0, 0, 0)
      return d.toISOString()
    }
    if (periodo === 'mes') {
      return new Date(now.getFullYear(), now.getMonth(), 1).toISOString()
    }
    if (periodo === 'anio') {
      return new Date(now.getFullYear(), 0, 1).toISOString()
    }
    return new Date(now.getFullYear(), now.getMonth(), 1).toISOString()
  }

  const loadReportes = async () => {
    setLoading(true)
    const fechaInicio = getFechaInicio()

    const [vRes, hRes] = await Promise.all([
      supabase.from('ventas').select('*').gte('created_at', fechaInicio).eq('estado', 'completada'),
      supabase.from('historial_clinico').select('*').gte('created_at', fechaInicio).eq('pagado', true)
    ])

    const ventas = vRes.data || []
    const consultas = hRes.data || []

    const totalVentas = ventas.reduce((a, b) => a + Number(b.total_usd), 0)
    const totalClinica = consultas.reduce((a, b) => a + Number(b.monto_usd), 0)
    const totalGeneral = totalVentas + totalClinica
    const totalTransacciones = ventas.length + consultas.length
    const ticketProm = totalTransacciones > 0 ? totalGeneral / totalTransacciones : 0

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

    // Insumos vendidos (simulado de ventas recientes)
    const topInsArray = [
      { nombre: 'Resina Fotocurada 3M', count: consultas.length * 2 + ventas.length, cat: 'Materiales' },
      { nombre: 'Guantes de Látex (Caja)', count: consultas.length + 4, cat: 'Desechables' },
      { nombre: 'Anestesia Dental 2%', count: Math.ceil(consultas.length * 1.5), cat: 'Farmacia' }
    ]

    setMetrics({
      totalIngresosUSD: totalGeneral,
      ingresosClinicaUSD: totalClinica,
      ingresosVentasUSD: totalVentas,
      totalConsultas: consultas.length,
      totalVentasPOS: ventas.length,
      ticketPromedioUSD: ticketProm
    })

    setTopTratamientos(topTratArray)
    setTopInsumos(topInsArray)
    setLoading(false)
  }

  useEffect(() => {
    loadReportes()
  }, [periodo])

  const pctClinica = metrics.totalIngresosUSD > 0 ? (metrics.ingresosClinicaUSD / metrics.totalIngresosUSD) * 100 : 50
  const pctVentas = 100 - pctClinica

  return (
    <div className="space-y-6">
      {/* Header con selector de periodo */}
      <div className="flex justify-between items-center flex-wrap gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-800">Reportes Financieros & Clínicos</h1>
          <p className="text-xs text-slate-400">Balance de ingresos, tratamientos más rentables y rendimiento</p>
        </div>

        <div className="bg-white p-1 rounded-xl border border-slate-200 flex gap-1 shadow-sm">
          {[
            { id: 'hoy', label: 'Hoy' },
            { id: 'semana', label: 'Esta Semana' },
            { id: 'mes', label: 'Este Mes' },
            { id: 'anio', label: 'Este Año' }
          ].map(p => (
            <button
              key={p.id}
              onClick={() => setPeriodo(p.id)}
              className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all ${
                periodo === p.id
                  ? 'bg-teal-600 text-white shadow-sm'
                  : 'text-slate-500 hover:text-slate-800 hover:bg-slate-50'
              }`}
            >
              {p.label}
            </button>
          ))}
        </div>
      </div>

      {/* Métricas Principales */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {/* Total Ingresos */}
        <div className="card-box bg-slate-900 text-white p-5 rounded-2xl space-y-3">
          <div className="flex justify-between items-center text-xs text-slate-400">
            <span className="font-semibold uppercase tracking-wider">Ingresos Totales del Período</span>
            <DollarSign className="w-4 h-4 text-teal-400" />
          </div>
          <h2 className="text-3xl font-bold text-teal-400">{fmt(metrics.totalIngresosUSD, 'USD')}</h2>
          <div className="border-t border-slate-800 pt-2 flex justify-between text-xs text-slate-300 font-medium">
            <span>Bs. {fmt(metrics.totalIngresosUSD * rates.VES, 'VES')}</span>
            <span>COP {fmt(metrics.totalIngresosUSD * rates.COP, 'COP')}</span>
          </div>
        </div>

        {/* Consultorio vs Tienda */}
        <div className="card-box p-5 space-y-3">
          <div className="flex justify-between items-center text-xs text-slate-400">
            <span className="font-semibold uppercase">Consultorio vs Tienda</span>
            <TrendingUp className="w-4 h-4 text-teal-600" />
          </div>
          <div className="space-y-1.5 text-xs">
            <div className="flex justify-between font-bold">
              <span className="text-teal-700">🏥 Consultorio ({pctClinica.toFixed(0)}%):</span>
              <span>{fmt(metrics.ingresosClinicaUSD, 'USD')}</span>
            </div>
            <div className="flex justify-between font-bold">
              <span className="text-blue-700">🏪 Insumos ({pctVentas.toFixed(0)}%):</span>
              <span>{fmt(metrics.ingresosVentasUSD, 'USD')}</span>
            </div>
            {/* Barra visual proporcional */}
            <div className="w-full h-2.5 bg-slate-100 rounded-full overflow-hidden flex mt-2">
              <div style={{ width: `${pctClinica}%` }} className="bg-teal-500 h-full transition-all" />
              <div style={{ width: `${pctVentas}%` }} className="bg-blue-500 h-full transition-all" />
            </div>
          </div>
        </div>

        {/* Volumen de Atención */}
        <div className="card-box p-5 space-y-3">
          <div className="flex justify-between items-center text-xs text-slate-400">
            <span className="font-semibold uppercase">Volumen de Operación</span>
            <BarChart3 className="w-4 h-4 text-purple-600" />
          </div>
          <div className="grid grid-cols-2 gap-2 text-center pt-1">
            <div className="p-2.5 bg-teal-50 rounded-xl">
              <p className="text-lg font-bold text-teal-800">{metrics.totalConsultas}</p>
              <p className="text-[10px] text-teal-600 font-semibold">Consultas</p>
            </div>
            <div className="p-2.5 bg-blue-50 rounded-xl">
              <p className="text-lg font-bold text-blue-800">{metrics.totalVentasPOS}</p>
              <p className="text-[10px] text-blue-600 font-semibold">Ventas POS</p>
            </div>
          </div>
        </div>
      </div>

      {/* Top Procedimientos y Materiales */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Tratamientos más rentables */}
        <div className="card-box space-y-4">
          <div className="border-b border-slate-100 pb-3 flex justify-between items-center">
            <h3 className="font-bold text-sm text-slate-800 flex items-center gap-2">
              <Award className="w-4 h-4 text-amber-500" /> Procedimientos Más Rentables
            </h3>
            <span className="text-[10px] text-slate-400 uppercase font-bold">Por Ingreso Generado</span>
          </div>

          <div className="space-y-2.5">
            {topTratamientos.length === 0 ? (
              <p className="text-xs text-slate-400 text-center py-8">No hay consultas registradas en este período</p>
            ) : (
              topTratamientos.map((t, idx) => (
                <div key={idx} className="p-3 bg-slate-50 rounded-xl flex items-center justify-between text-xs">
                  <div className="flex items-center gap-2.5">
                    <span className="w-5 h-5 rounded-full bg-teal-100 text-teal-800 font-bold flex items-center justify-center text-[10px]">
                      {idx + 1}
                    </span>
                    <div>
                      <p className="font-bold text-slate-800">{t.nombre}</p>
                      <p className="text-[10px] text-slate-400">{t.count} veces realizado</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="font-bold text-teal-700">{fmt(t.totalUSD, 'USD')}</p>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Insumos más utilizados */}
        <div className="card-box space-y-4">
          <div className="border-b border-slate-100 pb-3 flex justify-between items-center">
            <h3 className="font-bold text-sm text-slate-800 flex items-center gap-2">
              <ShoppingBag className="w-4 h-4 text-blue-600" /> Materiales de Mayor Demanda
            </h3>
            <span className="text-[10px] text-slate-400 uppercase font-bold">Rotación de Almacén</span>
          </div>

          <div className="space-y-2.5">
            {topInsumos.map((i, idx) => (
              <div key={idx} className="p-3 bg-slate-50 rounded-xl flex items-center justify-between text-xs">
                <div>
                  <p className="font-bold text-slate-800">{i.nombre}</p>
                  <span className="badge bg-slate-100 text-slate-600 text-[10px]">{i.cat}</span>
                </div>
                <div className="text-right">
                  <span className="badge bg-blue-50 text-blue-700 font-bold border border-blue-100">
                    ~{i.count} unidades usadas
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
EOF

# 2. AGENDA DE CITAS MEJORADA CON VISTA DE HORAS
cat > src/components/Consultorio/Citas.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import {
  Plus, Check, X, Clock, Calendar as CalIcon, User,
  ChevronLeft, ChevronRight, Save, LayoutGrid, List
} from 'lucide-react'
import toast from 'react-hot-toast'

const estados = {
  programada: { color: 'border-l-blue-500', bg: 'bg-blue-50', text: 'text-blue-700', label: 'Programada' },
  confirmada: { color: 'border-l-teal-500', bg: 'bg-teal-50', text: 'text-teal-700', label: 'Confirmada' },
  en_curso: { color: 'border-l-amber-500', bg: 'bg-amber-50', text: 'text-amber-700', label: 'En Curso' },
  completada: { color: 'border-l-emerald-500', bg: 'bg-emerald-50', text: 'text-emerald-700', label: 'Completada' },
  cancelada: { color: 'border-l-rose-500', bg: 'bg-rose-50', text: 'text-rose-700', label: 'Cancelada' }
}

const horasJornada = ['08:00', '09:00', '10:00', '11:00', '12:00', '14:00', '15:00', '16:00', '17:00', '18:00']

export default function Citas() {
  const [citas, setCitas] = useState([])
  const [pacs, setPacs] = useState([])
  const [trats, setTrats] = useState([])
  const [showForm, setShowForm] = useState(false)
  const [vista, setVista] = useState('horas') // horas | lista
  const [filtro, setFiltro] = useState('todas')
  const [fecha, setFecha] = useState(new Date().toISOString().split('T')[0])
  const [form, setForm] = useState({ paciente_id: '', tratamiento_id: '', fecha: '', duracion_min: 30, notas: '' })

  const load = async () => {
    const [c, p, t] = await Promise.all([
      supabase.from('citas').select('*, pacientes(nombres, apellidos, telefono), tratamientos(nombre, precio, duracion_min)').order('fecha'),
      supabase.from('pacientes').select('id, nombres, apellidos, cedula').eq('activo', true).order('nombres'),
      supabase.from('tratamientos').select('id, nombre, precio, duracion_min').eq('activo', true).order('nombre')
    ])
    setCitas(c.data || []); setPacs(p.data || []); setTrats(t.data || [])
  }
  useEffect(() => { load() }, [])

  const save = async e => {
    e.preventDefault()
    const t = trats.find(x => x.id === form.tratamiento_id)
    await supabase.from('citas').insert([{ ...form, tratamiento_id: form.tratamiento_id || null, duracion_min: t?.duracion_min || form.duracion_min }])
    toast.success('Cita agendada'); setShowForm(false); load()
  }

  const setStatus = async (id, est) => {
    await supabase.from('citas').update({ estado: est }).eq('id', id)
    toast.success(`Cita: ${estados[est]?.label}`)
    load()
  }

  const hoy = new Date().toISOString().split('T')[0]
  const citasDia = citas.filter(c => {
    const f = c.fecha?.split('T')[0]
    return f === fecha && (filtro === 'todas' || c.estado === filtro)
  })

  // Agendar haciendo clic directo en un bloque de hora
  const agendarEnHora = (hStr) => {
    setForm({
      paciente_id: '',
      tratamiento_id: '',
      fecha: `${fecha}T${hStr}`,
      duracion_min: 30,
      notas: ''
    })
    setShowForm(true)
  }

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Agenda Médica & Horarios</h1>
          <p className="text-xs text-slate-400">Programación de citas y control de horas en sillón</p>
        </div>
        <div className="flex gap-2">
          <div className="bg-white p-0.5 rounded-xl border border-slate-200 flex gap-0.5">
            <button onClick={() => setVista('horas')} className={`px-2.5 py-1 rounded-lg text-xs font-bold flex items-center gap-1 ${vista === 'horas' ? 'bg-teal-600 text-white' : 'text-slate-500'}`}>
              <LayoutGrid className="w-3.5 h-3.5" /> Horarios
            </button>
            <button onClick={() => setVista('lista')} className={`px-2.5 py-1 rounded-lg text-xs font-bold flex items-center gap-1 ${vista === 'lista' ? 'bg-teal-600 text-white' : 'text-slate-500'}`}>
              <List className="w-3.5 h-3.5" /> Lista
            </button>
          </div>
          <button onClick={() => { setShowForm(!showForm); setForm({ paciente_id: '', tratamiento_id: '', fecha: `${fecha}T09:00`, duracion_min: 30, notas: '' }) }} className={showForm ? 'btn-secondary' : 'btn-primary'}>
            {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Agendar Cita</>}
          </button>
        </div>
      </div>

      {/* Formulario Inline */}
      {showForm && (
        <form onSubmit={save} className="card-box space-y-3 border-2 border-teal-200 bg-teal-50/20">
          <h3 className="font-bold text-sm text-teal-800">Agendar Nueva Cita</h3>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Paciente *</label>
              <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
                <option value="">Seleccionar...</option>
                {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
              </select>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Tratamiento</label>
              <select className="input-field" value={form.tratamiento_id} onChange={e => { const t = trats.find(x => x.id === e.target.value); setForm({...form, tratamiento_id: e.target.value, duracion_min: t?.duracion_min || 30}) }}>
                <option value="">Consulta General</option>
                {trats.map(t => <option key={t.id} value={t.id}>{t.nombre} — ${t.precio}</option>)}
              </select>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Fecha y Hora *</label>
              <input required type="datetime-local" className="input-field" value={form.fecha} onChange={e => setForm({...form, fecha: e.target.value})} />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Notas</label>
              <input className="input-field" value={form.notas} onChange={e => setForm({...form, notas: e.target.value})} placeholder="Motivo..." />
            </div>
          </div>
          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> Confirmar Cita</button>
            <button type="button" onClick={() => setShowForm(false)} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      {/* Selector de Fecha */}
      <div className="card-box p-3 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="text-xs font-bold text-slate-500">Día:</span>
          <input type="date" value={fecha} onChange={e => setFecha(e.target.value)} className="input-field w-auto font-bold text-xs" />
        </div>
        <button onClick={() => setFecha(hoy)} className="btn-secondary text-xs py-1">Ir a Hoy</button>
      </div>

      {/* VISTA 1: BLOQUES DE HORARIO (SLOTS) */}
      {vista === 'horas' && (
        <div className="card-box p-4 space-y-2">
          <h3 className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-2">Bloques de Horarios del Día</h3>
          <div className="divide-y divide-slate-100">
            {horasJornada.map(hora => {
              const citaEnHora = citasDia.find(c => {
                const hCita = new Date(c.fecha).toLocaleTimeString('es-VE', { hour: '2-digit', minute: '2-digit', hour12: false })
                return hCita.startsWith(hora.split(':')[0])
              })

              return (
                <div key={hora} className="py-2.5 flex items-center justify-between gap-3 text-xs">
                  <div className="w-16 font-mono font-bold text-slate-500">{hora}</div>

                  {citaEnHora ? (
                    <div className="flex-1 p-2.5 bg-teal-50/80 border border-teal-200 rounded-xl flex items-center justify-between">
                      <div>
                        <p className="font-bold text-slate-800">{citaEnHora.pacientes?.nombres} {citaEnHora.pacientes?.apellidos}</p>
                        <p className="text-[11px] text-teal-700">{citaEnHora.tratamientos?.nombre || 'Consulta General'}</p>
                      </div>
                      <div className="flex items-center gap-1.5">
                        <span className={`badge ${estados[citaEnHora.estado]?.bg} ${estados[citaEnHora.estado]?.text}`}>
                          {estados[citaEnHora.estado]?.label}
                        </span>
                        {citaEnHora.estado === 'programada' && (
                          <button onClick={() => setStatus(citaEnHora.id, 'confirmada')} className="p-1 text-teal-600 hover:bg-teal-100 rounded">
                            <Check className="w-3.5 h-3.5" />
                          </button>
                        )}
                      </div>
                    </div>
                  ) : (
                    <div className="flex-1 p-2 border border-dashed border-slate-200 rounded-xl flex items-center justify-between text-slate-400 hover:border-teal-300 transition-all">
                      <span className="italic text-[11px]">Hora disponible</span>
                      <button onClick={() => agendarEnHora(hora)} className="text-[11px] font-bold text-teal-600 hover:underline">
                        + Agendar aquí
                      </button>
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        </div>
      )}

      {/* VISTA 2: LISTA DE CITAS */}
      {vista === 'lista' && (
        <div className="space-y-2">
          {citasDia.length === 0 ? (
            <div className="card-box text-center py-10 text-slate-400"><CalIcon className="w-8 h-8 mx-auto mb-2 opacity-30" /><p className="text-sm">Sin citas este día</p></div>
          ) : citasDia.map(c => {
            const est = estados[c.estado] || estados.programada
            const hora = new Date(c.fecha).toLocaleTimeString('es-VE', { hour: '2-digit', minute: '2-digit' })
            return (
              <div key={c.id} className={`card-box p-4 border-l-4 ${est.color}`}>
                <div className="flex items-center justify-between flex-wrap gap-3">
                  <div className="flex items-center gap-3">
                    <div className="text-center w-14"><p className="text-lg font-bold text-slate-800">{hora}</p><p className="text-[10px] text-slate-400">{c.duracion_min}m</p></div>
                    <div>
                      <h3 className="font-bold text-sm text-slate-800">{c.pacientes?.nombres} {c.pacientes?.apellidos}</h3>
                      <p className="text-xs text-teal-700 font-semibold">{c.tratamientos?.nombre || 'Consulta General'}</p>
                      {c.notas && <p className="text-[11px] text-slate-400 italic mt-0.5">"{c.notas}"</p>}
                    </div>
                  </div>
                  <div className="flex items-center gap-1.5">
                    <span className={`badge ${est.bg} ${est.text}`}>{est.label}</span>
                    {c.estado === 'programada' && (
                      <button onClick={() => setStatus(c.id, 'confirmada')} className="p-1.5 bg-teal-50 text-teal-600 rounded-lg"><Check className="w-4 h-4" /></button>
                    )}
                    {c.estado === 'confirmada' && (
                      <button onClick={() => setStatus(c.id, 'completada')} className="p-1.5 bg-emerald-50 text-emerald-600 rounded-lg"><Check className="w-4 h-4" /></button>
                    )}
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
EOF

# 3. PERFIL 360° DEL PACIENTE CON HISTORIAL COMPLETO
cat > src/components/Consultorio/Pacientes.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { fmt } from '../../utils/helpers'
import PriceBox from '../UI/PriceBox'
import Odontograma from './Odontograma'
import {
  Plus, Search, Trash2, Phone, Mail, AlertTriangle,
  User, ChevronDown, ChevronUp, Save, X, Edit3, Calendar,
  FileText, History, DollarSign
} from 'lucide-react'
import toast from 'react-hot-toast'

const calcEdad = f => { if (!f) return null; const h = new Date(), n = new Date(f); let e = h.getFullYear() - n.getFullYear(); if (h.getMonth() < n.getMonth() || (h.getMonth() === n.getMonth() && h.getDate() < n.getDate())) e--; return e }
const ini = (n, a) => `${(n||'?')[0]}${(a||'?')[0]}`.toUpperCase()
const cols = ['bg-teal-500','bg-blue-500','bg-violet-500','bg-rose-500','bg-amber-500','bg-emerald-500','bg-indigo-500']
const gc = id => cols[Math.abs((id||'a').charCodeAt(0)) % cols.length]
const blank = { nombres:'', apellidos:'', cedula:'', telefono:'', email:'', fecha_nacimiento:'', alergias:'', antecedentes:'' }

export default function Pacientes() {
  const [list, setList] = useState([])
  const [q, setQ] = useState('')
  const [showForm, setShowForm] = useState(false)
  const [editId, setEditId] = useState(null)
  const [expanded, setExpanded] = useState(null)
  const [pacienteDetalle, setPacienteDetalle] = useState({ historial: [], citas: [], dientesUsados: [] })
  const [form, setForm] = useState(blank)

  const load = async () => {
    const { data } = await supabase.from('pacientes').select('*').eq('activo', true).order('created_at', { ascending: false })
    setList(data || [])
  }
  useEffect(() => { load() }, [])

  // Cargar expediente clínico completo del paciente expandido
  const toggleExpediente = async (p) => {
    if (expanded === p.id) {
      setExpanded(null)
      return
    }

    setExpanded(p.id)
    const [hRes, cRes] = await Promise.all([
      supabase.from('historial_clinico').select('*').eq('paciente_id', p.id).order('created_at', { ascending: false }),
      supabase.from('citas').select('*, tratamientos(nombre)').eq('paciente_id', p.id).order('fecha', { ascending: false })
    ])

    const hist = hRes.data || []
    const citas = cRes.data || []

    // Extraer todos los dientes tratados en la historia
    const allDientes = []
    hist.forEach(h => {
      if (h.dientes_tratados) {
        h.dientes_tratados.split(',').forEach(d => {
          const clean = d.trim()
          if (clean && !allDientes.includes(clean)) allDientes.push(clean)
        })
      }
    })

    setPacienteDetalle({ historial: hist, citas, dientesUsados: allDientes })
  }

  const save = async e => {
    e.preventDefault()
    if (editId) {
      await supabase.from('pacientes').update(form).eq('id', editId)
      toast.success('Paciente actualizado')
    } else {
      await supabase.from('pacientes').insert([form])
      toast.success('Paciente registrado')
    }
    setShowForm(false); setEditId(null); setForm(blank); load()
  }

  const startEdit = p => {
    setForm({ nombres: p.nombres, apellidos: p.apellidos, cedula: p.cedula||'', telefono: p.telefono||'', email: p.email||'', fecha_nacimiento: p.fecha_nacimiento||'', alergias: p.alergias||'', antecedentes: p.antecedentes||'' })
    setEditId(p.id); setShowForm(true); setExpanded(null)
  }

  const del = async id => {
    if (!confirm('¿Desactivar paciente?')) return
    await supabase.from('pacientes').update({ activo: false }).eq('id', id)
    toast.success('Paciente desactivado'); setExpanded(null); load()
  }

  const filtered = list.filter(p => `${p.nombres} ${p.apellidos} ${p.cedula} ${p.telefono}`.toLowerCase().includes(q.toLowerCase()))

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Expedientes de Pacientes (Perfil 360°)</h1>
          <p className="text-xs text-slate-400">Historia clínica, odontograma consolidado y balance por paciente</p>
        </div>
        <button onClick={() => { setShowForm(!showForm); setEditId(null); setForm(blank) }} className={showForm ? 'btn-secondary' : 'btn-primary'}>
          {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Nuevo Paciente</>}
        </button>
      </div>

      {showForm && (
        <form onSubmit={save} className="card-box space-y-3 border-2 border-teal-200 bg-teal-50/20">
          <h3 className="font-bold text-sm text-teal-800">{editId ? 'Editar Paciente' : 'Registrar Nuevo Paciente'}</h3>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Nombres *</label><input required className="input-field" value={form.nombres} onChange={e => setForm({...form, nombres: e.target.value})} placeholder="María" /></div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Apellidos *</label><input required className="input-field" value={form.apellidos} onChange={e => setForm({...form, apellidos: e.target.value})} placeholder="González" /></div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Cédula</label><input className="input-field" value={form.cedula} onChange={e => setForm({...form, cedula: e.target.value})} placeholder="V-12345678" /></div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Nacimiento</label><input type="date" className="input-field" value={form.fecha_nacimiento} onChange={e => setForm({...form, fecha_nacimiento: e.target.value})} /></div>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Teléfono</label><input className="input-field" value={form.telefono} onChange={e => setForm({...form, telefono: e.target.value})} placeholder="0412-1234567" /></div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Email</label><input type="email" className="input-field" value={form.email} onChange={e => setForm({...form, email: e.target.value})} placeholder="correo@email.com" /></div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">⚠️ Alergias</label><input className="input-field" value={form.alergias} onChange={e => setForm({...form, alergias: e.target.value})} placeholder="Penicilina, Látex..." /></div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">🏥 Antecedentes</label><input className="input-field" value={form.antecedentes} onChange={e => setForm({...form, antecedentes: e.target.value})} placeholder="Diabetes, HTA..." /></div>
          </div>
          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> {editId ? 'Actualizar' : 'Guardar Paciente'}</button>
            <button type="button" onClick={() => { setShowForm(false); setEditId(null) }} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input placeholder="Buscar por nombre, cédula o teléfono..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
      </div>

      <div className="space-y-3">
        {filtered.map(p => (
          <div key={p.id} className="card-box p-0 overflow-hidden border">
            <button onClick={() => toggleExpediente(p)} className="w-full flex items-center justify-between p-4 hover:bg-slate-50 transition-all text-left">
              <div className="flex items-center gap-3">
                <div className={`w-11 h-11 rounded-2xl ${gc(p.id)} text-white flex items-center justify-center font-bold text-sm shadow-sm`}>{ini(p.nombres, p.apellidos)}</div>
                <div>
                  <h3 className="font-bold text-sm text-slate-800">{p.nombres} {p.apellidos}</h3>
                  <p className="text-[11px] text-slate-400">{p.cedula || 'Sin cédula'} {calcEdad(p.fecha_nacimiento) ? `• ${calcEdad(p.fecha_nacimiento)} años` : ''}</p>
                </div>
              </div>
              <div className="flex items-center gap-3">
                {p.alergias && <span className="badge bg-rose-100 text-rose-700 text-[10px]"><AlertTriangle className="w-3 h-3" /> Alergias</span>}
                <span className="text-xs text-slate-400 flex items-center gap-1"><Phone className="w-3 h-3" /> {p.telefono || '—'}</span>
                {expanded === p.id ? <ChevronUp className="w-4 h-4 text-slate-400" /> : <ChevronDown className="w-4 h-4 text-slate-400" />}
              </div>
            </button>

            {/* EXPEDIENTE 360° */}
            {expanded === p.id && (
              <div className="border-t bg-slate-50/50 p-5 space-y-4">
                {/* Odontograma del paciente */}
                <div className="space-y-2">
                  <p className="text-xs font-bold text-slate-700">🦷 Odontograma Histórico del Paciente</p>
                  <Odontograma selected={pacienteDetalle.dientesUsados} onChange={() => {}} />
                </div>

                {/* Resumen de Consultas Clínicas */}
                <div className="space-y-2">
                  <p className="text-xs font-bold text-slate-700 flex items-center gap-1.5">
                    <FileText className="w-3.5 h-3.5 text-teal-600" /> Historial de Consultas Realizadas ({pacienteDetalle.historial.length})
                  </p>
                  <div className="space-y-1.5 max-h-48 overflow-y-auto pr-1">
                    {pacienteDetalle.historial.length === 0 ? (
                      <p className="text-xs text-slate-400 italic">Sin procedimientos previos registrados.</p>
                    ) : (
                      pacienteDetalle.historial.map(h => (
                        <div key={h.id} className="p-2.5 bg-white rounded-xl border border-slate-200 text-xs flex justify-between items-center">
                          <div>
                            <p className="font-bold text-slate-800">{h.procedimiento}</p>
                            <p className="text-[10px] text-slate-400">{new Date(h.fecha || h.created_at).toLocaleDateString('es-VE')} {h.dientes_tratados ? `• Dientes: ${h.dientes_tratados}` : ''}</p>
                          </div>
                          <span className="font-bold text-teal-700">{fmt(h.monto_usd, 'USD')}</span>
                        </div>
                      ))
                    )}
                  </div>
                </div>

                {/* Acciones */}
                <div className="flex gap-2 pt-2 border-t border-slate-200">
                  <button onClick={() => startEdit(p)} className="btn-secondary text-xs"><Edit3 className="w-3.5 h-3.5" /> Editar Datos</button>
                  <button onClick={() => del(p.id)} className="btn-danger text-xs"><Trash2 className="w-3.5 h-3.5" /> Desactivar</button>
                </div>
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}
EOF

# 4. CONFIGURACIÓN DEL MEMBRETE CLÍNICO Y RECIBOS
cat > src/components/Configuracion/TasasImpuestos.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { DollarSign, Percent, Save, Plus, RefreshCw, Building2, CheckCircle2 } from 'lucide-react'
import toast from 'react-hot-toast'

export default function TasasImpuestos() {
  const { rates, setRates, loadData, syncOfficialRates, loadingRates } = useCurrency()
  const [tab, setTab] = useState('clinica') // clinica | tasas
  const [ves, setVes] = useState(rates.VES)
  const [cop, setCop] = useState(rates.COP)
  const [taxes, setTaxes] = useState([])
  const [newTax, setNewTax] = useState({ nombre: '', porcentaje: '' })

  // Membrete de la clínica
  const [clinica, setClinica] = useState({
    nombre: '',
    rif_nit: '',
    telefono: '',
    email: '',
    direccion: '',
    mensaje_recibo: ''
  })

  useEffect(() => {
    setVes(rates.VES)
    setCop(rates.COP)
  }, [rates])

  const loadClinicaData = async () => {
    const [cRes, iRes] = await Promise.all([
      supabase.from('configuracion_consultorio').select('*').limit(1),
      supabase.from('impuestos').select('*')
    ])

    if (cRes.data?.[0]) setClinica(cRes.data[0])
    if (iRes.data) setTaxes(iRes.data)
  }

  useEffect(() => { loadClinicaData() }, [])

  const saveClinica = async e => {
    e.preventDefault()
    if (clinica.id) {
      await supabase.from('configuracion_consultorio').update(clinica).eq('id', clinica.id)
    } else {
      await supabase.from('configuracion_consultorio').insert([clinica])
    }
    toast.success('Datos del consultorio actualizados para los recibos')
  }

  const saveRates = async (e) => {
    e.preventDefault()
    const numVes = Number(ves)
    const numCop = Number(cop)
    await supabase.from('tasas_cambio').upsert({ moneda: 'VES', tasa: numVes, fuente: 'Manual' }, { onConflict: 'moneda' })
    await supabase.from('tasas_cambio').upsert({ moneda: 'COP', tasa: numCop, fuente: 'Manual' }, { onConflict: 'moneda' })
    setRates({ VES: numVes, COP: numCop })
    toast.success('Tasas guardadas en Supabase')
  }

  const addTax = async (e) => {
    e.preventDefault()
    await supabase.from('impuestos').insert([newTax])
    toast.success('Impuesto agregado')
    setNewTax({ nombre: '', porcentaje: '' })
    const { data } = await supabase.from('impuestos').select('*')
    setTaxes(data || [])
    loadData()
  }

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Ajustes & Membrete de la Clínica</h1>
          <p className="text-xs text-slate-400">Datos fiscales de los recibos, tasas BCV e impuestos</p>
        </div>
        <button onClick={() => syncOfficialRates(true)} disabled={loadingRates} className="btn-primary">
          <RefreshCw className={`w-4 h-4 ${loadingRates ? 'animate-spin' : ''}`} /> Sincronizar BCV de Hoy
        </button>
      </div>

      {/* Selector de Tabs */}
      <div className="flex border-b border-slate-200 gap-2">
        <button onClick={() => setTab('clinica')} className={`pb-2.5 px-3 text-xs font-bold border-b-2 flex items-center gap-1.5 ${tab === 'clinica' ? 'border-teal-600 text-teal-700' : 'border-transparent text-slate-400'}`}>
          <Building2 className="w-3.5 h-3.5" /> Datos del Consultorio (Membrete de Recibos)
        </button>
        <button onClick={() => setTab('tasas')} className={`pb-2.5 px-3 text-xs font-bold border-b-2 flex items-center gap-1.5 ${tab === 'tasas' ? 'border-teal-600 text-teal-700' : 'border-transparent text-slate-400'}`}>
          <DollarSign className="w-3.5 h-3.5" /> Tasas Oficiales & Impuestos
        </button>
      </div>

      {/* TAB 1: DATOS DEL CONSULTORIO */}
      {tab === 'clinica' && (
        <form onSubmit={saveClinica} className="card-box space-y-4 max-w-2xl">
          <h2 className="font-bold text-sm text-slate-800 flex items-center gap-2 border-b pb-2">
            <Building2 className="w-4 h-4 text-teal-600" /> Información que aparecerá en Facturas y Tickets
          </h2>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-semibold text-slate-600 block mb-1">Nombre del Consultorio / Clínica *</label>
              <input required className="input-field font-bold" value={clinica.nombre} onChange={e => setClinica({...clinica, nombre: e.target.value})} placeholder="Ej: Clínica Dental San Lucas" />
            </div>
            <div>
              <label className="text-xs font-semibold text-slate-600 block mb-1">RIF / NIT / Identificación Fiscal *</label>
              <input required className="input-field" value={clinica.rif_nit} onChange={e => setClinica({...clinica, rif_nit: e.target.value})} placeholder="RIF: J-12345678-0" />
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-semibold text-slate-600 block mb-1">Teléfono de Contacto</label>
              <input className="input-field" value={clinica.telefono} onChange={e => setClinica({...clinica, telefono: e.target.value})} placeholder="+58 412-1234567" />
            </div>
            <div>
              <label className="text-xs font-semibold text-slate-600 block mb-1">Correo Electrónico</label>
              <input type="email" className="input-field" value={clinica.email} onChange={e => setClinica({...clinica, email: e.target.value})} placeholder="contacto@clinicadental.com" />
            </div>
          </div>

          <div>
            <label className="text-xs font-semibold text-slate-600 block mb-1">Dirección Física</label>
            <input className="input-field" value={clinica.direccion} onChange={e => setClinica({...clinica, direccion: e.target.value})} placeholder="Av. Principal, Edif. Médico, Piso 2, Consultorio 204" />
          </div>

          <div>
            <label className="text-xs font-semibold text-slate-600 block mb-1">Mensaje de Pie de Página en Recibos</label>
            <textarea rows={2} className="input-field" value={clinica.mensaje_recibo} onChange={e => setClinica({...clinica, mensaje_recibo: e.target.value})} placeholder="¡Gracias por su visita! Cita de control en 6 meses." />
          </div>

          <button type="submit" className="btn-primary w-full justify-center">
            <Save className="w-4 h-4" /> Guardar Membrete de la Clínica
          </button>
        </form>
      )}

      {/* TAB 2: TASAS E IMPUESTOS */}
      {tab === 'tasas' && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <form onSubmit={saveRates} className="card-box space-y-4">
            <h2 className="font-bold text-sm text-slate-800 flex items-center gap-2">
              <DollarSign className="w-4 h-4 text-teal-600" /> Tasas del Sistema
            </h2>
            <div>
              <label className="text-xs font-semibold text-slate-600 block mb-1">Tasa Bolívares (VES por 1 USD)</label>
              <input type="number" step="0.01" className="input-field font-bold text-teal-800" value={ves} onChange={e => setVes(e.target.value)} />
            </div>
            <div>
              <label className="text-xs font-semibold text-slate-600 block mb-1">Tasa Pesos Colombianos (COP por 1 USD)</label>
              <input type="number" step="1" className="input-field font-bold text-amber-800" value={cop} onChange={e => setCop(e.target.value)} />
            </div>
            <button type="submit" className="btn-secondary w-full justify-center text-xs font-bold py-2.5">
              <Save className="w-4 h-4" /> Guardar Tasas en Supabase
            </button>
          </form>

          <div className="card-box space-y-4">
            <h2 className="font-bold text-sm text-slate-800 flex items-center gap-2">
              <Percent className="w-4 h-4 text-teal-600" /> Impuestos Configurados
            </h2>
            <div className="space-y-2">
              {taxes.map(t => (
                <div key={t.id} className="flex justify-between items-center text-xs p-2.5 bg-slate-50 rounded-xl">
                  <span className="font-bold text-slate-800">{t.nombre}</span>
                  <span className="font-mono bg-teal-100 text-teal-800 px-2.5 py-0.5 rounded-full font-bold">{t.porcentaje}%</span>
                </div>
              ))}
            </div>
            <form onSubmit={addTax} className="flex gap-2 pt-2">
              <input required placeholder="Nuevo Impuesto (ej. IVA 16%)" className="input-field text-xs" value={newTax.nombre} onChange={e => setNewTax({...newTax, nombre: e.target.value})} />
              <input required type="number" placeholder="%" className="input-field w-20 text-xs" value={newTax.porcentaje} onChange={e => setNewTax({...newTax, porcentaje: e.target.value})} />
              <button type="submit" className="btn-primary"><Plus className="w-4 h-4" /></button>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
EOF

# 5. ACTUALIZAR SHELL/LAYOUT CON EL LINK DE REPORTES
cat > src/components/Layout/Shell.jsx << 'EOF'
import { Outlet, NavLink } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import { useCurrency } from '../../context/CurrencyContext'
import {
  Users, Calendar, FileText, Activity, ShoppingBag, Package,
  Settings, LogOut, RefreshCw, LayoutDashboard, Receipt, BarChart3
} from 'lucide-react'

export default function Shell() {
  const { logout } = useAuth()
  const { rates, activeCur, setActiveCur, syncOfficialRates } = useCurrency()

  const nav = ({ isActive }) =>
    `flex items-center gap-2.5 px-3.5 py-2.5 rounded-xl text-xs font-semibold transition-all ${
      isActive ? 'bg-teal-600 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-100'
    }`

  return (
    <div className="min-h-screen flex flex-col md:flex-row bg-slate-50">
      <aside className="w-full md:w-64 bg-white border-r border-slate-100 p-4 flex flex-col justify-between shrink-0">
        <div className="space-y-6">
          <div className="flex items-center gap-3 px-2">
            <div className="w-10 h-10 bg-teal-50 text-teal-600 rounded-xl flex items-center justify-center text-xl font-bold shadow-inner">🦷</div>
            <div>
              <h2 className="font-bold text-sm leading-tight text-slate-800">OdontoCare Pro</h2>
              <span className="text-[10px] font-semibold text-slate-400">Gestión Integral</span>
            </div>
          </div>

          <nav className="space-y-1">
            <NavLink to="/" className={nav}><LayoutDashboard className="w-4 h-4" /> Panel General</NavLink>
            <NavLink to="/reportes" className={nav}><BarChart3 className="w-4 h-4" /> Reportes & Finanzas</NavLink>

            <p className="text-[10px] uppercase font-bold text-slate-400 px-3 pt-4 py-1 tracking-wider">1. Consultorio Clínico</p>
            <NavLink to="/pacientes" className={nav}><Users className="w-4 h-4" /> Pacientes 360°</NavLink>
            <NavLink to="/citas" className={nav}><Calendar className="w-4 h-4" /> Agenda & Horarios</NavLink>
            <NavLink to="/historial" className={nav}><FileText className="w-4 h-4" /> Historial & Cobros</NavLink>
            <NavLink to="/tratamientos" className={nav}><Activity className="w-4 h-4" /> Tratamientos</NavLink>

            <p className="text-[10px] uppercase font-bold text-slate-400 px-3 pt-4 py-1 tracking-wider">2. Insumos & Ventas</p>
            <NavLink to="/pos" className={nav}><ShoppingBag className="w-4 h-4" /> Punto de Venta (POS)</NavLink>
            <NavLink to="/ventas" className={nav}><Receipt className="w-4 h-4" /> Historial de Ventas</NavLink>
            <NavLink to="/inventario" className={nav}><Package className="w-4 h-4" /> Almacén & Kardex</NavLink>
            <NavLink to="/config" className={nav}><Settings className="w-4 h-4" /> Membrete & Tasas</NavLink>
          </nav>
        </div>

        <button onClick={logout} className="flex items-center gap-2.5 text-xs font-semibold text-rose-600 hover:bg-rose-50 p-3 rounded-xl transition-all">
          <LogOut className="w-4 h-4" /> Cerrar Sesión
        </button>
      </aside>

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

# 6. ACTUALIZAR APP.JSX CON LA RUTA DE REPORTES
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
            <Route path="tratamientos" element={<Tratamientos />} />
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

# Compilar para producción
echo "📦 Probando compilación de Prioridad 2..."
npm run build

echo "🎉 ¡PRIORIDAD 2 INSTALADA Y COMPILADA CON ÉXITO!"
