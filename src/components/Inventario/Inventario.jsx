import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import PriceBox from '../UI/PriceBox'
import QRScanner from '../UI/QRScanner'
import { Plus, AlertTriangle, QrCode, Printer, Search, RefreshCw, X, Save } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Inventario() {
  const [list, setList] = useState([])
  const [cats, setCats] = useState([])
  const [taxes, setTaxes] = useState([])
  const [showForm, setShowForm] = useState(false)
  const [activeLabel, setActiveLabel] = useState(null)
  const [scanning, setScanning] = useState(false)
  const [q, setQ] = useState('')

  const [form, setForm] = useState({
    nombre: '', codigo: '', stock: 10, stock_minimo: 5,
    precio_compra: 0, precio_venta: '', categoria_id: '', impuesto_id: '', es_vendible: true
  })

  const load = async () => {
    const [p, c, t] = await Promise.all([
      supabase.from('productos').select('*, categorias(nombre, color), impuestos(nombre, porcentaje)').eq('activo', true).order('nombre'),
      supabase.from('categorias').select('*'),
      supabase.from('impuestos').select('*')
    ])
    setList(p.data || []); setCats(c.data || []); setTaxes(t.data || [])
  }
  useEffect(() => { load() }, [])

  const generateCode = () => {
    const cat = cats.find(x => x.id === form.categoria_id)
    const prefix = cat ? cat.nombre.slice(0, 3).toUpperCase() : 'ODN'
    const num = Math.floor(1000 + Math.random() * 9000)
    setForm(prev => ({ ...prev, codigo: `OD-${prefix}-${num}` }))
  }

  const save = async e => {
    e.preventDefault()
    if (!form.codigo) return toast.error('Debes generar o asignar un código')

    await supabase.from('productos').insert([{
      ...form,
      precio_venta: parseFloat(form.precio_venta) || 0,
      stock: parseInt(form.stock) || 0,
      categoria_id: form.categoria_id || null,
      impuesto_id: form.impuesto_id || null
    }])
    toast.success('Insumo guardado')
    setShowForm(false); load()
  }

  const handleScan = code => {
    setScanning(false)
    setQ(code)
    toast.success(`Filtrado por QR: ${code}`)
  }

  const filtered = list.filter(i => `${i.nombre} ${i.codigo}`.toLowerCase().includes(q.toLowerCase()))

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div><h1 className="text-xl font-bold text-slate-800">Almacén de Insumos Dentales</h1><p className="text-xs text-slate-400">Control de stock y códigos QR</p></div>
        <div className="flex gap-2">
          <button onClick={() => setScanning(true)} className="btn-secondary"><QrCode className="w-4 h-4 text-teal-600" /> Escanear</button>
          <button onClick={() => setShowForm(!showForm)} className={showForm ? 'btn-secondary' : 'btn-primary'}>
            {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Registrar Insumo</>}
          </button>
        </div>
      </div>

      {showForm && (
        <form onSubmit={save} className="card-box space-y-3 border-2 border-teal-200 bg-teal-50/20">
          <h3 className="font-bold text-sm text-teal-800">Registrar Insumo</h3>
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
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> Guardar</button>
            <button type="button" onClick={() => setShowForm(false)} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input placeholder="Buscar por nombre o código..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
      </div>

      <div className="card-box p-0 overflow-hidden border">
        <table className="w-full text-left text-xs">
          <thead className="bg-slate-50 border-b text-slate-500 font-bold uppercase">
            <tr>
              <th className="p-3.5">Código QR</th>
              <th className="p-3.5">Insumo</th>
              <th className="p-3.5">Stock</th>
              <th className="p-3.5">Precio</th>
              <th className="p-3.5 text-right">Etiqueta</th>
            </tr>
          </thead>
          <tbody className="divide-y">
            {filtered.map(i => (
              <tr key={i.id} className="hover:bg-slate-50">
                <td className="p-3.5 font-mono font-bold text-slate-800 flex items-center gap-1.5"><QrCode className="w-3.5 h-3.5 text-teal-600" /> {i.codigo}</td>
                <td className="p-3.5 font-bold text-slate-800">{i.nombre}</td>
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

      {scanning && <QRScanner onScan={handleScan} onClose={() => setScanning(false)} />}
    </div>
  )
}
