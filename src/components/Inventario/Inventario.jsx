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
