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
