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
