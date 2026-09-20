import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { fmt } from '../../utils/helpers'
import {
  Plus, DollarSign, TrendingDown, TrendingUp, Calculator,
  Save, X, Download, Printer, ArrowDownLeft, ArrowUpRight,
  Receipt, Wallet, AlertCircle
} from 'lucide-react'
import toast from 'react-hot-toast'

const categoriasGasto = [
  'Servicios Públicos', 'Alquiler', 'Internet/Teléfono', 'Limpieza',
  'Materiales de Oficina', 'Mantenimiento Equipos', 'Café/Agua',
  'Transporte', 'Sueldos', 'Impuestos', 'Laboratorio Dental', 'Otros'
]

export default function CajaChica() {
  const { rates } = useCurrency()
  const [gastos, setGastos] = useState([])
  const [ventas, setVentas] = useState([])
  const [consultas, setConsultas] = useState([])
  const [showGasto, setShowGasto] = useState(false)
  const [fecha, setFecha] = useState(new Date().toISOString().split('T')[0])
  const [formGasto, setFormGasto] = useState({ categoria: 'Otros', descripcion: '', monto_usd: '', metodo_pago: 'efectivo_usd' })

  const load = async () => {
    const [gRes, vRes, cRes] = await Promise.all([
      supabase.from('gastos').select('*').eq('fecha', fecha).order('created_at', { ascending: false }),
      supabase.from('ventas').select('total_usd, created_at').eq('estado', 'completada').gte('created_at', `${fecha}T00:00:00`).lte('created_at', `${fecha}T23:59:59`),
      supabase.from('historial_clinico').select('monto_usd, created_at').eq('pagado', true).gte('created_at', `${fecha}T00:00:00`).lte('created_at', `${fecha}T23:59:59`)
    ])
    setGastos(gRes.data || [])
    setVentas(vRes.data || [])
    setConsultas(cRes.data || [])
  }

  useEffect(() => { load() }, [fecha])

  const saveGasto = async (e) => {
    e.preventDefault()
    await supabase.from('gastos').insert([{ ...formGasto, monto_usd: parseFloat(formGasto.monto_usd) || 0, fecha }])
    toast.success('Gasto registrado')
    setShowGasto(false)
    setFormGasto({ categoria: 'Otros', descripcion: '', monto_usd: '', metodo_pago: 'efectivo_usd' })
    load()
  }

  const totalIngresos = ventas.reduce((a, b) => a + Number(b.total_usd), 0) + consultas.reduce((a, b) => a + Number(b.monto_usd), 0)
  const totalGastos = gastos.reduce((a, b) => a + Number(b.monto_usd), 0)
  const gananciaNeta = totalIngresos - totalGastos

  const exportarCierre = () => {
    let csv = 'data:text/csv;charset=utf-8,'
    csv += 'CIERRE DE CAJA - ' + fecha + '\n\n'
    csv += 'CONCEPTO,USD,Bs (BCV),COP\n'
    csv += `Ingresos Consultorio,${consultas.reduce((a,b)=>a+Number(b.monto_usd),0).toFixed(2)},${(consultas.reduce((a,b)=>a+Number(b.monto_usd),0)*rates.VES).toFixed(2)},${(consultas.reduce((a,b)=>a+Number(b.monto_usd),0)*rates.COP).toFixed(0)}\n`
    csv += `Ingresos Ventas POS,${ventas.reduce((a,b)=>a+Number(b.total_usd),0).toFixed(2)},${(ventas.reduce((a,b)=>a+Number(b.total_usd),0)*rates.VES).toFixed(2)},${(ventas.reduce((a,b)=>a+Number(b.total_usd),0)*rates.COP).toFixed(0)}\n`
    csv += `TOTAL INGRESOS,${totalIngresos.toFixed(2)},${(totalIngresos*rates.VES).toFixed(2)},${(totalIngresos*rates.COP).toFixed(0)}\n\n`
    csv += 'GASTOS OPERATIVOS\n'
    gastos.forEach(g => { csv += `${g.categoria} - ${g.descripcion},${g.monto_usd},${(g.monto_usd*rates.VES).toFixed(2)},${(g.monto_usd*rates.COP).toFixed(0)}\n` })
    csv += `\nTOTAL GASTOS,${totalGastos.toFixed(2)},${(totalGastos*rates.VES).toFixed(2)},${(totalGastos*rates.COP).toFixed(0)}\n`
    csv += `GANANCIA NETA,${gananciaNeta.toFixed(2)},${(gananciaNeta*rates.VES).toFixed(2)},${(gananciaNeta*rates.COP).toFixed(0)}\n`
    const link = document.createElement('a')
    link.setAttribute('href', encodeURI(csv))
    link.setAttribute('download', `cierre_caja_${fecha}.csv`)
    document.body.appendChild(link); link.click(); document.body.removeChild(link)
    toast.success('Cierre de caja exportado')
  }

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Caja Chica, Gastos & Cierre Diario</h1>
          <p className="text-xs text-slate-400">Control de egresos operativos y ganancia neta real del día</p>
        </div>
        <div className="flex gap-2">
          <button onClick={() => setShowGasto(!showGasto)} className={showGasto ? 'btn-secondary' : 'btn-primary'}>
            {showGasto ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Registrar Gasto</>}
          </button>
        </div>
      </div>

      {/* Selector de fecha */}
      <div className="card-box p-3 flex items-center justify-between">
        <span className="text-xs font-bold text-slate-500">Fecha del Cierre:</span>
        <input type="date" value={fecha} onChange={e => setFecha(e.target.value)} className="input-field w-auto font-bold text-xs" />
      </div>

      {/* Resumen de Cierre */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="card-box bg-emerald-600 text-white p-5">
          <div className="flex justify-between items-start">
            <div>
              <p className="text-xs text-emerald-100 font-semibold uppercase">Total Ingresos</p>
              <h3 className="text-2xl font-bold mt-1">{fmt(totalIngresos, 'USD')}</h3>
            </div>
            <TrendingUp className="w-5 h-5 text-emerald-200" />
          </div>
          <p className="text-[10px] text-emerald-200 mt-2">Consultorio: {fmt(consultas.reduce((a,b)=>a+Number(b.monto_usd),0))} | POS: {fmt(ventas.reduce((a,b)=>a+Number(b.total_usd),0))}</p>
        </div>

        <div className="card-box bg-rose-600 text-white p-5">
          <div className="flex justify-between items-start">
            <div>
              <p className="text-xs text-rose-100 font-semibold uppercase">Total Gastos</p>
              <h3 className="text-2xl font-bold mt-1">{fmt(totalGastos, 'USD')}</h3>
            </div>
            <TrendingDown className="w-5 h-5 text-rose-200" />
          </div>
          <p className="text-[10px] text-rose-200 mt-2">{gastos.length} gastos registrados hoy</p>
        </div>

        <div className={`card-box p-5 text-white ${gananciaNeta >= 0 ? 'bg-teal-700' : 'bg-red-800'}`}>
          <div className="flex justify-between items-start">
            <div>
              <p className="text-xs font-semibold uppercase opacity-80">Ganancia Neta Real</p>
              <h3 className="text-2xl font-bold mt-1">{fmt(gananciaNeta, 'USD')}</h3>
            </div>
            <Calculator className="w-5 h-5 opacity-60" />
          </div>
          <p className="text-[10px] opacity-70 mt-2">Bs. {fmt(gananciaNeta * rates.VES, 'VES')} | COP {fmt(gananciaNeta * rates.COP, 'COP')}</p>
        </div>
      </div>

      {/* Formulario de Gasto */}
      {showGasto && (
        <form onSubmit={saveGasto} className="card-box space-y-3 border-2 border-rose-200 bg-rose-50/20">
          <h3 className="font-bold text-sm text-rose-800">Registrar Gasto Operativo</h3>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Categoría</label>
              <select className="input-field" value={formGasto.categoria} onChange={e => setFormGasto({...formGasto, categoria: e.target.value})}>
                {categoriasGasto.map(c => <option key={c}>{c}</option>)}
              </select>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Descripción</label>
              <input required className="input-field" value={formGasto.descripcion} onChange={e => setFormGasto({...formGasto, descripcion: e.target.value})} placeholder="Ej: Pago de luz" />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Monto ($ USD)</label>
              <input required type="number" step="0.01" className="input-field font-bold text-rose-700" value={formGasto.monto_usd} onChange={e => setFormGasto({...formGasto, monto_usd: e.target.value})} />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Método de Pago</label>
              <select className="input-field" value={formGasto.metodo_pago} onChange={e => setFormGasto({...formGasto, metodo_pago: e.target.value})}>
                <option value="efectivo_usd">Efectivo $</option>
                <option value="efectivo_ves">Efectivo Bs.</option>
                <option value="transferencia">Transferencia</option>
                <option value="pago_movil">Pago Móvil</option>
              </select>
            </div>
          </div>
          <div className="flex gap-2">
            <button type="submit" className="btn-primary bg-rose-600 hover:bg-rose-700"><Save className="w-4 h-4" /> Registrar Gasto</button>
            <button type="button" onClick={() => setShowGasto(false)} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      {/* Lista de Gastos del Día */}
      <div className="card-box p-0 overflow-hidden border">
        <div className="p-3 bg-slate-50 border-b flex justify-between items-center">
          <h3 className="font-bold text-xs text-slate-600">Gastos del Día ({gastos.length})</h3>
          <button onClick={exportarCierre} className="btn-primary text-xs py-1.5"><Download className="w-3.5 h-3.5" /> Exportar Cierre de Caja</button>
        </div>
        <table className="w-full text-left text-xs">
          <thead className="bg-slate-50 border-b text-slate-500 font-bold uppercase">
            <tr><th className="p-3">Categoría</th><th className="p-3">Descripción</th><th className="p-3">Monto USD</th><th className="p-3">Monto Bs.</th><th className="p-3">Método</th></tr>
          </thead>
          <tbody className="divide-y">
            {gastos.length === 0 ? <tr><td colSpan={5} className="p-6 text-center text-slate-400">Sin gastos registrados hoy</td></tr> :
            gastos.map(g => (
              <tr key={g.id} className="hover:bg-slate-50">
                <td className="p-3"><span className="badge bg-rose-50 text-rose-700">{g.categoria}</span></td>
                <td className="p-3 font-medium">{g.descripcion}</td>
                <td className="p-3 font-bold text-rose-600">-{fmt(g.monto_usd, 'USD')}</td>
                <td className="p-3 text-slate-500">-{fmt(g.monto_usd * rates.VES, 'VES')}</td>
                <td className="p-3 text-slate-400">{g.metodo_pago}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
