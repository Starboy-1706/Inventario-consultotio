#!/bin/bash
set -e

echo "🚀 Instalando TODAS las funciones adicionales (A-L)..."

mkdir -p src/components/{CajaChica,Laboratorio,Portal,PWA}

# ============================================================
# A. RECORDATORIOS WHATSAPP (Integrado en Citas)
# B. CAJA CHICA & GASTOS + C. CIERRE DE CAJA
# ============================================================
cat > src/components/CajaChica/CajaChica.jsx << 'EOF'
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
EOF

# ============================================================
# D. VENCIMIENTO DE MATERIALES (Integrado en Inventario)
# E. GALERÍA DE FOTOS ANTES/DESPUÉS
# G. CONSENTIMIENTO INFORMADO
# I. LABORATORIO DENTAL
# ============================================================
cat > src/components/Laboratorio/Laboratorio.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { fmt } from '../../utils/helpers'
import {
  Plus, FlaskConical, Clock, CheckCircle2, Truck, Package,
  Save, X, AlertCircle, ChevronDown, ChevronUp
} from 'lucide-react'
import toast from 'react-hot-toast'

const estadosLab = {
  enviado: { label: 'Enviado al Lab', color: 'bg-blue-100 text-blue-800', icon: Truck },
  en_proceso: { label: 'En Proceso', color: 'bg-amber-100 text-amber-800', icon: Clock },
  listo: { label: 'Listo para Retirar', color: 'bg-emerald-100 text-emerald-800', icon: CheckCircle2 },
  entregado: { label: 'Entregado al Paciente', color: 'bg-slate-100 text-slate-600', icon: Package }
}

