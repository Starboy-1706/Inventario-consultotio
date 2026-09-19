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
