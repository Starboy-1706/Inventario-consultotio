#!/bin/bash
set -e

echo "🚀 Instalando Prioridad 1: Dashboard Ejecutivo, Cobros Clínicos, Kardex y Alertas..."

# 1. Dashboard Ejecutivo en Vivo
cat > src/components/Dashboard/Dashboard.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { fmt } from '../../utils/helpers'
import PriceBox from '../UI/PriceBox'
import {
  Users, Calendar, ShoppingBag, AlertTriangle, ArrowUpRight,
  Clock, CheckCircle2, TrendingUp, Package, Stethoscope, ChevronRight
} from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'

export default function Dashboard() {
  const navigate = useNavigate()
  const { rates } = useCurrency()
  const [stats, setStats] = useState({
    ingresosHoyUSD: 0,
    ingresosMesUSD: 0,
    citasHoy: 0,
    citasPendientes: 0,
    pacsTotal: 0,
    lowStockCount: 0,
    costoReabastecerUSD: 0
  })
  const [citasHoy, setCitasHoy] = useState([])
  const [alertasStock, setAlertasStock] = useState([])

  const loadDashboard = async () => {
    const today = new Date().toISOString().split('T')[0]
    const startOfMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString()

    const [pRes, cRes, vHoyRes, vMesRes, hHoyRes, hMesRes, prodRes] = await Promise.all([
      supabase.from('pacientes').select('id', { count: 'exact', head: true }).eq('activo', true),
      supabase.from('citas').select('*, pacientes(nombres, apellidos, telefono), tratamientos(nombre, precio)').gte('fecha', `${today}T00:00:00`).lte('fecha', `${today}T23:59:59`).order('fecha'),
      supabase.from('ventas').select('total_usd').gte('created_at', `${today}T00:00:00`).eq('estado', 'completada'),
      supabase.from('ventas').select('total_usd').gte('created_at', startOfMonth).eq('estado', 'completada'),
      supabase.from('historial_clinico').select('monto_usd').gte('created_at', `${today}T00:00:00`).eq('pagado', true),
      supabase.from('historial_clinico').select('monto_usd').gte('created_at', startOfMonth).eq('pagado', true),
      supabase.from('productos').select('*').eq('activo', true)
    ])

    // Cálculo de Ingresos (Consultorio + Ventas de Insumos)
    const ventasHoy = vHoyRes.data?.reduce((a, b) => a + Number(b.total_usd), 0) || 0
    const clinicaHoy = hHoyRes.data?.reduce((a, b) => a + Number(b.monto_usd), 0) || 0
    const ingresosHoy = ventasHoy + clinicaHoy

    const ventasMes = vMesRes.data?.reduce((a, b) => a + Number(b.total_usd), 0) || 0
    const clinicaMes = hMesRes.data?.reduce((a, b) => a + Number(b.monto_usd), 0) || 0
    const ingresosMes = ventasMes + clinicaMes

    // Insumos en alerta de stock
    const prods = prodRes.data || []
    const stockBajo = prods.filter(p => p.stock <= p.stock_minimo)
    const costoReponer = stockBajo.reduce((acc, p) => {
      const faltante = Math.max(0, p.stock_minimo - p.stock) + 5
      return acc + (faltante * (Number(p.precio_compra) || Number(p.precio_venta) * 0.6))
    }, 0)

    const citas = cRes.data || []
    const pendientes = citas.filter(c => c.estado === 'programada' || c.estado === 'en_curso').length

    setStats({
      ingresosHoyUSD: ingresosHoy,
      ingresosMesUSD: ingresosMes,
      citasHoy: citas.length,
      citasPendientes: pendientes,
      pacsTotal: pRes.count || 0,
      lowStockCount: stockBajo.length,
      costoReabastecerUSD: costoReponer
    })

    setCitasHoy(citas)
    setAlertasStock(stockBajo.slice(0, 6))
  }

  useEffect(() => {
    loadDashboard()
  }, [])

  const cambiarEstadoCita = async (id, estado) => {
    await supabase.from('citas').update({ estado }).eq('id', id)
    loadDashboard()
  }

  return (
    <div className="space-y-6">
      {/* Header Principal */}
      <div className="flex justify-between items-start flex-wrap gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-800">Panel Ejecutivo</h1>
          <p className="text-xs text-slate-400">Resumen clínico y comercial del día en tiempo real</p>
        </div>
        <div className="flex gap-2">
          <Link to="/pos" className="btn-primary">
            <ShoppingBag className="w-4 h-4" /> Venta Rápida (POS)
          </Link>
          <Link to="/citas" className="btn-secondary">
            <Calendar className="w-4 h-4" /> Agenda
          </Link>
        </div>
      </div>

      {/* Tarjetas Métricas Principales */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Ingresos Hoy */}
        <div className="card-box bg-gradient-to-br from-teal-600 to-teal-800 text-white p-5 shadow-lg shadow-teal-600/10">
          <div className="flex justify-between items-start">
            <div>
              <p className="text-xs text-teal-100 font-semibold uppercase tracking-wider">Ingresos de Hoy</p>
              <h3 className="text-2xl font-bold mt-1">{fmt(stats.ingresosHoyUSD, 'USD')}</h3>
            </div>
            <div className="p-2.5 bg-white/10 rounded-xl backdrop-blur-sm">
              <TrendingUp className="w-5 h-5 text-teal-100" />
            </div>
          </div>
          <div className="mt-3 pt-3 border-t border-white/10 flex justify-between text-[11px] text-teal-100 font-medium">
            <span>Bs. {fmt(stats.ingresosHoyUSD * rates.VES, 'VES')}</span>
            <span>COP {fmt(stats.ingresosHoyUSD * rates.COP, 'COP')}</span>
          </div>
        </div>

        {/* Citas de Hoy */}
        <div className="card-box flex items-center justify-between">
          <div>
            <p className="text-xs text-slate-400 font-semibold uppercase">Citas de Hoy</p>
            <h3 className="text-2xl font-bold text-slate-800 mt-1">{stats.citasHoy}</h3>
            <p className="text-[11px] text-teal-600 font-medium mt-0.5">{stats.citasPendientes} pendientes por atender</p>
          </div>
          <div className="w-12 h-12 bg-teal-50 text-teal-600 rounded-2xl flex items-center justify-center font-bold">
            <Calendar className="w-6 h-6" />
          </div>
        </div>

        {/* Ingresos del Mes */}
        <div className="card-box flex items-center justify-between">
          <div>
            <p className="text-xs text-slate-400 font-semibold uppercase">Ingresos del Mes</p>
            <h3 className="text-xl font-bold text-slate-800 mt-1">{fmt(stats.ingresosMesUSD, 'USD')}</h3>
            <p className="text-[11px] text-slate-400 mt-0.5">Consultorio + Insumos</p>
          </div>
          <div className="w-12 h-12 bg-emerald-50 text-emerald-600 rounded-2xl flex items-center justify-center font-bold">
            <Stethoscope className="w-6 h-6" />
          </div>
        </div>

        {/* Alertas de Insumos */}
        <div className="card-box flex items-center justify-between">
          <div>
            <p className="text-xs text-slate-400 font-semibold uppercase">Insumos en Alerta</p>
            <h3 className="text-2xl font-bold text-rose-600 mt-1">{stats.lowStockCount}</h3>
            <p className="text-[11px] text-slate-400 mt-0.5">Reposición: ~{fmt(stats.costoReabastecerUSD, 'USD')}</p>
          </div>
          <div className="w-12 h-12 bg-rose-50 text-rose-600 rounded-2xl flex items-center justify-center font-bold">
            <AlertTriangle className="w-6 h-6" />
          </div>
        </div>
      </div>

      {/* Bloque Central de Operaciones */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Agenda de Citas de Hoy con cambio de estado inmediato */}
        <div className="lg:col-span-2 card-box space-y-4">
          <div className="flex justify-between items-center border-b border-slate-100 pb-3">
            <div>
              <h3 className="font-bold text-sm text-slate-800 flex items-center gap-2">
                <Clock className="w-4 h-4 text-teal-600" /> Pacientes en Agenda para Hoy
              </h3>
              <p className="text-[11px] text-slate-400">Control de flujo: cambia el estado del paciente en tiempo real</p>
            </div>
            <Link to="/citas" className="text-xs font-semibold text-teal-600 hover:underline flex items-center gap-1">
              Ver agenda completa <ChevronRight className="w-3.5 h-3.5" />
            </Link>
          </div>

          <div className="space-y-2">
            {citasHoy.length === 0 ? (
              <div className="text-center py-12 text-slate-400">
                <Calendar className="w-10 h-10 mx-auto mb-2 opacity-20" />
                <p className="text-xs font-medium">No hay citas programadas para el día de hoy</p>
              </div>
            ) : (
              citasHoy.map(c => {
                const hora = new Date(c.fecha).toLocaleTimeString('es-VE', { hour: '2-digit', minute: '2-digit' })
                return (
                  <div key={c.id} className="p-3.5 bg-slate-50 hover:bg-slate-100/80 rounded-xl border border-slate-100 flex items-center justify-between flex-wrap gap-3 transition-all">
                    <div className="flex items-center gap-3">
                      <div className="text-center w-12">
                        <p className="font-bold text-sm text-slate-800">{hora}</p>
                        <span className="text-[10px] text-slate-400">{c.duracion_min || 30}m</span>
                      </div>
                      <div className="h-8 w-px bg-slate-200" />
                      <div>
                        <p className="font-bold text-xs text-slate-800">{c.pacientes?.nombres} {c.pacientes?.apellidos}</p>
                        <p className="text-[11px] text-teal-700 font-semibold">{c.tratamientos?.nombre || 'Consulta General'}</p>
                      </div>
                    </div>

                    <div className="flex items-center gap-2">
                      <span className={`badge ${
                        c.estado === 'completada' ? 'bg-emerald-100 text-emerald-800' :
                        c.estado === 'en_curso' ? 'bg-amber-100 text-amber-800 animate-pulse' :
                        c.estado === 'cancelada' ? 'bg-rose-100 text-rose-800' : 'bg-blue-100 text-blue-800'
                      }`}>
                        {c.estado}
                      </span>

                      {/* Botones de flujo rápido */}
                      {c.estado === 'programada' && (
                        <button onClick={() => cambiarEstadoCita(c.id, 'en_curso')} className="btn-secondary text-xs py-1 px-2.5">
                          En Sillón ➔
                        </button>
                      )}
                      {c.estado === 'en_curso' && (
                        <button onClick={() => cambiarEstadoCita(c.id, 'completada')} className="btn-primary text-xs py-1 px-2.5 bg-emerald-600 hover:bg-emerald-700">
                          <CheckCircle2 className="w-3.5 h-3.5" /> Terminar
                        </button>
                      )}
                      {c.estado === 'completada' && (
                        <Link to="/historial" className="btn-primary text-xs py-1 px-2.5">
                          Cobrar $
                        </Link>
                      )}
                    </div>
                  </div>
                )
              })
            )}
          </div>
        </div>

        {/* Panel de Insumos Críticos & Reabastecimiento */}
        <div className="card-box space-y-4">
          <div className="border-b border-slate-100 pb-3">
            <h3 className="font-bold text-sm text-slate-800 flex items-center gap-2">
              <AlertTriangle className="w-4 h-4 text-rose-500" /> Insumos por Agotarse
            </h3>
            <p className="text-[11px] text-slate-400">Materiales que alcanzaron su nivel de stock mínimo</p>
          </div>

          <div className="space-y-2">
            {alertasStock.length === 0 ? (
              <div className="p-4 bg-emerald-50 text-emerald-700 rounded-xl text-xs font-semibold text-center">
                ✓ Todo el inventario está en niveles óptimos
              </div>
            ) : (
              alertasStock.map(p => (
                <div key={p.id} className="p-2.5 bg-rose-50/60 border border-rose-100 rounded-xl flex items-center justify-between text-xs">
                  <div>
                    <p className="font-bold text-slate-800">{p.nombre}</p>
                    <span className="text-[10px] text-slate-400">Mínimo sugerido: {p.stock_minimo}</span>
                  </div>
                  <div className="text-right">
                    <span className="badge bg-rose-100 text-rose-700 font-bold">Stock: {p.stock}</span>
                  </div>
                </div>
              ))
            )}
          </div>

          <Link to="/inventario" className="w-full btn-secondary justify-center text-xs py-2.5 mt-2">
            <Package className="w-4 h-4" /> Ir al Almacén / Reponer Stock
          </Link>
        </div>
      </div>
    </div>
  )
}
EOF

