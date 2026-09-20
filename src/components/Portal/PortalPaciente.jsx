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
