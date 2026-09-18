#!/bin/bash
set -e

echo "🔧 Reparando archivos y asegurando build para Vercel..."

mkdir -p src/{components/{Auth,Layout,Dashboard,Consultorio,Ventas,Inventario,Configuracion,UI},context,lib,utils}

# 1. Package.json verificado
cat > package.json << 'EOF'
{
  "name": "sistema-odontologico-pro",
  "private": true,
  "version": "3.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite --host 0.0.0.0",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "@supabase/supabase-js": "^2.48.1",
    "html5-qrcode": "^2.3.8",
    "lucide-react": "^0.475.0",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-hot-toast": "^2.5.1",
    "react-router-dom": "^6.28.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.4",
    "autoprefixer": "^10.4.20",
    "postcss": "^8.4.49",
    "tailwindcss": "^3.4.17",
    "vite": "^5.4.11"
  }
}
EOF

# 2. Historial Clínico (Corregido sin Tooth de lucide)
cat > src/components/Consultorio/Historial.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import PriceBox from '../UI/PriceBox'
import {
  Plus, FileText, CheckCircle2, Clock, Search,
  User, Activity, Sparkles
} from 'lucide-react'
import toast from 'react-hot-toast'

export default function Historial() {
  const [list, setList] = useState([])
  const [pacs, setPacs] = useState([])
  const [modal, setModal] = useState(false)
  const [q, setQ] = useState('')
  const [filtroPac, setFiltroPac] = useState('')
  const [form, setForm] = useState({
    paciente_id: '', diagnostico: '', procedimiento: '',
    dientes_tratados: '', monto_usd: 0, pagado: true, metodo_pago: 'efectivo_usd'
  })

  const load = async () => {
    const [h, p] = await Promise.all([
      supabase.from('historial_clinico').select('*, pacientes(nombres, apellidos, cedula)').order('created_at', { ascending: false }),
      supabase.from('pacientes').select('id, nombres, apellidos').eq('activo', true).order('nombres')
    ])
    setList(h.data || []); setPacs(p.data || [])
  }
  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    await supabase.from('historial_clinico').insert([{ ...form, monto_usd: parseFloat(form.monto_usd) || 0 }])
    toast.success('Procedimiento registrado en expediente')
    setModal(false); load()
  }

  const filtered = list.filter(h => {
    const matchQ = `${h.pacientes?.nombres} ${h.pacientes?.apellidos} ${h.procedimiento} ${h.diagnostico}`.toLowerCase().includes(q.toLowerCase())
    const matchPac = !filtroPac || h.paciente_id === filtroPac
    return matchQ && matchPac
  })

  const grouped = {}
  filtered.forEach(h => {
    const key = h.paciente_id
    if (!grouped[key]) grouped[key] = { paciente: h.pacientes, items: [] }
    grouped[key].items.push(h)
  })

  const metodoLabel = (m) => ({
    efectivo_usd: 'Efectivo $', efectivo_ves: 'Efectivo Bs.', efectivo_cop: 'Efectivo COP',
    transferencia: 'Transferencia', pago_movil: 'Pago Móvil', zelle: 'Zelle', tarjeta: 'Tarjeta', mixto: 'Mixto'
  }[m] || m)

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Historial Clínico</h1>
          <p className="text-xs text-slate-400">{list.length} procedimientos registrados</p>
        </div>
        <button onClick={() => setModal(true)} className="btn-primary"><Plus className="w-4 h-4" /> Registrar Procedimiento</button>
      </div>

      <div className="flex gap-3 flex-wrap">
        <div className="relative flex-1 min-w-[200px]">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input placeholder="Buscar procedimiento, diagnóstico..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
        </div>
        <select value={filtroPac} onChange={e => setFiltroPac(e.target.value)} className="input-field w-auto min-w-[180px]">
          <option value="">Todos los pacientes</option>
          {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
        </select>
      </div>

      <div className="space-y-6">
        {Object.values(grouped).length === 0 && (
          <div className="text-center py-16 text-slate-400">
            <FileText className="w-12 h-12 mx-auto mb-3 opacity-30" />
            <p className="font-medium">Sin registros clínicos</p>
          </div>
        )}

        {Object.values(grouped).map((g, gi) => (
          <div key={gi} className="card-box space-y-4">
            <div className="flex items-center gap-3 pb-3 border-b border-slate-100">
              <div className="w-10 h-10 rounded-xl bg-teal-50 text-teal-600 flex items-center justify-center font-bold text-sm">
                <User className="w-5 h-5" />
              </div>
              <div>
                <h3 className="font-bold text-sm text-slate-800">{g.paciente?.nombres} {g.paciente?.apellidos}</h3>
                <p className="text-[11px] text-slate-400">{g.items.length} procedimiento{g.items.length !== 1 ? 's' : ''}</p>
              </div>
            </div>

            <div className="relative pl-6 space-y-4">
              <div className="absolute left-[9px] top-2 bottom-2 w-0.5 bg-slate-200" />

              {g.items.map((h) => (
                <div key={h.id} className="relative">
                  <div className={`absolute -left-6 top-1 w-[18px] h-[18px] rounded-full border-2 flex items-center justify-center ${
                    h.pagado ? 'bg-emerald-500 border-emerald-300' : 'bg-amber-400 border-amber-200'
                  }`}>
                    {h.pagado ? <CheckCircle2 className="w-2.5 h-2.5 text-white" /> : <Clock className="w-2.5 h-2.5 text-white" />}
                  </div>

                  <div className="bg-slate-50 rounded-xl p-4 space-y-2">
                    <div className="flex justify-between items-start flex-wrap gap-2">
                      <div>
                        <p className="font-bold text-sm text-teal-700">{h.procedimiento}</p>
                        <p className="text-xs text-slate-500 mt-0.5">
                          {new Date(h.fecha).toLocaleDateString('es-VE', { day: 'numeric', month: 'short', year: 'numeric' })}
                        </p>
                      </div>
                      <PriceBox usd={h.monto_usd} showAll />
                    </div>

                    {h.diagnostico && (
                      <p className="text-xs text-slate-600 bg-white p-2 rounded-lg border border-slate-100">
                        <span className="font-bold text-slate-500">Dx:</span> {h.diagnostico}
                      </p>
                    )}

                    <div className="flex items-center gap-3 flex-wrap">
                      {h.dientes_tratados && (
                        <span className="badge bg-violet-50 text-violet-700 border border-violet-100">
                          🦷 Dientes: {h.dientes_tratados}
                        </span>
                      )}
                      <span className={`badge ${h.pagado ? 'bg-emerald-50 text-emerald-700 border-emerald-100' : 'bg-amber-50 text-amber-700 border-amber-100'}`}>
                        {h.pagado ? '✓ Cobrado' : '⏳ Pendiente'}
                      </span>
                      <span className="badge bg-slate-100 text-slate-500">{metodoLabel(h.metodo_pago)}</span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>

      {modal && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-4 shadow-2xl">
            <h2 className="font-bold text-base text-slate-800">Registrar Procedimiento</h2>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Paciente *</label>
              <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
                <option value="">Seleccionar paciente...</option>
                {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
              </select>
            </div>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Procedimiento Realizado *</label>
              <input required className="input-field" value={form.procedimiento} onChange={e => setForm({...form, procedimiento: e.target.value})} placeholder="Ej: Resina Fotocurada #14, Limpieza" />
            </div>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">🦷 Dientes Tratados</label>
              <input className="input-field" value={form.dientes_tratados} onChange={e => setForm({...form, dientes_tratados: e.target.value})} placeholder="Ej: 14, 15, 21, 36" />
            </div>

            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Diagnóstico</label>
              <textarea className="input-field" value={form.diagnostico} onChange={e => setForm({...form, diagnostico: e.target.value})} placeholder="Hallazgos clínicos, observaciones..." rows={2} />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Monto ($ USD)</label>
                <input type="number" step="0.01" min="0" className="input-field" value={form.monto_usd} onChange={e => setForm({...form, monto_usd: e.target.value})} />
              </div>
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Método de Pago</label>
                <select className="input-field" value={form.metodo_pago} onChange={e => setForm({...form, metodo_pago: e.target.value})}>
                  <option value="efectivo_usd">Efectivo $</option>
                  <option value="efectivo_ves">Efectivo Bs.</option>
                  <option value="efectivo_cop">Efectivo COP</option>
                  <option value="transferencia">Transferencia</option>
                  <option value="pago_movil">Pago Móvil</option>
                  <option value="zelle">Zelle</option>
                  <option value="tarjeta">Tarjeta</option>
                  <option value="mixto">Mixto</option>
                </select>
              </div>
            </div>

            <label className="flex items-center gap-2 cursor-pointer">
              <input type="checkbox" checked={form.pagado} onChange={e => setForm({...form, pagado: e.target.checked})} className="w-4 h-4 rounded text-teal-600" />
              <span className="text-sm font-medium text-slate-700">Marcar como cobrado</span>
            </label>

            <div className="flex justify-end gap-2 pt-2">
              <button type="button" onClick={() => setModal(false)} className="btn-secondary">Cancelar</button>
              <button type="submit" className="btn-primary">Guardar en Expediente</button>
            </div>
          </form>
        </div>
      )}
    </div>
  )
}
EOF

# 3. Inventario (Inputs arreglados con sus handlers)
cat > src/components/Inventario/Inventario.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import PriceBox from '../UI/PriceBox'
import QRScanner from '../UI/QRScanner'
import { Plus, AlertTriangle, QrCode, Printer, Search, RefreshCw } from 'lucide-react'
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
      precio_venta: parseFloat(form.precio_venta) || 0,
      stock: parseInt(form.stock) || 0,
      stock_minimo: parseInt(form.stock_minimo) || 0,
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

      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input placeholder="Buscar insumo por nombre, categoría o escanea su QR..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
      </div>

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

            <div>
              <label className="text-xs font-semibold block mb-1">Nombre del Insumo / Material</label>
              <input required placeholder="Ej: Resina 3M Z250" className="input-field" value={form.nombre} onChange={e => setForm({...form, nombre: e.target.value})} />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-xs font-semibold block mb-1">Stock Inicial</label>
                <input required type="number" min="0" placeholder="10" className="input-field" value={form.stock} onChange={e => setForm({...form, stock: e.target.value})} />
              </div>
              <div>
                <label className="text-xs font-semibold block mb-1">Precio Venta ($ USD)</label>
                <input required type="number" step="0.01" min="0" placeholder="25.00" className="input-field" value={form.precio_venta} onChange={e => setForm({...form, precio_venta: e.target.value})} />
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <button type="button" onClick={() => setModal(false)} className="btn-secondary">Cancelar</button>
              <button type="submit" className="btn-primary">Registrar en Almacén</button>
            </div>
          </form>
        </div>
      )}

      {activeLabel && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-3xl p-6 w-full max-w-sm shadow-2xl space-y-4 text-center">
            <h3 className="font-bold text-sm text-slate-400 border-b pb-2">ETIQUETA CLÍNICA DE CONTROL</h3>
            
            <div id="printable-area" className="p-4 border-2 border-dashed border-slate-300 rounded-2xl bg-white space-y-3 mx-auto">
              <p className="font-bold text-sm text-slate-800 uppercase tracking-tight truncate">{activeLabel.nombre}</p>
              <span className="badge bg-teal-50 text-teal-800 border border-teal-100 font-bold">{activeLabel.categorias?.nombre}</span>
              
              <div className="w-36 h-36 bg-slate-50 border rounded-xl flex items-center justify-center mx-auto shadow-inner overflow-hidden">
                <img 
                  src={`https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(activeLabel.codigo)}`} 
                  alt={activeLabel.codigo}
                  className="w-32 h-32 object-contain"
                />
              </div>

              <p className="font-mono font-bold text-xs text-slate-500 tracking-widest">{activeLabel.codigo}</p>
              <p className="text-teal-700 font-bold text-sm">${activeLabel.precio_venta} USD</p>
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
EOF

# 4. Pacientes (Navegación react-router arreglada)
cat > src/components/Consultorio/Pacientes.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../../lib/supabase'
import {
  Plus, Search, Trash2, Phone, Mail, AlertTriangle,
  User, Calendar, Heart, X, Edit3, Save
} from 'lucide-react'
import toast from 'react-hot-toast'

const calcularEdad = (fecha) => {
  if (!fecha) return null
  const hoy = new Date()
  const nac = new Date(fecha)
  let edad = hoy.getFullYear() - nac.getFullYear()
  if (hoy.getMonth() < nac.getMonth() || (hoy.getMonth() === nac.getMonth() && hoy.getDate() < nac.getDate())) edad--
  return edad
}

const getInicial = (n, a) => `${(n||'?')[0]}${(a||'?')[0]}`.toUpperCase()
const colores = ['bg-teal-500', 'bg-blue-500', 'bg-violet-500', 'bg-rose-500', 'bg-amber-500', 'bg-emerald-500', 'bg-indigo-500', 'bg-pink-500']
const getColor = (id) => colores[Math.abs(id?.charCodeAt(0) || 0) % colores.length]

export default function Pacientes() {
  const navigate = useNavigate()
  const [list, setList] = useState([])
  const [q, setQ] = useState('')
  const [modal, setModal] = useState(false)
  const [ficha, setFicha] = useState(null)
  const [tab, setTab] = useState('datos')
  const [editando, setEditando] = useState(false)
  const [form, setForm] = useState({ nombres: '', apellidos: '', cedula: '', telefono: '', email: '', fecha_nacimiento: '', alergias: '', antecedentes: '' })

  const load = async () => {
    const { data } = await supabase.from('pacientes').select('*').eq('activo', true).order('created_at', { ascending: false })
    setList(data || [])
  }
  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    if (editando && ficha) {
      await supabase.from('pacientes').update(form).eq('id', ficha.id)
      toast.success('Paciente actualizado')
      setFicha({ ...ficha, ...form })
    } else {
      await supabase.from('pacientes').insert([form])
      toast.success('Paciente registrado')
    }
    setModal(false); setEditando(false)
    setForm({ nombres: '', apellidos: '', cedula: '', telefono: '', email: '', fecha_nacimiento: '', alergias: '', antecedentes: '' })
    load()
  }

  const del = async (id) => {
    if (!confirm('¿Desactivar este paciente del sistema?')) return
    await supabase.from('pacientes').update({ activo: false }).eq('id', id)
    toast.success('Paciente desactivado'); setFicha(null); load()
  }

  const openEdit = (p) => {
    setForm({ nombres: p.nombres, apellidos: p.apellidos, cedula: p.cedula || '', telefono: p.telefono || '', email: p.email || '', fecha_nacimiento: p.fecha_nacimiento || '', alergias: p.alergias || '', antecedentes: p.antecedentes || '' })
    setFicha(p); setEditando(true); setModal(true); setTab('datos')
  }

  const filtered = list.filter(p =>
    `${p.nombres} ${p.apellidos} ${p.cedula} ${p.telefono}`.toLowerCase().includes(q.toLowerCase())
  )

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Pacientes</h1>
          <p className="text-xs text-slate-400">{list.length} expedientes activos</p>
        </div>
        <button onClick={() => { setForm({ nombres: '', apellidos: '', cedula: '', telefono: '', email: '', fecha_nacimiento: '', alergias: '', antecedentes: '' }); setEditando(false); setModal(true) }} className="btn-primary">
          <Plus className="w-4 h-4" /> Nuevo Paciente
        </button>
      </div>

      <div className="relative">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
        <input placeholder="Buscar por nombre, cédula o teléfono..." value={q} onChange={e => setQ(e.target.value)} className="input-field pl-10" />
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        {filtered.map(p => (
          <button key={p.id} onClick={() => { setFicha(p); setTab('datos'); setEditando(false) }}
            className="card-box text-left space-y-3 hover:shadow-md hover:border-teal-200 transition-all group cursor-pointer">
            <div className="flex items-center gap-3">
              <div className={`w-12 h-12 rounded-2xl ${getColor(p.id)} text-white flex items-center justify-center font-bold text-sm shadow-sm`}>
                {getInicial(p.nombres, p.apellidos)}
              </div>
              <div className="flex-1 min-w-0">
                <h3 className="font-bold text-sm text-slate-800 truncate group-hover:text-teal-700">{p.nombres} {p.apellidos}</h3>
                <p className="text-[11px] text-slate-400">{p.cedula || 'Sin cédula'} {calcularEdad(p.fecha_nacimiento) ? `• ${calcularEdad(p.fecha_nacimiento)} años` : ''}</p>
              </div>
            </div>

            <div className="space-y-1.5 text-xs text-slate-500">
              <p className="flex items-center gap-1.5 truncate"><Phone className="w-3 h-3 text-slate-300" /> {p.telefono || 'Sin teléfono'}</p>
              {p.email && <p className="flex items-center gap-1.5 truncate"><Mail className="w-3 h-3 text-slate-300" /> {p.email}</p>}
            </div>

            {p.alergias && (
              <div className="flex items-center gap-1.5 p-2 bg-rose-50 border border-rose-100 rounded-xl text-rose-600 text-[11px] font-semibold">
                <AlertTriangle className="w-3.5 h-3.5 shrink-0" /> {p.alergias}
              </div>
            )}
          </button>
        ))}
      </div>

      {ficha && !modal && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-3xl w-full max-w-lg shadow-2xl overflow-hidden animate-fadeIn">
            <div className="bg-gradient-to-r from-teal-600 to-teal-700 p-6 text-white relative">
              <button onClick={() => setFicha(null)} className="absolute top-4 right-4 p-1.5 bg-white/20 rounded-lg hover:bg-white/30">
                <X className="w-4 h-4" />
              </button>
              <div className="flex items-center gap-4">
                <div className={`w-16 h-16 rounded-2xl ${getColor(ficha.id)} text-white flex items-center justify-center font-bold text-xl shadow-lg border-2 border-white/30`}>
                  {getInicial(ficha.nombres, ficha.apellidos)}
                </div>
                <div>
                  <h2 className="text-lg font-bold">{ficha.nombres} {ficha.apellidos}</h2>
                  <p className="text-teal-100 text-sm">{ficha.cedula || 'Sin cédula'} {calcularEdad(ficha.fecha_nacimiento) ? `• ${calcularEdad(ficha.fecha_nacimiento)} años` : ''}</p>
                </div>
              </div>
            </div>

            <div className="flex border-b bg-slate-50">
              {[
                { id: 'datos', label: 'Datos', icon: User },
                { id: 'medico', label: 'Médico', icon: Heart },
                { id: 'acciones', label: 'Acciones', icon: Calendar }
              ].map(t => (
                <button key={t.id} onClick={() => setTab(t.id)}
                  className={`flex-1 py-3 text-xs font-semibold flex items-center justify-center gap-1.5 transition-all ${
                    tab === t.id ? 'text-teal-700 border-b-2 border-teal-600 bg-white' : 'text-slate-400 hover:text-slate-600'
                  }`}>
                  <t.icon className="w-3.5 h-3.5" /> {t.label}
                </button>
              ))}
            </div>

            <div className="p-6 space-y-4 max-h-[50vh] overflow-y-auto">
              {tab === 'datos' && (
                <div className="space-y-3">
                  <div className="p-2.5 bg-slate-50 rounded-xl text-xs"><p className="text-slate-400">Nombre</p><p className="font-bold text-sm text-slate-800">{ficha.nombres} {ficha.apellidos}</p></div>
                  <div className="p-2.5 bg-slate-50 rounded-xl text-xs"><p className="text-slate-400">Cédula</p><p className="font-bold text-sm text-slate-800">{ficha.cedula || 'No registrada'}</p></div>
                  <div className="p-2.5 bg-slate-50 rounded-xl text-xs"><p className="text-slate-400">Teléfono</p><p className="font-bold text-sm text-slate-800">{ficha.telefono || 'No registrado'}</p></div>
                  <div className="p-2.5 bg-slate-50 rounded-xl text-xs"><p className="text-slate-400">Email</p><p className="font-bold text-sm text-slate-800">{ficha.email || 'No registrado'}</p></div>
                </div>
              )}

              {tab === 'medico' && (
                <div className="space-y-4">
                  <div>
                    <p className="text-xs font-bold text-slate-500 uppercase mb-2 flex items-center gap-1.5"><AlertTriangle className="w-3.5 h-3.5 text-rose-500" /> Alergias</p>
                    {ficha.alergias ? (
                      <div className="p-3 bg-rose-50 border border-rose-200 rounded-xl text-rose-700 text-sm font-medium">{ficha.alergias}</div>
                    ) : (
                      <p className="text-sm text-slate-400 italic">Sin alergias registradas</p>
                    )}
                  </div>
                  <div>
                    <p className="text-xs font-bold text-slate-500 uppercase mb-2 flex items-center gap-1.5"><Heart className="w-3.5 h-3.5 text-red-500" /> Antecedentes Médicos</p>
                    {ficha.antecedentes ? (
                      <div className="p-3 bg-amber-50 border border-amber-200 rounded-xl text-amber-800 text-sm">{ficha.antecedentes}</div>
                    ) : (
                      <p className="text-sm text-slate-400 italic">Sin antecedentes registrados</p>
                    )}
                  </div>
                </div>
              )}

              {tab === 'acciones' && (
                <div className="space-y-3">
                  <button onClick={() => { setFicha(null); navigate('/citas') }} className="w-full btn-primary justify-center py-3">
                    <Calendar className="w-4 h-4" /> Agendar Cita
                  </button>
                  <button onClick={() => { setFicha(null); navigate('/historial') }} className="w-full btn-secondary justify-center py-3">
                    <Heart className="w-4 h-4" /> Ver Historial Clínico
                  </button>
                </div>
              )}
            </div>

            <div className="p-4 border-t bg-slate-50 flex gap-2">
              <button onClick={() => openEdit(ficha)} className="flex-1 btn-secondary justify-center">
                <Edit3 className="w-3.5 h-3.5" /> Editar
              </button>
              <button onClick={() => del(ficha.id)} className="btn-danger">
                <Trash2 className="w-3.5 h-3.5" /> Desactivar
              </button>
            </div>
          </div>
        </div>
      )}

      {modal && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4 z-50">
          <form onSubmit={save} className="bg-white p-6 rounded-3xl w-full max-w-md space-y-4 shadow-2xl">
            <h2 className="font-bold text-base text-slate-800">{editando ? 'Editar Paciente' : 'Nuevo Paciente'}</h2>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Nombres *</label>
                <input required value={form.nombres} onChange={e => setForm({...form, nombres: e.target.value})} className="input-field" placeholder="Ej: María" />
              </div>
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Apellidos *</label>
                <input required value={form.apellidos} onChange={e => setForm({...form, apellidos: e.target.value})} className="input-field" placeholder="Ej: González" />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Cédula</label>
                <input value={form.cedula} onChange={e => setForm({...form, cedula: e.target.value})} className="input-field" placeholder="V-12345678" />
              </div>
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Fecha Nacimiento</label>
                <input type="date" value={form.fecha_nacimiento} onChange={e => setForm({...form, fecha_nacimiento: e.target.value})} className="input-field" />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Teléfono</label>
                <input value={form.telefono} onChange={e => setForm({...form, telefono: e.target.value})} className="input-field" placeholder="0412-1234567" />
              </div>
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Email</label>
                <input type="email" value={form.email} onChange={e => setForm({...form, email: e.target.value})} className="input-field" placeholder="correo@email.com" />
              </div>
            </div>
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">⚠️ Alergias</label>
              <textarea value={form.alergias} onChange={e => setForm({...form, alergias: e.target.value})} className="input-field" rows={2} placeholder="Penicilina, Látex, Anestesia..." />
            </div>
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">🏥 Antecedentes Médicos</label>
              <textarea value={form.antecedentes} onChange={e => setForm({...form, antecedentes: e.target.value})} className="input-field" rows={2} placeholder="Diabetes, Hipertensión, Cardiopatía..." />
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <button type="button" onClick={() => { setModal(false); setEditando(false) }} className="btn-secondary">Cancelar</button>
              <button type="submit" className="btn-primary"><Save className="w-3.5 h-3.5" /> {editando ? 'Actualizar' : 'Registrar'}</button>
            </div>
          </form>
        </div>
      )}
    </div>
  )
}
EOF

# 5. Instalar y probar build en Codespace
echo "📦 Instalando y probando compilación de producción..."
npm install
npm run build

echo "✅ ¡COMPILACIÓN EXITOSA! Listo para desplegar en Vercel sin errores."