# 2. Historial Clínico con Facturación Directa, Recibos Imprimibles y Descuento de Insumos
cat > src/components/Consultorio/Historial.jsx << 'EOF'
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
EOF

# 3. Módulo de Almacén con Kardex Completo & Panel de Reabastecimiento
cat > src/components/Inventario/Inventario.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { fmt } from '../../utils/helpers'
import PriceBox from '../UI/PriceBox'
import QRScanner from '../UI/QRScanner'
import {
  Plus, AlertTriangle, QrCode, Printer, Search, RefreshCw,
  X, Save, ArrowDownLeft, ArrowUpRight, History, Package, ShoppingCart
} from 'lucide-react'
import toast from 'react-hot-toast'

export default function Inventario() {
  const { rates } = useCurrency()
  const [list, setList] = useState([])
  const [cats, setCats] = useState([])
  const [taxes, setTaxes] = useState([])
  const [movs, setMovs] = useState([])
  const [tab, setTab] = useState('stock') // stock | alertas | kardex | entrada
  const [showForm, setShowForm] = useState(false)
  const [activeLabel, setActiveLabel] = useState(null)
  const [scanning, setScanning] = useState(false)
  const [q, setQ] = useState('')

  // Formulario nuevo producto
  const [form, setForm] = useState({
    nombre: '', codigo: '', stock: 10, stock_minimo: 5,
    precio_compra: 0, precio_venta: '', categoria_id: '', impuesto_id: '', es_vendible: true
  })

  // Formulario entrada rápida de mercancía
  const [entradaForm, setEntradaForm] = useState({ producto_id: '', cantidad: 10, precio_compra: '', notas: '' })

  const load = async () => {
    const [p, c, t, m] = await Promise.all([
      supabase.from('productos').select('*, categorias(nombre, color), impuestos(nombre, porcentaje)').eq('activo', true).order('nombre'),
      supabase.from('categorias').select('*'),
      supabase.from('impuestos').select('*'),
      supabase.from('movimientos').select('*, productos(nombre, codigo)').order('created_at', { ascending: false }).limit(50)
    ])
    setList(p.data || []); setCats(c.data || []); setTaxes(t.data || []); setMovs(m.data || [])
  }

  useEffect(() => { load() }, [])

  const generateCode = () => {
    const cat = cats.find(x => x.id === form.categoria_id)
    const prefix = cat ? cat.nombre.slice(0, 3).toUpperCase() : 'ODN'
    const num = Math.floor(1000 + Math.random() * 9000)
    setForm(prev => ({ ...prev, codigo: `OD-${prefix}-${num}` }))
  }

  const saveProduct = async e => {
    e.preventDefault()
    if (!form.codigo) return toast.error('Debes generar o asignar un código')

    const { data: newProd, error } = await supabase.from('productos').insert([{
      ...form,
      precio_compra: parseFloat(form.precio_compra) || 0,
      precio_venta: parseFloat(form.precio_venta) || 0,
      stock: parseInt(form.stock) || 0,
      categoria_id: form.categoria_id || null,
      impuesto_id: form.impuesto_id || null
    }]).select().single()

    if (error) return toast.error('Error al guardar insumo')

    if (form.stock > 0 && newProd) {
      await supabase.from('movimientos').insert({
        producto_id: newProd.id,
        tipo: 'entrada',
        cantidad: Number(form.stock),
        stock_antes: 0,
        stock_despues: Number(form.stock),
        referencia: 'Stock Inicial',
        notas: 'Creación de insumo'
      })
    }

    toast.success('Insumo registrado')
    setShowForm(false); load()
  }

  const registrarEntradaStock = async e => {
    e.preventDefault()
    const prod = list.find(p => p.id === entradaForm.producto_id)
    if (!prod) return toast.error('Selecciona un insumo')

    const cant = parseInt(entradaForm.cantidad)
    const nuevoStock = prod.stock + cant

    await supabase.from('productos').update({
      stock: nuevoStock,
      precio_compra: parseFloat(entradaForm.precio_compra) || prod.precio_compra
    }).eq('id', prod.id)

    await supabase.from('movimientos').insert({
      producto_id: prod.id,
      tipo: 'entrada',
      cantidad: cant,
      stock_antes: prod.stock,
      stock_despues: nuevoStock,
      referencia: 'Compra / Reabastecimiento',
      notas: entradaForm.notas
    })

    toast.success(`+${cant} unidades agregadas a ${prod.nombre}`)
    setEntradaForm({ producto_id: '', cantidad: 10, precio_compra: '', notas: '' })
    setTab('stock')
    load()
  }

  const alertas = list.filter(i => i.stock <= i.stock_minimo)
  const filtered = list.filter(i => `${i.nombre} ${i.codigo} ${i.categorias?.nombre}`.toLowerCase().includes(q.toLowerCase()))

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Almacén & Kardex de Insumos</h1>
          <p className="text-xs text-slate-400">Control de existencias, trazabilidad y compras de reposición</p>
        </div>
        <div className="flex gap-2">
          <button onClick={() => setScanning(true)} className="btn-secondary"><QrCode className="w-4 h-4 text-teal-600" /> Escanear QR</button>
          <button onClick={() => { setShowForm(!showForm); setTab('stock') }} className={showForm ? 'btn-secondary' : 'btn-primary'}>
            {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Nuevo Insumo</>}
          </button>
        </div>
      </div>

      {/* Tabs de Navegación del Almacén */}
      <div className="flex border-b border-slate-200 gap-2">
        {[
          { id: 'stock', label: 'Stock Total', count: list.length, icon: Package },
          { id: 'alertas', label: 'Insumos por Agotarse', count: alertas.length, alert: alertas.length > 0, icon: AlertTriangle },
          { id: 'kardex', label: 'Kardex / Movimientos', count: movs.length, icon: History },
          { id: 'entrada', label: '+ Entrada de Mercancía', icon: ArrowDownLeft }
        ].map(t => (
          <button
            key={t.id}
            onClick={() => { setTab(t.id); setShowForm(false) }}
            className={`pb-2.5 px-3 text-xs font-bold border-b-2 flex items-center gap-1.5 transition-all ${
              tab === t.id
                ? 'border-teal-600 text-teal-700'
                : 'border-transparent text-slate-400 hover:text-slate-600'
            }`}
          >
            <t.icon className="w-3.5 h-3.5" />
            {t.label}
            {t.count !== undefined && (
              <span className={`px-1.5 py-0.2 rounded-full text-[10px] ${t.alert ? 'bg-rose-100 text-rose-700' : 'bg-slate-100 text-slate-600'}`}>
                {t.count}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* FORMULARIO NUEVO INSUMO */}
      {showForm && (
        <form onSubmit={saveProduct} className="card-box space-y-3 border-2 border-teal-200 bg-teal-50/20">
          <h3 className="font-bold text-sm text-teal-800">Registrar Nuevo Insumo en el Almacén</h3>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Categoría</label>
              <select required className="input-field" value={form.categoria_id} onChange={e => setForm({...form, categoria_id: e.target.value})}>
                <option value="">Seleccione...</option>
                {cats.map(c => <option key={c.id} value={c.id}>{c.nombre}</option>)}
              </select>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Código del Artículo</label>
              <div className="flex gap-1">
                <input required className="input-field font-mono" value={form.codigo} onChange={e => setForm({...form, codigo: e.target.value.toUpperCase()})} />
                <button type="button" onClick={generateCode} className="btn-secondary text-xs px-2"><RefreshCw className="w-3.5 h-3.5" /></button>
              </div>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Nombre</label>
              <input required className="input-field" value={form.nombre} onChange={e => setForm({...form, nombre: e.target.value})} placeholder="Ej: Resina 3M" />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Precio Venta ($ USD)</label>
              <input required type="number" step="0.01" className="input-field font-bold text-teal-700" value={form.precio_venta} onChange={e => setForm({...form, precio_venta: e.target.value})} placeholder="25.00" />
            </div>
          </div>
          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> Guardar Insumo</button>
            <button type="button" onClick={() => setShowForm(false)} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      {/* TAB 1: STOCK TOTAL */}
      {tab === 'stock' && (
        <div className="space-y-3">
          <div className="relative">
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input placeholder="Buscar por nombre, código o categoría..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
          </div>

          <div className="card-box p-0 overflow-hidden border">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-50 border-b text-slate-500 font-bold uppercase">
                <tr>
                  <th className="p-3.5">Código QR</th>
                  <th className="p-3.5">Insumo</th>
                  <th className="p-3.5">Categoría</th>
                  <th className="p-3.5">Stock</th>
                  <th className="p-3.5">Precio Venta</th>
                  <th className="p-3.5 text-right">Etiqueta</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {filtered.map(i => (
                  <tr key={i.id} className="hover:bg-slate-50">
                    <td className="p-3.5 font-mono font-bold text-slate-800 flex items-center gap-1.5"><QrCode className="w-3.5 h-3.5 text-teal-600" /> {i.codigo}</td>
                    <td className="p-3.5 font-bold text-slate-800">{i.nombre}</td>
                    <td className="p-3.5"><span className="badge bg-slate-100 text-slate-600">{i.categorias?.nombre || 'General'}</span></td>
                    <td className="p-3.5 font-bold">
                      <span className={i.stock <= i.stock_minimo ? 'text-rose-600 flex items-center gap-1' : 'text-slate-700'}>
                        {i.stock} {i.stock <= i.stock_minimo && <AlertTriangle className="w-3.5 h-3.5" />}
                      </span>
                    </td>
                    <td className="p-3.5"><PriceBox usd={i.precio_venta} showAll /></td>
                    <td className="p-3.5 text-right">
                      <button onClick={() => setActiveLabel(i)} className="p-1.5 bg-teal-50 text-teal-700 rounded-lg inline-flex items-center gap-1 font-bold">
                        <Printer className="w-3.5 h-3.5" /> Ver Etiqueta
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 2: INSUMOS POR AGOTARSE */}
      {tab === 'alertas' && (
        <div className="space-y-3">
          <div className="p-4 bg-rose-50 border border-rose-200 rounded-2xl flex items-center justify-between text-xs text-rose-800">
            <span>Hay <b>{alertas.length}</b> insumos por debajo de su stock mínimo.</span>
            <button onClick={() => setTab('entrada')} className="btn-primary bg-rose-600 hover:bg-rose-700 text-xs py-1.5">
              + Reponer Stock Ahora
            </button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
            {alertas.map(i => (
              <div key={i.id} className="card-box space-y-2 border-rose-200 bg-rose-50/20">
                <div className="flex justify-between items-start">
                  <div><h4 className="font-bold text-sm text-slate-800">{i.nombre}</h4><p className="text-[11px] font-mono text-slate-400">{i.codigo}</p></div>
                  <span className="badge bg-rose-100 text-rose-700 font-bold">Quedan: {i.stock}</span>
                </div>
                <div className="pt-2 border-t border-rose-100 flex justify-between text-xs text-slate-500">
                  <span>Mínimo requerido: {i.stock_minimo}</span>
                  <span className="font-bold text-teal-700">Faltan: {Math.max(0, i.stock_minimo - i.stock)}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* TAB 3: KARDEX / MOVIMIENTOS */}
      {tab === 'kardex' && (
        <div className="card-box p-0 overflow-hidden border">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-50 border-b text-slate-500 font-bold uppercase">
              <tr>
                <th className="p-3.5">Fecha</th>
                <th className="p-3.5">Insumo</th>
                <th className="p-3.5">Tipo de Movimiento</th>
                <th className="p-3.5">Cantidad</th>
                <th className="p-3.5">Stock Resultante</th>
                <th className="p-3.5">Referencia</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {movs.map(m => (
                <tr key={m.id} className="hover:bg-slate-50">
                  <td className="p-3.5 text-slate-400">{new Date(m.created_at).toLocaleString('es-VE')}</td>
                  <td className="p-3.5 font-bold text-slate-800">{m.productos?.nombre || 'Insumo'}</td>
                  <td className="p-3.5">
                    <span className={`badge ${
                      m.tipo === 'entrada' ? 'bg-emerald-100 text-emerald-800' :
                      m.tipo === 'venta' ? 'bg-blue-100 text-blue-800' :
                      m.tipo === 'uso_consultorio' ? 'bg-purple-100 text-purple-800' : 'bg-slate-100 text-slate-700'
                    }`}>
                      {m.tipo === 'entrada' ? '⬆ Entrada / Compra' :
                       m.tipo === 'venta' ? '⬇ Venta POS' :
                       m.tipo === 'uso_consultorio' ? '🦷 Uso en Consulta' : m.tipo}
                    </span>
                  </td>
                  <td className="p-3.5 font-bold font-mono">
                    <span className={m.cantidad > 0 ? 'text-emerald-600' : 'text-rose-600'}>
                      {m.cantidad > 0 ? `+${m.cantidad}` : m.cantidad}
                    </span>
                  </td>
                  <td className="p-3.5 font-mono">{m.stock_antes} ➔ <b>{m.stock_despues}</b></td>
                  <td className="p-3.5 text-slate-500">{m.referencia || m.notas || '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* TAB 4: ENTRADA DE MERCANCÍA */}
      {tab === 'entrada' && (
        <form onSubmit={registrarEntradaStock} className="card-box space-y-4 max-w-xl">
          <h3 className="font-bold text-sm text-slate-800 flex items-center gap-2">
            <ArrowDownLeft className="w-4 h-4 text-teal-600" /> Registrar Entrada de Insumos por Compra
          </h3>

          <div>
            <label className="text-xs font-semibold text-slate-600 block mb-1">Insumo a Reponer *</label>
            <select required className="input-field" value={entradaForm.producto_id} onChange={e => setEntradaForm({...entradaForm, producto_id: e.target.value})}>
              <option value="">Seleccionar insumo del almacén...</option>
              {list.map(p => <option key={p.id} value={p.id}>{p.nombre} (Stock actual: {p.stock})</option>)}
            </select>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-semibold text-slate-600 block mb-1">Cantidad Comprada *</label>
              <input required type="number" min="1" className="input-field font-bold" value={entradaForm.cantidad} onChange={e => setEntradaForm({...entradaForm, cantidad: e.target.value})} />
            </div>
            <div>
              <label className="text-xs font-semibold text-slate-600 block mb-1">Costo Unitario ($ USD)</label>
              <input type="number" step="0.01" className="input-field" value={entradaForm.precio_compra} onChange={e => setEntradaForm({...entradaForm, precio_compra: e.target.value})} placeholder="Costo de compra..." />
            </div>
          </div>

          <div>
            <label className="text-xs font-semibold text-slate-600 block mb-1">Notas / Factura Proveedor</label>
            <input className="input-field" value={entradaForm.notas} onChange={e => setEntradaForm({...entradaForm, notas: e.target.value})} placeholder="Ej: Compra Dental Medics Factura #123" />
          </div>

          <button type="submit" className="btn-primary w-full justify-center">
            <Save className="w-4 h-4" /> Registrar Entrada en Kardex
          </button>
        </form>
      )}

      {/* Modal Etiqueta QR */}
      {activeLabel && (
        <div className="card-box bg-slate-900 text-white p-6 rounded-2xl flex flex-col items-center justify-center space-y-3">
          <p className="font-bold text-sm uppercase">{activeLabel.nombre}</p>
          <div className="bg-white p-3 rounded-xl">
            <img src={`https://api.qrserver.com/v1/create-qr-code/?size=140x140&data=${encodeURIComponent(activeLabel.codigo)}`} alt="QR" className="w-28 h-28" />
          </div>
          <p className="font-mono font-bold text-xs text-teal-400 tracking-widest">{activeLabel.codigo}</p>
          <div className="flex gap-2">
            <button onClick={() => window.print()} className="btn-primary text-xs"><Printer className="w-3.5 h-3.5" /> Imprimir Etiqueta</button>
            <button onClick={() => setActiveLabel(null)} className="btn-secondary text-xs">Cerrar</button>
          </div>
        </div>
      )}

      {scanning && <QRScanner onScan={(code) => { setScanning(false); setQ(code); setTab('stock'); toast.success(`QR: ${code}`) }} onClose={() => setScanning(false)} />}
    </div>
  )
}
EOF

npm run build
echo "✅ Prioridad 1 compilada exitosamente sin errores."
