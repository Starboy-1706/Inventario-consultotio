import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { fmt } from '../../utils/helpers'
import { Search, XCircle } from 'lucide-react'
import toast from 'react-hot-toast'

export default function HistorialVentas() {
  const [list, setList] = useState([])
  const [q, setQ] = useState('')

  const load = async () => {
    const { data } = await supabase.from('ventas').select('*').order('created_at', { ascending: false })
    setList(data || [])
  }
  useEffect(() => { load() }, [])

  const anular = async v => {
    if (!confirm(`¿Anular la factura ${v.factura}?`)) return
    await supabase.from('ventas').update({ estado: 'anulada' }).eq('id', v.id)
    toast.success('Venta anulada')
    load()
  }

  const filtered = list.filter(v => `${v.factura} ${v.cliente}`.toLowerCase().includes(q.toLowerCase()))

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-xl font-bold text-slate-800">Historial de Ventas</h1>
        <p className="text-xs text-slate-400">Auditoría de facturación y pagos</p>
      </div>

      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input placeholder="Buscar por factura o cliente..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
      </div>

      <div className="card-box p-0 overflow-hidden border">
        <table className="w-full text-left text-xs">
          <thead className="bg-slate-50 border-b text-slate-500 font-bold uppercase">
            <tr>
              <th className="p-3.5">Factura</th>
              <th className="p-3.5">Cliente</th>
              <th className="p-3.5">Total USD</th>
              <th className="p-3.5">Total Bs (BCV)</th>
              <th className="p-3.5">Total COP</th>
              <th className="p-3.5">Estado</th>
              <th className="p-3.5 text-right">Acción</th>
            </tr>
          </thead>
          <tbody className="divide-y">
            {filtered.map(v => (
              <tr key={v.id} className={v.estado === 'anulada' ? 'opacity-40 bg-slate-50' : ''}>
                <td className="p-3.5 font-mono font-bold text-slate-800">{v.factura}</td>
                <td className="p-3.5">{v.cliente}</td>
                <td className="p-3.5 font-bold text-teal-700">{fmt(v.total_usd, 'USD')}</td>
                <td className="p-3.5 font-semibold text-slate-600">{fmt(v.total_ves, 'VES')}</td>
                <td className="p-3.5 font-semibold text-amber-700">{fmt(v.total_cop, 'COP')}</td>
                <td className="p-3.5">
                  <span className={`badge ${v.estado === 'anulada' ? 'bg-rose-100 text-rose-700' : 'bg-emerald-100 text-emerald-700'}`}>
                    {v.estado}
                  </span>
                </td>
                <td className="p-3.5 text-right">
                  {v.estado !== 'anulada' && (
                    <button onClick={() => anular(v)} className="p-1.5 hover:bg-rose-50 rounded-lg text-rose-600" title="Anular"><XCircle className="w-4 h-4" /></button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
