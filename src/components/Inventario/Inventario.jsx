import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { fmt } from '../../utils/helpers'
import PriceBox from '../UI/PriceBox'
import QRScanner from '../UI/QRScanner'
import {
  Plus, AlertTriangle, QrCode, Printer, Search, RefreshCw,
  X, Save, ArrowDownLeft, History, Package, Calendar
} from 'lucide-react'
import toast from 'react-hot-toast'

export default function Inventario() {
  const { rates } = useCurrency()
  const [list, setList] = useState([])
  const [cats, setCats] = useState([])
  const [movs, setMovs] = useState([])
  const [tab, setTab] = useState('stock')
  const [showForm, setShowForm] = useState(false)
  const [activeLabel, setActiveLabel] = useState(null)
  const [scanning, setScanning] = useState(false)
  const [q, setQ] = useState('')

  const [form, setForm] = useState({
    nombre: '', codigo: '', stock: 10, stock_minimo: 5,
    precio_compra: 0, precio_venta: '', categoria_id: '',
    impuesto_id: '', es_vendible: true, fecha_vencimiento: '', lote: ''
  })
  const [entradaForm, setEntradaForm] = useState({ producto_id: '', cantidad: 10, precio_compra: '', notas: '' })

  const load = async () => {
    const [p, c, m] = await Promise.all([
      supabase.from('productos').select('*, categorias(nombre, color), impuestos(nombre, porcentaje)').eq('activo', true).order('nombre'),
      supabase.from('categorias').select('*'),
      supabase.from('movimientos').select('*, productos(nombre, codigo)').order('created_at', { ascending: false }).limit(50)
    ])
    setList(p.data || []); setCats(c.data || []); setMovs(m.data || [])
  }
  useEffect(() => { load() }, [])

  const generateCode = () => {
    const cat = cats.find(x => x.id === form.categoria_id)
    const prefix = cat ? cat.nombre.slice(0, 3).toUpperCase() : 'ODN'
    setForm(prev => ({ ...prev, codigo: `OD-${prefix}-${Math.floor(1000 + Math.random() * 9000)}` }))
  }

  const saveProduct = async e => {
    e.preventDefault()
    if (!form.codigo) return toast.error('Genera un código')
    const { data: np, error } = await supabase.from('productos').insert([{
      ...form, precio_compra: parseFloat(form.precio_compra) || 0, precio_venta: parseFloat(form.precio_venta) || 0,
      stock: parseInt(form.stock) || 0, categoria_id: form.categoria_id || null,
      impuesto_id: form.impuesto_id || null, fecha_vencimiento: form.fecha_vencimiento || null
    }]).select().single()
    if (error) return toast.error('Error')
    if (form.stock > 0 && np) {
      await supabase.from('movimientos').insert({ producto_id: np.id, tipo: 'entrada', cantidad: Number(form.stock), stock_antes: 0, stock_despues: Number(form.stock), referencia: 'Stock Inicial' })
    }
    toast.success('Insumo registrado'); setShowForm(false); load()
  }

  const registrarEntrada = async e => {
    e.preventDefault()
    const prod = list.find(p => p.id === entradaForm.producto_id)
    if (!prod) return toast.error('Selecciona un insumo')
    const cant = parseInt(entradaForm.cantidad)
    const nuevo = prod.stock + cant
    await supabase.from('productos').update({ stock: nuevo, precio_compra: parseFloat(entradaForm.precio_compra) || prod.precio_compra }).eq('id', prod.id)
    await supabase.from('movimientos').insert({ producto_id: prod.id, tipo: 'entrada', cantidad: cant, stock_antes: prod.stock, stock_despues: nuevo, referencia: 'Compra', notas: entradaForm.notas })
    toast.success(`+${cant} unidades a ${prod.nombre}`); setEntradaForm({ producto_id: '', cantidad: 10, precio_compra: '', notas: '' }); setTab('stock'); load()
  }

  // D. Vencimientos próximos (30 días)
  const hoy = new Date()
  const en30 = new Date(hoy.getTime() + 30 * 24 * 60 * 60 * 1000)
  const vencimientos = list.filter(i => {
    if (!i.fecha_vencimiento) return false
    const fv = new Date(i.fecha_vencimiento)
    return fv <= en30
  })

  const alertas = list.filter(i => i.stock <= i.stock_minimo)
  const filtered = list.filter(i => `${i.nombre} ${i.codigo}`.toLowerCase().includes(q.toLowerCase()))

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div><h1 className="text-xl font-bold text-slate-800">Almacén & Kardex de Insumos</h1><p className="text-xs text-slate-400">Stock, vencimientos, trazabilidad y compras</p></div>
        <div className="flex gap-2">
          <button onClick={() => setScanning(true)} className="btn-secondary"><QrCode className="w-4 h-4 text-teal-600" /> QR</button>
          <button onClick={() => { setShowForm(!showForm); setTab('stock') }} className={showForm ? 'btn-secondary' : 'btn-primary'}>
            {showForm ? <><X className="w-4 h-4" /></> : <><Plus className="w-4 h-4" /> Nuevo</>}
          </button>
        </div>
      </div>

      {/* D. Alerta de Vencimientos */}
      {vencimientos.length > 0 && (
        <div className="p-3 bg-amber-50 border border-amber-200 rounded-xl text-xs text-amber-800 font-semibold flex items-center gap-2">
          <AlertTriangle className="w-4 h-4" /> {vencimientos.length} insumo{vencimientos.length > 1 ? 's' : ''} próximo{vencimientos.length > 1 ? 's' : ''} a vencer en los próximos 30 días
        </div>
      )}

      <div className="flex border-b border-slate-200 gap-2 overflow-x-auto">
        {[
          { id: 'stock', label: 'Stock', count: list.length },
          { id: 'alertas', label: 'Stock Bajo', count: alertas.length, alert: alertas.length > 0 },
          { id: 'vencimientos', label: 'Vencimientos', count: vencimientos.length, alert: vencimientos.length > 0 },
          { id: 'kardex', label: 'Kardex', count: movs.length },
          { id: 'entrada', label: '+ Entrada' }
        ].map(t => (
          <button key={t.id} onClick={() => { setTab(t.id); setShowForm(false) }}
            className={`pb-2.5 px-3 text-xs font-bold border-b-2 flex items-center gap-1 whitespace-nowrap ${tab === t.id ? 'border-teal-600 text-teal-700' : 'border-transparent text-slate-400'}`}>
            {t.label} {t.count !== undefined && <span className={`px-1.5 rounded-full text-[10px] ${t.alert ? 'bg-rose-100 text-rose-700' : 'bg-slate-100'}`}>{t.count}</span>}
          </button>
        ))}
      </div>

      {showForm && (
        <form onSubmit={saveProduct} className="card-box space-y-3 border-2 border-teal-200 bg-teal-50/20">
          <h3 className="font-bold text-sm text-teal-800">Registrar Insumo</h3>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Categoría</label>
              <select required className="input-field" value={form.categoria_id} onChange={e => setForm({...form, categoria_id: e.target.value})}>
                <option value="">Seleccione...</option>{cats.map(c => <option key={c.id} value={c.id}>{c.nombre}</option>)}
              </select>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Código</label>
              <div className="flex gap-1"><input required className="input-field font-mono" value={form.codigo} onChange={e => setForm({...form, codigo: e.target.value.toUpperCase()})} /><button type="button" onClick={generateCode} className="btn-secondary text-xs px-2"><RefreshCw className="w-3.5 h-3.5" /></button></div>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Nombre</label><input required className="input-field" value={form.nombre} onChange={e => setForm({...form, nombre: e.target.value})} /></div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Precio Venta $</label><input required type="number" step="0.01" className="input-field font-bold text-teal-700" value={form.precio_venta} onChange={e => setForm({...form, precio_venta: e.target.value})} /></div>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Stock</label><input type="number" className="input-field" value={form.stock} onChange={e => setForm({...form, stock: e.target.value})} /></div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Lote</label><input className="input-field" value={form.lote} onChange={e => setForm({...form, lote: e.target.value})} placeholder="LOT-2025-001" /></div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Fecha Vencimiento</label><input type="date" className="input-field" value={form.fecha_vencimiento} onChange={e => setForm({...form, fecha_vencimiento: e.target.value})} /></div>
          </div>
          <div className="flex gap-2"><button type="submit" className="btn-primary"><Save className="w-4 h-4" /> Guardar</button><button type="button" onClick={() => setShowForm(false)} className="btn-secondary">Cancelar</button></div>
        </form>
      )}

      {tab === 'stock' && (
        <div className="space-y-3">
          <div className="relative"><Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" /><input placeholder="Buscar..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" /></div>
          <div className="card-box p-0 overflow-hidden border">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-50 border-b text-slate-500 font-bold uppercase"><tr><th className="p-3">Código</th><th className="p-3">Insumo</th><th className="p-3">Stock</th><th className="p-3">Vence</th><th className="p-3">Precio</th><th className="p-3 text-right">QR</th></tr></thead>
              <tbody className="divide-y">
                {filtered.map(i => (
                  <tr key={i.id} className="hover:bg-slate-50">
                    <td className="p-3 font-mono font-bold flex items-center gap-1"><QrCode className="w-3 h-3 text-teal-600" />{i.codigo}</td>
                    <td className="p-3 font-bold">{i.nombre}</td>
                    <td className="p-3 font-bold"><span className={i.stock <= i.stock_minimo ? 'text-rose-600' : ''}>{i.stock}</span></td>
                    <td className="p-3">{i.fecha_vencimiento ? <span className={new Date(i.fecha_vencimiento) <= en30 ? 'text-amber-600 font-bold' : 'text-slate-400'}>{new Date(i.fecha_vencimiento).toLocaleDateString('es-VE')}</span> : '—'}</td>
                    <td className="p-3"><PriceBox usd={i.precio_venta} showAll /></td>
                    <td className="p-3 text-right"><button onClick={() => setActiveLabel(i)} className="p-1.5 bg-teal-50 text-teal-700 rounded-lg"><Printer className="w-3.5 h-3.5" /></button></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {tab === 'alertas' && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
          {alertas.map(i => (
            <div key={i.id} className="card-box border-rose-200 bg-rose-50/20"><h4 className="font-bold text-sm">{i.nombre}</h4><p className="text-xs text-rose-600 font-bold mt-1">Stock: {i.stock} / Mín: {i.stock_minimo}</p></div>
          ))}
        </div>
      )}

      {tab === 'vencimientos' && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
          {vencimientos.map(i => (
            <div key={i.id} className="card-box border-amber-200 bg-amber-50/20">
              <h4 className="font-bold text-sm">{i.nombre}</h4>
              <p className="text-xs text-slate-500">Lote: {i.lote || '—'}</p>
              <p className="text-xs text-amber-700 font-bold mt-1">Vence: {new Date(i.fecha_vencimiento).toLocaleDateString('es-VE')}</p>
            </div>
          ))}
        </div>
      )}

      {tab === 'kardex' && (
        <div className="card-box p-0 overflow-hidden border">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-50 border-b text-slate-500 font-bold uppercase"><tr><th className="p-3">Fecha</th><th className="p-3">Insumo</th><th className="p-3">Tipo</th><th className="p-3">Cant</th><th className="p-3">Stock</th><th className="p-3">Ref</th></tr></thead>
            <tbody className="divide-y">
              {movs.map(m => (
                <tr key={m.id} className="hover:bg-slate-50">
                  <td className="p-3 text-slate-400">{new Date(m.created_at).toLocaleDateString('es-VE')}</td>
                  <td className="p-3 font-bold">{m.productos?.nombre}</td>
                  <td className="p-3"><span className={`badge ${m.tipo === 'entrada' ? 'bg-emerald-100 text-emerald-800' : m.tipo === 'venta' ? 'bg-blue-100 text-blue-800' : 'bg-purple-100 text-purple-800'}`}>{m.tipo}</span></td>
                  <td className="p-3 font-mono font-bold"><span className={m.cantidad > 0 ? 'text-emerald-600' : 'text-rose-600'}>{m.cantidad > 0 ? `+${m.cantidad}` : m.cantidad}</span></td>
                  <td className="p-3 font-mono">{m.stock_antes}→{m.stock_despues}</td>
                  <td className="p-3 text-slate-400">{m.referencia || '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {tab === 'entrada' && (
        <form onSubmit={registrarEntrada} className="card-box space-y-3 max-w-xl">
          <h3 className="font-bold text-sm">Entrada de Mercancía</h3>
          <select required className="input-field" value={entradaForm.producto_id} onChange={e => setEntradaForm({...entradaForm, producto_id: e.target.value})}>
            <option value="">Seleccionar...</option>{list.map(p => <option key={p.id} value={p.id}>{p.nombre} (Stock: {p.stock})</option>)}
          </select>
          <div className="grid grid-cols-2 gap-3">
            <input required type="number" min="1" className="input-field" placeholder="Cantidad" value={entradaForm.cantidad} onChange={e => setEntradaForm({...entradaForm, cantidad: e.target.value})} />
            <input type="number" step="0.01" className="input-field" placeholder="Costo $" value={entradaForm.precio_compra} onChange={e => setEntradaForm({...entradaForm, precio_compra: e.target.value})} />
          </div>
          <input className="input-field" placeholder="Notas / Factura" value={entradaForm.notas} onChange={e => setEntradaForm({...entradaForm, notas: e.target.value})} />
          <button type="submit" className="btn-primary w-full"><Save className="w-4 h-4" /> Registrar Entrada</button>
        </form>
      )}

      {activeLabel && (
        <div className="card-box bg-slate-900 text-white p-6 rounded-2xl flex flex-col items-center space-y-3">
          <p className="font-bold text-sm">{activeLabel.nombre}</p>
          <div className="bg-white p-3 rounded-xl"><img src={`https://api.qrserver.com/v1/create-qr-code/?size=140x140&data=${encodeURIComponent(activeLabel.codigo)}`} alt="QR" className="w-28 h-28" /></div>
          <p className="font-mono text-xs text-teal-400">{activeLabel.codigo}</p>
          <div className="flex gap-2"><button onClick={() => window.print()} className="btn-primary text-xs"><Printer className="w-3.5 h-3.5" /> Imprimir</button><button onClick={() => setActiveLabel(null)} className="btn-secondary text-xs">Cerrar</button></div>
        </div>
      )}
      {scanning && <QRScanner onScan={c => { setScanning(false); setQ(c); setTab('stock') }} onClose={() => setScanning(false)} />}
    </div>
  )
}
