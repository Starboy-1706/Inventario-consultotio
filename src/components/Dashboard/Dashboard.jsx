import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import PriceBox from '../UI/PriceBox'
import { Users, Calendar, ShoppingBag, Package, AlertTriangle, ArrowUpRight } from 'lucide-react'
import { Link } from 'react-router-dom'

export default function Dashboard() {
  const [stats, setStats] = useState({ pacs: 0, citas: 0, ventasTotal: 0, lowStock: 0 })
  const [citasHoy, setCitasHoy] = useState([])
  const [prodsBajos, setProdsBajos] = useState([])

  const load = async () => {
    const today = new Date().toISOString().split('T')[0]
    const [p, c, v, pr] = await Promise.all([
      supabase.from('pacientes').select('id', { count: 'exact', head: true }).eq('activo', true),
      supabase.from('citas').select('*, pacientes(nombres, apellidos), tratamientos(nombre)').gte('fecha', `${today}T00:00:00`).lte('fecha', `${today}T23:59:59`),
      supabase.from('ventas').select('total_usd').eq('estado', 'completada'),
      supabase.from('productos').select('*').eq('activo', true)
    ])

    const totalV = v.data?.reduce((a, b) => a + Number(b.total_usd), 0) || 0
    const low = pr.data?.filter(x => x.stock <= x.stock_minimo) || []

    setStats({ pacs: p.count || 0, citas: c.data?.length || 0, ventasTotal: totalV, lowStock: low.length })
    setCitasHoy(c.data || [])
    setProdsBajos(low.slice(0, 5))
  }
  useEffect(() => { load() }, [])

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-bold text-slate-800">Panel de Control</h1>
        <p className="text-xs text-slate-400">Resumen operativo del consultorio y ventas de insumos</p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="card-box flex items-center justify-between">
          <div><p className="text-xs text-slate-400 font-medium">Pacientes Registrados</p><h3 className="text-2xl font-bold text-slate-800 mt-1">{stats.pacs}</h3></div>
          <div className="w-12 h-12 bg-blue-50 text-blue-600 rounded-2xl flex items-center justify-center"><Users className="w-6 h-6" /></div>
        </div>
        <div className="card-box flex items-center justify-between">
          <div><p className="text-xs text-slate-400 font-medium">Citas para Hoy</p><h3 className="text-2xl font-bold text-slate-800 mt-1">{stats.citas}</h3></div>
          <div className="w-12 h-12 bg-teal-50 text-teal-600 rounded-2xl flex items-center justify-center"><Calendar className="w-6 h-6" /></div>
        </div>
        <div className="card-box flex items-center justify-between">
          <div>
            <p className="text-xs text-slate-400 font-medium">Ventas de Insumos</p>
            <h3 className="text-xl font-bold text-slate-800 mt-1"><PriceBox usd={stats.ventasTotal} /></h3>
          </div>
          <div className="w-12 h-12 bg-emerald-50 text-emerald-600 rounded-2xl flex items-center justify-center"><ShoppingBag className="w-6 h-6" /></div>
        </div>
        <div className="card-box flex items-center justify-between">
          <div><p className="text-xs text-slate-400 font-medium">Insumos en Alerta</p><h3 className="text-2xl font-bold text-rose-600 mt-1">{stats.lowStock}</h3></div>
          <div className="w-12 h-12 bg-rose-50 text-rose-600 rounded-2xl flex items-center justify-center"><AlertTriangle className="w-6 h-6" /></div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Citas de Hoy */}
        <div className="card-box space-y-3">
          <div className="flex justify-between items-center border-b pb-2">
            <h3 className="font-bold text-sm text-slate-800 flex items-center gap-2"><Calendar className="w-4 h-4 text-teal-600" /> Agenda de Hoy</h3>
            <Link to="/citas" className="text-xs font-semibold text-teal-600 flex items-center gap-1 hover:underline">Ver todas <ArrowUpRight className="w-3.5 h-3.5" /></Link>
          </div>
          <div className="space-y-2">
            {citasHoy.length === 0 ? <p className="text-xs text-slate-400 py-6 text-center">No hay citas para hoy</p> :
            citasHoy.map(c => (
              <div key={c.id} className="flex justify-between items-center p-2.5 bg-slate-50 rounded-xl text-xs">
                <div><p className="font-bold text-slate-800">{c.pacientes?.nombres} {c.pacientes?.apellidos}</p><span className="text-slate-400">{c.tratamientos?.nombre || 'Consulta General'}</span></div>
                <span className="font-bold text-teal-700">{new Date(c.fecha).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Insumos con bajo stock */}
        <div className="card-box space-y-3">
          <div className="flex justify-between items-center border-b pb-2">
            <h3 className="font-bold text-sm text-slate-800 flex items-center gap-2"><Package className="w-4 h-4 text-rose-500" /> Insumos con Stock Bajo</h3>
            <Link to="/inventario" className="text-xs font-semibold text-teal-600 flex items-center gap-1 hover:underline">Ir al almacén <ArrowUpRight className="w-3.5 h-3.5" /></Link>
          </div>
          <div className="space-y-2">
            {prodsBajos.length === 0 ? <p className="text-xs text-slate-400 py-6 text-center">Stock de insumos en óptimas condiciones</p> :
            prodsBajos.map(p => (
              <div key={p.id} className="flex justify-between items-center p-2.5 bg-rose-50/50 border border-rose-100 rounded-xl text-xs">
                <div><p className="font-bold text-slate-800">{p.nombre}</p><span className="text-slate-400">{p.codigo || 'S/C'}</span></div>
                <span className="badge bg-rose-100 text-rose-700 font-bold">Stock: {p.stock} (Mín: {p.stock_minimo})</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
