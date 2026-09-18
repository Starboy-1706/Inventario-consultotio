import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import PriceBox from '../UI/PriceBox'
import QRScanner from '../UI/QRScanner'
import { Plus, Package, AlertTriangle, QrCode, Printer, Search, RefreshCw, Layers } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Inventario() {
  const [list, setList] = useState([])
  const [cats, setCats] = useState([])
  const [taxes, setTaxes] = useState([])
  const [modal, setModal] = useState(false)
  const [activeLabel, setActiveLabel] = useState(null)
  const [scanning, setScanning] = useState(false)
  const [q, setQ] = useState('')

  const [form, setForm] = useState({
    nombre: '',
    codigo: '',
    stock: 10,
    stock_minimo: 5,
    precio_compra: 0,
    precio_venta: '',
    categoria_id: '',
    impuesto_id: '',
    es_vendible: true,
    es_insumo_consultorio: false
  })

  const load = async () => {
    const [p, c, t] = await Promise.all([
      supabase.from('productos').select('*, categorias(nombre, tipo, color), impuestos(nombre, porcentaje)').eq('activo', true).order('nombre'),
      supabase.from('categorias').select('*'),
      supabase.from('impuestos').select('*')
    ])
    setList(p.data || []); setCats(c.data || []); setTaxes(t.data || [])
  }

  useEffect(() => { load() }, [])

  // Generar código estructurado automático estilo inventario parroquial
  const generateUniqueCode = () => {
    const cat = cats.find(x => x.id === form.categoria_id)
    const prefix = cat ? cat.nombre.slice(0, 3).toUpperCase() : 'GEN'
    const num = Math.floor(1000 + Math.random() * 9000)
    setForm(prev => ({ ...prev, codigo: `OD-${prefix}-${num}` }))
  }

  const save = async (e) => {
    e.preventDefault()
    if (!form.codigo) return toast.error('Debes generar o ingresar un código para el artículo')

    const payload = {
      ...form,
      categoria_id: form.categoria_id || null,
      impuesto_id: form.impuesto_id || null
    }

    const { error } = await supabase.from('productos').insert([payload])
    if (error) return toast.error('Error al registrar insumo')

    toast.success('Insumo guardado en almacén')
    setModal(false)
    setForm({ nombre: '', codigo: '', stock: 10, stock_minimo: 5, precio_compra: 0, precio_venta: '', categoria_id: '', impuesto_id: '', es_vendible: true, es_insumo_consultorio: false })
    load()
  }

  const handleQRScan = (code) => {
    setScanning(false)
    setQ(code)
    toast.success(`Filtrado por código QR: ${code}`)
  }

  const filtered = list.filter(i => 
    `${i.nombre} ${i.codigo} ${i.categorias?.nombre}`.toLowerCase().includes(q.toLowerCase())
  )

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Almacén de Materiales e Insumos</h1>
          <p className="text-xs text-slate-400">Códigos únicos por artículo, generación de etiquetas QR y trazabilidad</p>
        </div>
        <div className="flex gap-2">
          <button onClick={() => setScanning(true)} className="btn-secondary"><QrCode className="w-4 h-4 text-teal-600" /> Escanear QR</button>
          <button onClick={() => setModal(true)} className="btn-primary"><Plus className="w-4 h-4" /> Registrar Insumo</button>
        </div>
      </div>

      {/* Barra de búsqueda */}
      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input placeholder="Buscar insumo por nombre, categoría o escanea su QR..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
      </div>

      {/* Tabla con códigos e impresión de etiquetas QR */}
      <div className="card-box p-0 overflow-hidden border">
        <table className="w-full text-left text-xs">
          <thead className="bg-slate-50 border-b border-slate-100 text-slate-500 font-bold uppercase">
            <tr>
              <th className="p-3.5">Código QR</th>
              <th className="p-3.5">Nombre del Insumo</th>
              <th className="p-3.5">Categoría</th>
              <th className="p-3.5">Stock</th>
              <th className="p-3.5">Precios (Multimoneda)</th>
              <th className="p-3.5 text-right">Etiqueta</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {filtered.map(i => (
              <tr key={i.id} className="hover:bg-slate-50/50">
                <td className="p-3.5 font-mono font-bold text-slate-800 flex items-center gap-2">
                  <QrCode className="w-3.5 h-3.5 text-teal-600" /> {i.codigo}
                </td>
                <td className="p-3.5">
                  <p className="font-bold text-slate-800">{i.nombre}</p>
                  <span className="text-[10px] text-slate-400">UM: {i.unidad || 'Unidad'}</span>
                </td>
                <td className="p-3.5">
                  <span className="badge" style={{ backgroundColor: `${i.categorias?.color}15`, color: i.categorias?.color }}>
                    {i.categorias?.nombre || 'General'}
                  </span>
                </td>
                <td className="p-3.5 font-bold">
                  <span className={`inline-flex items-center gap-1 ${i.stock <= i.stock_minimo ? 'text-rose-600' : 'text-slate-700'}`}>
                    {i.stock} {i.stock <= i.stock_minimo && <AlertTriangle className="w-3.5 h-3.5 text-rose-500 animate-pulse" />}
                  </span>
                </td>
                <td className="p-3.5"><PriceBox usd={i.precio_venta} showAll /></td>
                <td className="p-3.5 text-right">
                  <button onClick={() => setActiveLabel(i)} className="p-1.5 bg-teal-50 text-teal-700 hover:bg-teal-100 rounded-lg inline-flex items-center gap-1 text-[11px] font-bold">
                    <Printer className="w-3.5 h-3.5" /> Etiqueta QR
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Modal de Registro */}
      {modal && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-4 shadow-2xl">
            <div className="flex justify-between items-center border-b pb-2">
              <h2 className="font-bold text-base text-slate-800">Registrar Nuevo Insumo</h2>
              <button type="button" onClick={() => setModal(false)} className="text-slate-400 hover:text-slate-600">✕</button>
            </div>

            <div>
              <label className="text-xs font-semibold block mb-1">Categoría</label>
              <select required className="input-field" value={form.categoria_id} onChange={e => setForm({...form, categoria_id: e.target.value})}>
                <option value="">Seleccione Categoría</option>
                {cats.map(c => <option key={c.id} value={c.id}>{c.nombre} ({c.tipo})</option>)}
              </select>
            </div>

            <div>
              <label className="text-xs font-semibold block mb-1">Código del Artículo</label>
              <div className="flex gap-2">
                <input required placeholder="Código Único" className="input-field font-mono" value={form.codigo} onChange={e => setForm({...form, codigo: e.target.value.toUpperCase()})} />
                <button type="button" onClick={generateUniqueCode} disabled={!form.categoria_id} className="btn-secondary text-xs shrink-0 py-2.5">
                  <RefreshCw className="w-3.5 h-3.5" /> Auto-Generar
                </button>
              </div>
            </div>

            <input required placeholder="Nombre del Insumo / Material" className="input-field" value={form.nombre} />

            <div className="grid grid-cols-2 gap-3">
              <input required type="number" placeholder="Stock Inicial" className="input-field" value={form.stock} />
              <input required type="number" step="0.01" placeholder="Precio Venta ($ USD)" className="input-field" value={form.precio_venta} />
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <button type="button" onClick={() => setModal(false)} className="btn-secondary">Cancelar</button>
              <button type="submit" className="btn-primary">Registrar en Almacén</button>
            </div>
          </form>
        </div>
      )}

      {/* Modal de Etiqueta QR Imprimible Estilo Original */}
      {activeLabel && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-3xl p-6 w-full max-w-sm shadow-2xl space-y-4 text-center">
            <h3 className="font-bold text-sm text-slate-400 border-b pb-2">ETIQUETA CLÍNICA DE CONTROL</h3>
            
            {/* Contenedor imprimible */}
            <div id="printable-area" className="p-4 border-2 border-dashed border-slate-300 rounded-2xl bg-white space-y-3 mx-auto">
              <p className="font-bold text-sm text-slate-800 uppercase tracking-tight truncate">{activeLabel.nombre}</p>
              <span className="badge bg-teal-50 text-teal-800 border border-teal-100 font-bold">{activeLabel.categorias?.nombre}</span>
              
              {/* Código QR Generado con API pública ultra-estable */}
              <div className="w-36 h-36 bg-slate-50 border rounded-xl flex items-center justify-center mx-auto shadow-inner overflow-hidden">
                <img 
                  src={`https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(activeLabel.codigo)}`} 
                  alt={activeLabel.codigo}
                  className="w-32 h-32 object-contain"
                />
              </div>

              <p className="font-mono font-bold text-xs text-slate-500 tracking-widest">{activeLabel.codigo}</p>

              <div className="text-center pt-2 border-t border-slate-100 text-xs font-bold space-y-0.5">
                <p className="text-teal-700">USD: {activeLabel.precio_venta}</p>
              </div>
            </div>

            <div className="flex gap-2">
              <button onClick={() => setActiveLabel(null)} className="w-1/2 btn-secondary justify-center">Cerrar</button>
              <button onClick={() => window.print()} className="w-1/2 btn-primary justify-center"><Printer className="w-4 h-4" /> Imprimir</button>
            </div>
          </div>
        </div>
      )}

      {scanning && <QRScanner onScan={handleQRScan} onClose={() => setScanning(false)} />}
    </div>
  )
}
