import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import {
  formatPhoneNumber, msgRecordatorioCita, msgCobroCuota,
  msgPostOperatorio, msgControlSemestral, openWhatsApp,
  makePhoneCall, sendEmail
} from '../../utils/comunicaciones'
import {
  MessageSquare, Phone, Mail, Send, Calendar,
  CreditCard, Stethoscope, Sparkles, Copy, CheckCircle2, User, Building2
} from 'lucide-react'
import toast from 'react-hot-toast'

export default function CentroComunicacion() {
  const { rates } = useCurrency()
  const [pacs, setPacs] = useState([])
  const [citas, setCitas] = useState([])
  const [planes, setPlanes] = useState([])
  const [clinica, setClinica] = useState(null)

  const [selectedPacId, setSelectedPacId] = useState('')
  const [tipoPlantilla, setTipoPlantilla] = useState('cita') // cita | cobro | post | control | libre
  const [mensajePersonalizado, setMensajePersonalizado] = useState('')
  const [selectedCitaId, setSelectedCitaId] = useState('')
  const [selectedPlanId, setSelectedPlanId] = useState('')
  const [customProc, setCustomProc] = useState('Extracción Dental')
  const [copied, setCopied] = useState(false)

  const loadData = async () => {
    const [pRes, cRes, plRes, clRes] = await Promise.all([
      supabase.from('pacientes').select('*').eq('activo', true).order('nombres'),
      supabase.from('citas').select('*, pacientes(nombres, apellidos), tratamientos(nombre)').order('fecha', { ascending: false }).limit(30),
      supabase.from('planes_tratamiento').select('*, pacientes(nombres, apellidos)').eq('estado', 'activo'),
      supabase.from('configuracion_consultorio').select('*').limit(1)
    ])

    setPacs(pRes.data || [])
    setCitas(cRes.data || [])
    setPlanes(plRes.data || [])
    if (clRes.data?.[0]) setClinica(clRes.data[0])
  }

  useEffect(() => { loadData() }, [])

  const pacienteActual = pacs.find(p => p.id === selectedPacId)

  // Generar mensaje según la plantilla elegida
  useEffect(() => {
    if (!pacienteActual && tipoPlantilla !== 'libre') {
      setMensajePersonalizado('')
      return
    }

    let texto = ''
    if (tipoPlantilla === 'cita') {
      const cita = citas.find(c => c.id === selectedCitaId) || citas.find(c => c.paciente_id === selectedPacId)
      texto = msgRecordatorioCita({ paciente: pacienteActual, cita, clinica })
    } else if (tipoPlantilla === 'cobro') {
      const plan = planes.find(p => p.id === selectedPlanId) || planes.find(p => p.paciente_id === selectedPacId)
      texto = msgCobroCuota({ paciente: pacienteActual, plan, rates, clinica })
    } else if (tipoPlantilla === 'post') {
      texto = msgPostOperatorio({ paciente: pacienteActual, procedimiento: customProc, clinica })
    } else if (tipoPlantilla === 'control') {
      texto = msgControlSemestral({ paciente: pacienteActual, clinica })
    }

    if (tipoPlantilla !== 'libre') {
      setMensajePersonalizado(texto)
    }
  }, [selectedPacId, tipoPlantilla, selectedCitaId, selectedPlanId, customProc, rates, clinica])

  const handleSendWhatsApp = () => {
    if (!pacienteActual?.telefono) return toast.error('El paciente no tiene teléfono registrado')
    if (!mensajePersonalizado) return toast.error('El mensaje está vacío')
    openWhatsApp(pacienteActual.telefono, mensajePersonalizado)
    toast.success('Abriendo WhatsApp...')
  }

  const handleCall = () => {
    if (!pacienteActual?.telefono) return toast.error('El paciente no tiene teléfono registrado')
    makePhoneCall(pacienteActual.telefono)
  }

  const handleEmail = () => {
    if (!pacienteActual?.email) return toast.error('El paciente no tiene correo registrado')
    sendEmail(pacienteActual.email, `${clinica?.nombre || 'Consultorio Odontológico'} - Información Importante`, mensajePersonalizado)
  }

  const handleCopy = () => {
    navigator.clipboard?.writeText(mensajePersonalizado)
    setCopied(true)
    toast.success('Mensaje copiado al portapapeles')
    setTimeout(() => setCopied(false), 2000)
  }

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-xl font-bold text-slate-800 flex items-center gap-2">
          <MessageSquare className="w-5 h-5 text-teal-600" /> Centro de Comunicaciones & WhatsApp
        </h1>
        <p className="text-xs text-slate-400">Envío de recordatorios de citas, avisos de cobro por WhatsApp, llamadas y correos con 1 clic</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Panel de Configuración del Mensaje */}
        <div className="lg:col-span-2 card-box space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {/* Selector de Paciente */}
            <div>
              <label className="text-xs font-semibold text-slate-600 block mb-1">1. Seleccionar Paciente *</label>
              <select className="input-field font-medium text-xs" value={selectedPacId} onChange={e => setSelectedPacId(e.target.value)}>
                <option value="">Seleccione un paciente de la lista...</option>
                {pacs.map(p => (
                  <option key={p.id} value={p.id}>{p.nombres} {p.apellidos} {p.telefono ? `(${p.telefono})` : '(Sin tel)'}</option>
                ))}
              </select>
            </div>

            {/* Selector de Tipo de Mensaje */}
            <div>
              <label className="text-xs font-semibold text-slate-600 block mb-1">2. Tipo de Comunicación</label>
              <select className="input-field text-xs font-bold text-teal-800" value={tipoPlantilla} onChange={e => setTipoPlantilla(e.target.value)}>
                <option value="cita">📅 Recordatorio de Cita Próxima</option>
                <option value="cobro">💵 Aviso de Cuota / Saldo Pendiente</option>
                <option value="post">🩹 Indicaciones Post-Operatorias</option>
                <option value="control">✨ Recordatorio de Control Semestral</option>
                <option value="libre">✍️ Mensaje Libre / Personalizado</option>
              </select>
            </div>
          </div>

          {/* Opciones contextuales */}
          {tipoPlantilla === 'cita' && (
            <div>
              <label className="text-xs font-semibold text-slate-600 block mb-1">Cita Específica (Opcional)</label>
              <select className="input-field text-xs" value={selectedCitaId} onChange={e => setSelectedCitaId(e.target.value)}>
                <option value="">Cita más reciente del paciente</option>
                {citas.filter(c => !selectedPacId || c.paciente_id === selectedPacId).map(c => (
                  <option key={c.id} value={c.id}>
                    {new Date(c.fecha).toLocaleString('es-VE')} — {c.tratamientos?.nombre || 'Consulta'}
                  </option>
                ))}
              </select>
            </div>
          )}

          {tipoPlantilla === 'cobro' && (
            <div>
              <label className="text-xs font-semibold text-slate-600 block mb-1">Plan de Tratamiento / Cuotas</label>
              <select className="input-field text-xs" value={selectedPlanId} onChange={e => setSelectedPlanId(e.target.value)}>
                <option value="">Plan activo del paciente</option>
                {planes.filter(p => !selectedPacId || p.paciente_id === selectedPacId).map(p => (
                  <option key={p.id} value={p.id}>
                    {p.titulo} — Saldo: ${p.saldo_pendiente_usd} USD
                  </option>
                ))}
              </select>
            </div>
          )}

          {tipoPlantilla === 'post' && (
            <div>
              <label className="text-xs font-semibold text-slate-600 block mb-1">Procedimiento Realizado</label>
              <input className="input-field text-xs" value={customProc} onChange={e => setCustomProc(e.target.value)} placeholder="Ej: Extracción Quirúrgica del #18" />
            </div>
          )}

          {/* Editor del Mensaje */}
          <div>
            <div className="flex justify-between items-center mb-1">
              <label className="text-xs font-semibold text-slate-600">3. Vista Previa / Editar Mensaje</label>
              <button onClick={handleCopy} className="text-[11px] text-teal-600 hover:underline flex items-center gap-1 font-bold">
                {copied ? <CheckCircle2 className="w-3 h-3 text-emerald-600" /> : <Copy className="w-3 h-3" />} {copied ? 'Copiado' : 'Copiar Texto'}
              </button>
            </div>
            <textarea
              rows={8}
              className="input-field font-mono text-xs leading-relaxed bg-slate-50 border-slate-200"
              value={mensajePersonalizado}
              onChange={e => setMensajePersonalizado(e.target.value)}
              placeholder="Seleccione un paciente y plantilla para previsualizar el mensaje..."
            />
          </div>

          {/* Botones de Envío Omnicanal */}
          <div className="flex flex-wrap gap-2 pt-2 border-t">
            <button
              onClick={handleSendWhatsApp}
              disabled={!pacienteActual?.telefono}
              className="btn-primary bg-emerald-600 hover:bg-emerald-700 text-xs flex-1 py-2.5 justify-center shadow-lg shadow-emerald-600/10"
            >
              💬 Enviar por WhatsApp
            </button>
            <button
              onClick={handleCall}
              disabled={!pacienteActual?.telefono}
              className="btn-secondary text-xs py-2.5 px-4"
            >
              <Phone className="w-3.5 h-3.5 text-teal-600" /> Llamar
            </button>
            <button
              onClick={handleEmail}
              disabled={!pacienteActual?.email}
              className="btn-secondary text-xs py-2.5 px-4"
            >
              <Mail className="w-3.5 h-3.5 text-blue-600" /> Correo
            </button>
          </div>
        </div>

        {/* Ficha Rápida del Destinatario */}
        <div className="card-box space-y-4 h-fit">
          <h3 className="font-bold text-sm text-slate-800 border-b pb-2 flex items-center gap-2">
            <User className="w-4 h-4 text-teal-600" /> Datos del Paciente
          </h3>

          {pacienteActual ? (
            <div className="space-y-3 text-xs">
              <div>
                <p className="text-slate-400 font-semibold">Nombre Completo</p>
                <p className="font-bold text-sm text-slate-800">{pacienteActual.nombres} {pacienteActual.apellidos}</p>
              </div>
              <div>
                <p className="text-slate-400 font-semibold">Teléfono / WhatsApp</p>
                <p className="font-mono font-bold text-slate-700">{pacienteActual.telefono || '⚠️ Sin teléfono registrado'}</p>
              </div>
              <div>
                <p className="text-slate-400 font-semibold">Correo Electrónico</p>
                <p className="text-slate-700">{pacienteActual.email || '—'}</p>
              </div>
              <div>
                <p className="text-slate-400 font-semibold">Cédula / Documento</p>
                <p className="text-slate-700">{pacienteActual.cedula || '—'}</p>
              </div>
            </div>
          ) : (
            <p className="text-xs text-slate-400 italic py-6 text-center">Selecciona un paciente para ver sus canales de contacto.</p>
          )}

          <div className="p-3 bg-teal-50 border border-teal-100 rounded-xl text-[11px] text-teal-800 space-y-1">
            <p className="font-bold flex items-center gap-1"><Sparkles className="w-3.5 h-3.5" /> Consejo Dental</p>
            <p>Enviar recordatorios 24h antes por WhatsApp reduce el ausentismo de citas hasta en un 40%.</p>
          </div>
        </div>
      </div>
    </div>
  )
}