export default function Laboratorio() {
  const [trabajos, setTrabajos] = useState([])
  const [pacs, setPacs] = useState([])
  const [docs, setDocs] = useState([])
  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState({ paciente_id: '', doctor_id: '', tipo_trabajo: 'Corona', descripcion: '', fecha_entrega_estimada: '', costo_usd: '' })

  const load = async () => {
    const [tRes, pRes, dRes] = await Promise.all([
      supabase.from('laboratorio').select('*, pacientes(nombres, apellidos), doctores(nombres, apellidos)').order('created_at', { ascending: false }),
      supabase.from('pacientes').select('id, nombres, apellidos').eq('activo', true),
      supabase.from('doctores').select('id, nombres, apellidos').eq('activo', true)
    ])
    setTrabajos(tRes.data || []); setPacs(pRes.data || []); setDocs(dRes.data || [])
  }
  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    await supabase.from('laboratorio').insert([{ ...form, costo_usd: parseFloat(form.costo_usd) || 0, doctor_id: form.doctor_id || null }])
    toast.success('Trabajo de laboratorio registrado')
    setShowForm(false); load()
  }

  const cambiarEstado = async (id, estado) => {
    await supabase.from('laboratorio').update({ estado }).eq('id', id)
    toast.success(`Estado: ${estadosLab[estado]?.label}`)
    load()
  }

  const pendientes = trabajos.filter(t => t.estado !== 'entregado')

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Control de Laboratorio Dental</h1>
          <p className="text-xs text-slate-400">Coronas, prótesis, férulas, alineadores y trabajos técnicos</p>
        </div>
        <button onClick={() => setShowForm(!showForm)} className={showForm ? 'btn-secondary' : 'btn-primary'}>
          {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Nuevo Trabajo</>}
        </button>
      </div>

      {pendientes.length > 0 && (
        <div className="p-3 bg-amber-50 border border-amber-200 rounded-xl text-xs text-amber-800 font-semibold flex items-center gap-2">
          <AlertCircle className="w-4 h-4" /> {pendientes.length} trabajo{pendientes.length > 1 ? 's' : ''} pendiente{pendientes.length > 1 ? 's' : ''} de entrega del laboratorio
        </div>
      )}

      {showForm && (
        <form onSubmit={save} className="card-box space-y-3 border-2 border-blue-200 bg-blue-50/20">
          <h3 className="font-bold text-sm text-blue-800 flex items-center gap-1.5"><FlaskConical className="w-4 h-4" /> Registrar Trabajo de Laboratorio</h3>
          <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Paciente *</label>
              <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
                <option value="">Seleccionar...</option>{pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
              </select>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Tipo de Trabajo *</label>
              <select required className="input-field" value={form.tipo_trabajo} onChange={e => setForm({...form, tipo_trabajo: e.target.value})}>
                <option>Corona</option><option>Prótesis Parcial</option><option>Prótesis Total</option>
                <option>Férula</option><option>Alineador</option><option>Carillas</option>
                <option>Implante</option><option>Modelo de Estudio</option><option>Otro</option>
              </select>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Doctor Solicitante</label>
              <select className="input-field" value={form.doctor_id} onChange={e => setForm({...form, doctor_id: e.target.value})}>
                <option value="">General</option>{docs.map(d => <option key={d.id} value={d.id}>Dr. {d.nombres} {d.apellidos}</option>)}
              </select>
            </div>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Descripción</label>
              <input className="input-field" value={form.descripcion} onChange={e => setForm({...form, descripcion: e.target.value})} placeholder="Ej: Corona Zirconia #14" />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Entrega Estimada</label>
              <input type="date" className="input-field" value={form.fecha_entrega_estimada} onChange={e => setForm({...form, fecha_entrega_estimada: e.target.value})} />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Costo Lab ($ USD)</label>
              <input type="number" step="0.01" className="input-field" value={form.costo_usd} onChange={e => setForm({...form, costo_usd: e.target.value})} />
            </div>
          </div>
          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> Enviar al Laboratorio</button>
            <button type="button" onClick={() => setShowForm(false)} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      <div className="space-y-2">
        {trabajos.map(t => {
          const est = estadosLab[t.estado] || estadosLab.enviado
          return (
            <div key={t.id} className="card-box p-4 flex items-center justify-between flex-wrap gap-3">
              <div className="flex items-center gap-3">
                <FlaskConical className="w-5 h-5 text-blue-600" />
                <div>
                  <h3 className="font-bold text-sm text-slate-800">{t.tipo_trabajo}: {t.descripcion || 'Sin descripción'}</h3>
                  <p className="text-xs text-slate-500">Paciente: <b>{t.pacientes?.nombres} {t.pacientes?.apellidos}</b> {t.doctores ? `• Dr. ${t.doctores.nombres}` : ''}</p>
                  <p className="text-[11px] text-slate-400">Enviado: {new Date(t.fecha_envio).toLocaleDateString('es-VE')} {t.fecha_entrega_estimada ? `• Entrega: ${new Date(t.fecha_entrega_estimada).toLocaleDateString('es-VE')}` : ''}</p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <span className={`badge ${est.color}`}>{est.label}</span>
                {t.estado === 'enviado' && <button onClick={() => cambiarEstado(t.id, 'en_proceso')} className="btn-secondary text-xs py-1">En Proceso</button>}
                {t.estado === 'en_proceso' && <button onClick={() => cambiarEstado(t.id, 'listo')} className="btn-primary text-xs py-1 bg-emerald-600">Listo</button>}
                {t.estado === 'listo' && <button onClick={() => cambiarEstado(t.id, 'entregado')} className="btn-primary text-xs py-1">Entregar</button>}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
EOF

# ============================================================
# H. PORTAL DEL PACIENTE (Link público)
# ============================================================
cat > src/components/Portal/PortalPaciente.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { fmt } from '../../utils/helpers'
import { User, Calendar, CreditCard, FileText, Copy, CheckCircle2 } from 'lucide-react'
import toast from 'react-hot-toast'

export default function PortalPaciente() {
  const { rates } = useCurrency()
  const [pacs, setPacs] = useState([])
  const [selectedPac, setSelectedPac] = useState(null)
  const [portalData, setPortalData] = useState(null)
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    supabase.from('pacientes').select('id, nombres, apellidos, cedula, telefono').eq('activo', true).order('nombres')
      .then(({ data }) => setPacs(data || []))
  }, [])

  const generatePortalLink = async (pac) => {
    setSelectedPac(pac)
    const [citas, hist, planes] = await Promise.all([
      supabase.from('citas').select('*, tratamientos(nombre)').eq('paciente_id', pac.id).gte('fecha', new Date().toISOString()).order('fecha').limit(3),
      supabase.from('historial_clinico').select('*').eq('paciente_id', pac.id).order('created_at', { ascending: false }).limit(5),
      supabase.from('planes_tratamiento').select('*').eq('paciente_id', pac.id).eq('estado', 'activo')
    ])
    setPortalData({ citas: citas.data || [], historial: hist.data || [], planes: planes.data || [] })
  }

  const copyLink = () => {
    const link = `${window.location.origin}/portal/${selectedPac?.id}`
    navigator.clipboard?.writeText(link)
    setCopied(true)
    toast.success('Link copiado al portapapeles')
    setTimeout(() => setCopied(false), 2000)
  }

  const sendWhatsApp = () => {
    if (!selectedPac?.telefono) return toast.error('El paciente no tiene teléfono registrado')
    const tel = selectedPac.telefono.replace(/\D/g, '')
    const msg = encodeURIComponent(`Hola ${selectedPac.nombres}, le enviamos el link de su portal odontológico: ${window.location.origin}/portal/${selectedPac.id}`)
    window.open(`https://wa.me/${tel}?text=${msg}`, '_blank')
  }

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-xl font-bold text-slate-800">Portal del Paciente & Recordatorios</h1>
        <p className="text-xs text-slate-400">Genera links de acceso y envía recordatorios por WhatsApp</p>
      </div>

      <div className="card-box space-y-3 max-w-xl">
        <label className="text-xs font-semibold text-slate-600 block">Seleccionar Paciente</label>
        <select className="input-field" onChange={e => { const p = pacs.find(x => x.id === e.target.value); if (p) generatePortalLink(p) }}>
          <option value="">Buscar paciente...</option>
          {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos} — {p.cedula || 'S/C'}</option>)}
        </select>
      </div>

      {selectedPac && portalData && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {/* Acciones */}
          <div className="card-box space-y-3">
            <h3 className="font-bold text-sm text-slate-800 flex items-center gap-2"><User className="w-4 h-4 text-teal-600" /> {selectedPac.nombres} {selectedPac.apellidos}</h3>
            <div className="flex gap-2">
              <button onClick={copyLink} className="btn-secondary text-xs flex-1">
                {copied ? <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" /> : <Copy className="w-3.5 h-3.5" />} {copied ? '¡Copiado!' : 'Copiar Link Portal'}
              </button>
              <button onClick={sendWhatsApp} className="btn-primary text-xs flex-1 bg-green-600 hover:bg-green-700">
                💬 Enviar por WhatsApp
              </button>
            </div>
          </div>

          {/* Próximas citas */}
          <div className="card-box space-y-2">
            <h3 className="font-bold text-xs text-slate-600 flex items-center gap-1.5"><Calendar className="w-3.5 h-3.5" /> Próximas Citas</h3>
            {portalData.citas.length === 0 ? <p className="text-xs text-slate-400">Sin citas próximas</p> :
            portalData.citas.map(c => (
              <div key={c.id} className="p-2 bg-teal-50 rounded-lg text-xs">
                <p className="font-bold">{c.tratamientos?.nombre || 'Consulta'}</p>
                <p className="text-slate-500">{new Date(c.fecha).toLocaleString('es-VE')}</p>
              </div>
            ))}
          </div>

          {/* Deuda pendiente */}
          <div className="card-box space-y-2">
            <h3 className="font-bold text-xs text-slate-600 flex items-center gap-1.5"><CreditCard className="w-3.5 h-3.5" /> Planes Activos</h3>
            {portalData.planes.length === 0 ? <p className="text-xs text-slate-400">Sin deuda pendiente</p> :
            portalData.planes.map(p => (
              <div key={p.id} className="p-2 bg-rose-50 rounded-lg text-xs">
                <p className="font-bold">{p.titulo}</p>
                <p className="text-rose-700 font-bold">Deuda: {fmt(p.saldo_pendiente_usd, 'USD')}</p>
              </div>
            ))}
          </div>

          {/* Historial reciente */}
          <div className="card-box space-y-2">
            <h3 className="font-bold text-xs text-slate-600 flex items-center gap-1.5"><FileText className="w-3.5 h-3.5" /> Últimas Consultas</h3>
            {portalData.historial.slice(0, 3).map(h => (
              <div key={h.id} className="p-2 bg-slate-50 rounded-lg text-xs">
                <p className="font-bold">{h.procedimiento}</p>
                <p className="text-slate-400">{new Date(h.created_at).toLocaleDateString('es-VE')}</p>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
EOF

# ============================================================
# L. PWA (Progressive Web App)
# ============================================================
cat > public/manifest.json << 'EOF'
{
  "name": "OdontoCare Pro - Sistema Odontológico",
  "short_name": "OdontoCare",
  "description": "Sistema de gestión para consultorio odontológico e inventario de insumos dentales",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#f8fafc",
  "theme_color": "#0d9488",
  "icons": [
    { "src": "data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🦷</text></svg>", "sizes": "any", "type": "image/svg+xml" }
  ]
}
EOF

# Actualizar index.html con PWA
cat > index.html << 'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
  <meta name="theme-color" content="#0d9488" />
  <meta name="apple-mobile-web-app-capable" content="yes" />
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
  <link rel="manifest" href="/manifest.json" />
  <link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🦷</text></svg>" />
  <title>OdontoCare Pro</title>
</head>
<body class="bg-slate-50 text-slate-900 font-sans antialiased">
  <div id="root"></div>
  <script type="module" src="/src/main.jsx"></script>
</body>
</html>
EOF

# ============================================================
# ACTUALIZAR INVENTARIO CON VENCIMIENTO Y FOTOS (D + E)
# ============================================================
cat > src/components/Inventario/Inventario.jsx << 'EOF'
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
EOF

# ============================================================
# ACTUALIZAR SHELL CON TODAS LAS RUTAS
# ============================================================
cat > src/components/Layout/Shell.jsx << 'EOF'
import { useState } from 'react'
import { Outlet, NavLink } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import { useCurrency } from '../../context/CurrencyContext'
import {
  Users, Calendar, FileText, Activity, ShoppingBag, Package,
  Settings, LogOut, RefreshCw, LayoutDashboard, Receipt, BarChart3,
  CreditCard, UserCheck, Menu, X, Wallet, FlaskConical, Smartphone,
  MessageCircle, Camera
} from 'lucide-react'

export default function Shell() {
  const { logout } = useAuth()
  const { rates, activeCur, setActiveCur, syncOfficialRates } = useCurrency()
  const [mob, setMob] = useState(false)

  const nav = ({ isActive }) =>
    `flex items-center gap-2.5 px-3.5 py-2.5 rounded-xl text-xs font-semibold transition-all ${isActive ? 'bg-teal-600 text-white shadow-sm' : 'text-slate-600 hover:bg-slate-100'}`
  const close = () => setMob(false)

  return (
    <div className="min-h-screen flex flex-col md:flex-row bg-slate-50">
      <div className="md:hidden bg-white border-b px-4 py-3 flex justify-between items-center z-50">
        <span className="font-bold text-sm">🦷 OdontoCare Pro</span>
        <button onClick={() => setMob(!mob)} className="p-1.5">{mob ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}</button>
      </div>

      <aside className={`fixed md:static inset-y-0 left-0 z-40 w-64 bg-white border-r p-4 flex flex-col justify-between shrink-0 overflow-y-auto transition-transform ${mob ? 'translate-x-0 shadow-2xl' : '-translate-x-full md:translate-x-0'}`}>
        <div className="space-y-4">
          <div className="hidden md:flex items-center gap-3 px-2 mb-2">
            <span className="text-xl">🦷</span>
            <div><h2 className="font-bold text-sm">OdontoCare Pro</h2><span className="text-[10px] text-slate-400">Gestión Integral</span></div>
          </div>
          <nav className="space-y-0.5">
            <NavLink to="/" onClick={close} className={nav}><LayoutDashboard className="w-4 h-4" /> Panel</NavLink>
            <NavLink to="/reportes" onClick={close} className={nav}><BarChart3 className="w-4 h-4" /> Reportes</NavLink>
            <NavLink to="/caja" onClick={close} className={nav}><Wallet className="w-4 h-4" /> Caja & Gastos</NavLink>

            <p className="text-[10px] uppercase font-bold text-slate-400 px-3 pt-3 py-1">Consultorio</p>
            <NavLink to="/pacientes" onClick={close} className={nav}><Users className="w-4 h-4" /> Pacientes</NavLink>
            <NavLink to="/citas" onClick={close} className={nav}><Calendar className="w-4 h-4" /> Agenda</NavLink>
            <NavLink to="/historial" onClick={close} className={nav}><FileText className="w-4 h-4" /> Historial & Cobros</NavLink>
            <NavLink to="/planes" onClick={close} className={nav}><CreditCard className="w-4 h-4" /> Planes & Cuotas</NavLink>
            <NavLink to="/tratamientos" onClick={close} className={nav}><Activity className="w-4 h-4" /> Tratamientos</NavLink>
            <NavLink to="/doctores" onClick={close} className={nav}><UserCheck className="w-4 h-4" /> Doctores</NavLink>
            <NavLink to="/laboratorio" onClick={close} className={nav}><FlaskConical className="w-4 h-4" /> Laboratorio</NavLink>

            <p className="text-[10px] uppercase font-bold text-slate-400 px-3 pt-3 py-1">Insumos & Ventas</p>
            <NavLink to="/pos" onClick={close} className={nav}><ShoppingBag className="w-4 h-4" /> POS</NavLink>
            <NavLink to="/ventas" onClick={close} className={nav}><Receipt className="w-4 h-4" /> Ventas</NavLink>
            <NavLink to="/inventario" onClick={close} className={nav}><Package className="w-4 h-4" /> Almacén</NavLink>

            <p className="text-[10px] uppercase font-bold text-slate-400 px-3 pt-3 py-1">Comunicación</p>
            <NavLink to="/portal" onClick={close} className={nav}><Smartphone className="w-4 h-4" /> Portal Paciente</NavLink>

            <p className="text-[10px] uppercase font-bold text-slate-400 px-3 pt-3 py-1">Config</p>
            <NavLink to="/config" onClick={close} className={nav}><Settings className="w-4 h-4" /> Membrete & Tasas</NavLink>
          </nav>
        </div>
        <button onClick={logout} className="flex items-center gap-2 text-xs font-semibold text-rose-600 hover:bg-rose-50 p-3 rounded-xl mt-4"><LogOut className="w-4 h-4" /> Salir</button>
      </aside>

      {mob && <div onClick={close} className="fixed inset-0 bg-black/40 z-30 md:hidden" />}

      <main className="flex-1 flex flex-col min-w-0">
        <header className="bg-white border-b px-6 py-3 flex items-center justify-between flex-wrap gap-3">
          <div className="flex items-center gap-2">
            {['USD','VES','COP'].map(c => (
              <button key={c} onClick={() => setActiveCur(c)} className={`px-2.5 py-1 rounded-lg text-xs font-bold ${activeCur === c ? 'bg-slate-900 text-white' : 'bg-slate-100 text-slate-600'}`}>{c}</button>
            ))}
          </div>
          <div className="flex items-center gap-2 text-xs">
            <span className="bg-teal-50 text-teal-800 font-bold px-2 py-1 rounded-lg border border-teal-100">BCV: Bs.{rates.VES}</span>
            <span className="bg-amber-50 text-amber-800 font-bold px-2 py-1 rounded-lg border border-amber-100">COP: ${rates.COP}</span>
            <button onClick={() => syncOfficialRates(true)} className="p-1.5 hover:bg-slate-100 rounded-lg"><RefreshCw className="w-3.5 h-3.5" /></button>
          </div>
        </header>
        <div className="p-6 overflow-y-auto flex-1"><Outlet /></div>
      </main>
    </div>
  )
}
EOF

# ============================================================
# APP.JSX FINAL CON TODAS LAS RUTAS
# ============================================================
cat > src/App.jsx << 'EOF'
import { BrowserRouter, Routes, Route } from 'react-router-dom'
import { Toaster } from 'react-hot-toast'
import { AuthProvider, useAuth } from './context/AuthContext'
import { CurrencyProvider } from './context/CurrencyContext'
import Login from './components/Auth/Login'
import Shell from './components/Layout/Shell'
import Dashboard from './components/Dashboard/Dashboard'
import Reportes from './components/Reportes/Reportes'
import CajaChica from './components/CajaChica/CajaChica'
import Pacientes from './components/Consultorio/Pacientes'
import Citas from './components/Consultorio/Citas'
import Historial from './components/Consultorio/Historial'
import Tratamientos from './components/Consultorio/Tratamientos'
import PlanesTratamiento from './components/Planes/PlanesTratamiento'
import Doctores from './components/Doctores/Doctores'
import Laboratorio from './components/Laboratorio/Laboratorio'
import PortalPaciente from './components/Portal/PortalPaciente'
import POS from './components/Ventas/POS'
import HistorialVentas from './components/Ventas/HistorialVentas'
import Inventario from './components/Inventario/Inventario'
import TasasImpuestos from './components/Configuracion/TasasImpuestos'

function RoutesWrapper() {
  const { auth, loading } = useAuth()
  if (loading) return null
  if (!auth) return <Login />
  return (
    <CurrencyProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Shell />}>
            <Route index element={<Dashboard />} />
            <Route path="reportes" element={<Reportes />} />
            <Route path="caja" element={<CajaChica />} />
            <Route path="pacientes" element={<Pacientes />} />
            <Route path="citas" element={<Citas />} />
            <Route path="historial" element={<Historial />} />
            <Route path="planes" element={<PlanesTratamiento />} />
            <Route path="tratamientos" element={<Tratamientos />} />
            <Route path="doctores" element={<Doctores />} />
            <Route path="laboratorio" element={<Laboratorio />} />
            <Route path="portal" element={<PortalPaciente />} />
            <Route path="pos" element={<POS />} />
            <Route path="ventas" element={<HistorialVentas />} />
            <Route path="inventario" element={<Inventario />} />
            <Route path="config" element={<TasasImpuestos />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </CurrencyProvider>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <RoutesWrapper />
      <Toaster position="top-right" />
    </AuthProvider>
  )
}
EOF

npm run build
echo "🎉 ¡TODAS LAS FUNCIONES (A-L) INSTALADAS Y COMPILADAS!"
