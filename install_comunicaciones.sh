#!/bin/bash
set -e

echo "📲 Instalando Centro de Comunicaciones (WhatsApp, Llamadas y Correo)..."

mkdir -p src/components/Comunicacion

# 1. Utilidades y generador de mensajes inteligentes
cat > src/utils/comunicaciones.js << 'EOF'
import { fmt } from './helpers'

// Limpiar y formatear número telefónico
export function formatPhoneNumber(phone, defaultCountryCode = '58') {
  if (!phone) return ''
  let cleaned = String(phone).replace(/\D/g, '') // Solo números

  // Si empieza con 0 (ej: 04121234567 en Venezuela), quitar el 0 y añadir código de país
  if (cleaned.startsWith('0')) {
    cleaned = defaultCountryCode + cleaned.substring(1)
  }

  // Si no tiene código de país (menos de 11 dígitos), agregar el código por defecto
  if (cleaned.length === 10 && !cleaned.startsWith('58') && !cleaned.startsWith('57')) {
    cleaned = defaultCountryCode + cleaned
  }

  return cleaned
}

// 1. Plantilla Recordatorio de Cita
export function msgRecordatorioCita({ paciente, cita, clinica }) {
  const nombre = paciente?.nombres || 'Paciente'
  const fecha = cita?.fecha ? new Date(cita.fecha).toLocaleDateString('es-VE', { weekday: 'long', day: 'numeric', month: 'long' }) : 'próxima fecha'
  const hora = cita?.fecha ? new Date(cita.fecha).toLocaleTimeString('es-VE', { hour: '2-digit', minute: '2-digit' }) : ''
  const trat = cita?.tratamientos?.nombre || 'Consulta Odontológica'
  const clinicaNom = clinica?.nombre || 'Consultorio Odontológico'

  return `🦷 *${clinicaNom}*
¡Hola, *${nombre}*! 👋

Le recordamos su cita odontológica programada:
📅 *Fecha:* ${fecha}
⏰ *Hora:* ${hora}
👨‍⚕️ *Tratamiento:* ${trat}

📍 *Dirección:* ${clinica?.direccion || 'Consulte con nosotros'}

Por favor, responda *CONFIRMO* para asegurar su turno o avísenos si necesita reprogramar. ¡Le esperamos!`
}

// 2. Plantilla Cobro / Cuota de Tratamiento
export function msgCobroCuota({ paciente, plan, rates, clinica }) {
  const nombre = paciente?.nombres || 'Paciente'
  const titulo = plan?.titulo || 'Tratamiento Odontológico'
  const saldoUSD = Number(plan?.saldo_pendiente_usd || 0)
  const saldoVES = saldoUSD * (rates?.VES || 1)
  const saldoCOP = saldoUSD * (rates?.COP || 1)
  const clinicaNom = clinica?.nombre || 'Consultorio Odontológico'

  return `🦷 *${clinicaNom}*
Estimado/a *${nombre}*, le saludamos cordialmente.

Le recordamos el estado de su plan de tratamiento (*${titulo}*):
💵 *Saldo Pendiente:* ${fmt(saldoUSD, 'USD')}
🇻🇪 *En Bolívares (BCV):* ${fmt(saldoVES, 'VES')}
🇨🇴 *En Pesos (COP):* ${fmt(saldoCOP, 'COP')}

Agradecemos coordinar su abono o pago en su próxima consulta. ¡Muchas gracias por su confianza!`
}

// 3. Plantilla Cuidados Post-Operatorios
export function msgPostOperatorio({ paciente, procedimiento, clinica }) {
  const nombre = paciente?.nombres || 'Paciente'
  const proc = procedimiento || 'su procedimiento dental'
  const clinicaNom = clinica?.nombre || 'Consultorio Odontológico'

  return `🦷 *${clinicaNom}*
Hola *${nombre}*, esperamos que se encuentre muy bien tras *${proc}*.

⚠️ *Recomendaciones importantes para las próximas 48 horas:*
1. 🧊 Aplicar frío local intermitente durante el primer día.
2. 🚫 No realizar enjuagues bucales bruscos ni escupir con fuerza.
3. 🍲 Dieta blanda y fría/tibia (evitar alimentos duros o muy calientes).
4. 💊 Tomar puntualmente los medicamentos indicados por el doctor.
5. 🚭 Evitar fumar, esfuerzo físico y exposición al sol.

Ante cualquier molestia persistente, estamos a su disposición. ¡Pronta recuperación!`
}

// 4. Plantilla Control Preventivo / 6 Meses
export function msgControlSemestral({ paciente, clinica }) {
  const nombre = paciente?.nombres || 'Paciente'
  const clinicaNom = clinica?.nombre || 'Consultorio Odontológico'

  return `✨ *${clinicaNom}*
¡Hola, *${nombre}*! Esperamos que esté teniendo un excelente día.

Le recordamos que ya han transcurrido *6 meses* desde su último chequeo. Para mantener su salud bucal óptima y prevenir caries o sarro, le invitamos a agendar su *Limpieza Dental Preventiva*.

Escríbanos para coordinar el horario que más le convenga. ¡Cuidamos de su sonrisa! 🦷`
}

// Abrir enlace WhatsApp directo
export function openWhatsApp(phone, message) {
  const cleaned = formatPhoneNumber(phone)
  if (!cleaned) return false
  const url = `https://wa.me/${cleaned}?text=${encodeURIComponent(message)}`
  window.open(url, '_blank')
  return true
}

// Abrir llamada telefónica
export function makePhoneCall(phone) {
  if (!phone) return
  window.location.href = `tel:${phone.replace(/\s+/g, '')}`
}

// Abrir cliente de correo
export function sendEmail(email, subject, body) {
  if (!email) return
  window.location.href = `mailto:${email}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`
}
EOF

# 2. Centro de Comunicaciones Completo (Componente)
cat > src/components/Comunicacion/CentroComunicacion.jsx << 'EOF'
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
EOF

# 3. Integrar acciones rápidas de WhatsApp y llamadas en CITAS
cat > src/components/Consultorio/Citas.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { msgRecordatorioCita, openWhatsApp, makePhoneCall } from '../../utils/comunicaciones'
import {
  Plus, Check, X, Clock, Calendar as CalIcon, User,
  ChevronLeft, ChevronRight, Save, LayoutGrid, List, MessageCircle, Phone
} from 'lucide-react'
import toast from 'react-hot-toast'

const estados = {
  programada: { color: 'border-l-blue-500', bg: 'bg-blue-50', text: 'text-blue-700', label: 'Programada' },
  confirmada: { color: 'border-l-teal-500', bg: 'bg-teal-50', text: 'text-teal-700', label: 'Confirmada' },
  en_curso: { color: 'border-l-amber-500', bg: 'bg-amber-50', text: 'text-amber-700', label: 'En Curso' },
  completada: { color: 'border-l-emerald-500', bg: 'bg-emerald-50', text: 'text-emerald-700', label: 'Completada' },
  cancelada: { color: 'border-l-rose-500', bg: 'bg-rose-50', text: 'text-rose-700', label: 'Cancelada' }
}

const horasJornada = ['08:00', '09:00', '10:00', '11:00', '12:00', '14:00', '15:00', '16:00', '17:00', '18:00']

export default function Citas() {
  const [citas, setCitas] = useState([])
  const [pacs, setPacs] = useState([])
  const [trats, setTrats] = useState([])
  const [clinica, setClinica] = useState(null)
  const [showForm, setShowForm] = useState(false)
  const [vista, setVista] = useState('horas')
  const [filtro, setFiltro] = useState('todas')
  const [fecha, setFecha] = useState(new Date().toISOString().split('T')[0])
  const [form, setForm] = useState({ paciente_id: '', tratamiento_id: '', fecha: '', duracion_min: 30, notas: '' })

  const load = async () => {
    const [c, p, t, cl] = await Promise.all([
      supabase.from('citas').select('*, pacientes(nombres, apellidos, telefono, email), tratamientos(nombre, precio, duracion_min)').order('fecha'),
      supabase.from('pacientes').select('id, nombres, apellidos, cedula').eq('activo', true).order('nombres'),
      supabase.from('tratamientos').select('id, nombre, precio, duracion_min').eq('activo', true).order('nombre'),
      supabase.from('configuracion_consultorio').select('*').limit(1)
    ])
    setCitas(c.data || []); setPacs(p.data || []); setTrats(t.data || [])
    if (cl.data?.[0]) setClinica(cl.data[0])
  }
  useEffect(() => { load() }, [])

  const save = async e => {
    e.preventDefault()
    const t = trats.find(x => x.id === form.tratamiento_id)
    await supabase.from('citas').insert([{ ...form, tratamiento_id: form.tratamiento_id || null, duracion_min: t?.duracion_min || form.duracion_min }])
    toast.success('Cita agendada'); setShowForm(false); load()
  }

  const setStatus = async (id, est) => {
    await supabase.from('citas').update({ estado: est }).eq('id', id)
    toast.success(`Cita: ${estados[est]?.label}`)
    load()
  }

  const sendWhatsAppReminder = (cita) => {
    if (!cita.pacientes?.telefono) return toast.error('El paciente no tiene teléfono')
    const msg = msgRecordatorioCita({ paciente: cita.pacientes, cita, clinica })
    openWhatsApp(cita.pacientes.telefono, msg)
  }

  const hoy = new Date().toISOString().split('T')[0]
  const citasDia = citas.filter(c => {
    const f = c.fecha?.split('T')[0]
    return f === fecha && (filtro === 'todas' || c.estado === filtro)
  })

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Agenda Médica & Horarios</h1>
          <p className="text-xs text-slate-400">Control de citas con recordatorio WhatsApp directo</p>
        </div>
        <div className="flex gap-2">
          <div className="bg-white p-0.5 rounded-xl border border-slate-200 flex gap-0.5">
            <button onClick={() => setVista('horas')} className={`px-2.5 py-1 rounded-lg text-xs font-bold flex items-center gap-1 ${vista === 'horas' ? 'bg-teal-600 text-white' : 'text-slate-500'}`}>
              <LayoutGrid className="w-3.5 h-3.5" /> Horarios
            </button>
            <button onClick={() => setVista('lista')} className={`px-2.5 py-1 rounded-lg text-xs font-bold flex items-center gap-1 ${vista === 'lista' ? 'bg-teal-600 text-white' : 'text-slate-500'}`}>
              <List className="w-3.5 h-3.5" /> Lista
            </button>
          </div>
          <button onClick={() => { setShowForm(!showForm); setForm({ paciente_id: '', tratamiento_id: '', fecha: `${fecha}T09:00`, duracion_min: 30, notas: '' }) }} className={showForm ? 'btn-secondary' : 'btn-primary'}>
            {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Agendar Cita</>}
          </button>
        </div>
      </div>

      {showForm && (
        <form onSubmit={save} className="card-box space-y-3 border-2 border-teal-200 bg-teal-50/20">
          <h3 className="font-bold text-sm text-teal-800">Agendar Nueva Cita</h3>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Paciente *</label>
              <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
                <option value="">Seleccionar...</option>
                {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
              </select>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Tratamiento</label>
              <select className="input-field" value={form.tratamiento_id} onChange={e => { const t = trats.find(x => x.id === e.target.value); setForm({...form, tratamiento_id: e.target.value, duracion_min: t?.duracion_min || 30}) }}>
                <option value="">Consulta General</option>
                {trats.map(t => <option key={t.id} value={t.id}>{t.nombre} — ${t.precio}</option>)}
              </select>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Fecha y Hora *</label>
              <input required type="datetime-local" className="input-field" value={form.fecha} onChange={e => setForm({...form, fecha: e.target.value})} />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Notas</label>
              <input className="input-field" value={form.notas} onChange={e => setForm({...form, notas: e.target.value})} placeholder="Motivo..." />
            </div>
          </div>
          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> Confirmar Cita</button>
            <button type="button" onClick={() => setShowForm(false)} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      {/* Selector de Fecha */}
      <div className="card-box p-3 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="text-xs font-bold text-slate-500">Día:</span>
          <input type="date" value={fecha} onChange={e => setFecha(e.target.value)} className="input-field w-auto font-bold text-xs" />
        </div>
        <button onClick={() => setFecha(hoy)} className="btn-secondary text-xs py-1">Ir a Hoy</button>
      </div>

      {/* Vista de Horarios con botón WhatsApp */}
      {vista === 'horas' && (
        <div className="card-box p-4 space-y-2">
          <div className="divide-y divide-slate-100">
            {horasJornada.map(hora => {
              const cita = citasDia.find(c => {
                const hCita = new Date(c.fecha).toLocaleTimeString('es-VE', { hour: '2-digit', minute: '2-digit', hour12: false })
                return hCita.startsWith(hora.split(':')[0])
              })

              return (
                <div key={hora} className="py-2.5 flex items-center justify-between gap-3 text-xs">
                  <div className="w-16 font-mono font-bold text-slate-500">{hora}</div>

                  {cita ? (
                    <div className="flex-1 p-2.5 bg-teal-50/80 border border-teal-200 rounded-xl flex items-center justify-between flex-wrap gap-2">
                      <div>
                        <p className="font-bold text-slate-800">{cita.pacientes?.nombres} {cita.pacientes?.apellidos}</p>
                        <p className="text-[11px] text-teal-700">{cita.tratamientos?.nombre || 'Consulta General'}</p>
                      </div>
                      <div className="flex items-center gap-1.5">
                        <button
                          onClick={() => sendWhatsAppReminder(cita)}
                          title="Enviar Recordatorio por WhatsApp"
                          className="p-1.5 bg-emerald-100 hover:bg-emerald-200 text-emerald-800 rounded-lg flex items-center gap-1 font-bold text-[11px]"
                        >
                          <MessageCircle className="w-3.5 h-3.5 text-emerald-600" /> WhatsApp
                        </button>
                        <span className={`badge ${estados[cita.estado]?.bg} ${estados[cita.estado]?.text}`}>
                          {estados[cita.estado]?.label}
                        </span>
                        {cita.estado === 'programada' && (
                          <button onClick={() => setStatus(cita.id, 'confirmada')} className="p-1 text-teal-600 hover:bg-teal-100 rounded">
                            <Check className="w-3.5 h-3.5" />
                          </button>
                        )}
                      </div>
                    </div>
                  ) : (
                    <div className="flex-1 p-2 border border-dashed border-slate-200 rounded-xl flex items-center justify-between text-slate-400">
                      <span className="italic text-[11px]">Disponible</span>
                      <button onClick={() => { setForm({ paciente_id: '', tratamiento_id: '', fecha: `${fecha}T${hora}`, duracion_min: 30, notas: '' }); setShowForm(true) }} className="text-[11px] font-bold text-teal-600 hover:underline">
                        + Agendar
                      </button>
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        </div>
      )}

      {/* Vista Lista */}
      {vista === 'lista' && (
        <div className="space-y-2">
          {citasDia.map(c => (
            <div key={c.id} className={`card-box p-4 border-l-4 ${estados[c.estado]?.color}`}>
              <div className="flex items-center justify-between flex-wrap gap-3">
                <div>
                  <h3 className="font-bold text-sm text-slate-800">{c.pacientes?.nombres} {c.pacientes?.apellidos}</h3>
                  <p className="text-xs text-teal-700">{c.tratamientos?.nombre || 'Consulta General'} • {new Date(c.fecha).toLocaleTimeString('es-VE')}</p>
                </div>
                <div className="flex items-center gap-2">
                  <button onClick={() => sendWhatsAppReminder(c)} className="btn-secondary text-xs py-1 px-2.5 text-emerald-700 bg-emerald-50">
                    <MessageCircle className="w-3.5 h-3.5 text-emerald-600" /> Recordar WhatsApp
                  </button>
                  <span className={`badge ${estados[c.estado]?.bg} ${estados[c.estado]?.text}`}>{estados[c.estado]?.label}</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
EOF

# 4. Actualizar SHELL con la ruta de Comunicaciones
cat > src/components/Layout/Shell.jsx << 'EOF'
import { useState } from 'react'
import { Outlet, NavLink } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import { useCurrency } from '../../context/CurrencyContext'
import {
  Users, Calendar, FileText, Activity, ShoppingBag, Package,
  Settings, LogOut, RefreshCw, LayoutDashboard, Receipt, BarChart3,
  CreditCard, UserCheck, Menu, X, Wallet, FlaskConical, MessageSquare
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
            <NavLink to="/reportes" onClick={close} className={nav}><BarChart3 className="w-4 h-4" /> Reportes & Finanzas</NavLink>
            <NavLink to="/caja" onClick={close} className={nav}><Wallet className="w-4 h-4" /> Caja Chica & Cierre</NavLink>
            <NavLink to="/comunicacion" onClick={close} className={nav}><MessageSquare className="w-4 h-4 text-emerald-600" /> WhatsApp & Contacto</NavLink>

            <p className="text-[10px] uppercase font-bold text-slate-400 px-3 pt-3 py-1">Consultorio</p>
            <NavLink to="/pacientes" onClick={close} className={nav}><Users className="w-4 h-4" /> Pacientes 360°</NavLink>
            <NavLink to="/citas" onClick={close} className={nav}><Calendar className="w-4 h-4" /> Agenda & Horarios</NavLink>
            <NavLink to="/historial" onClick={close} className={nav}><FileText className="w-4 h-4" /> Historial & Cobros</NavLink>
            <NavLink to="/planes" onClick={close} className={nav}><CreditCard className="w-4 h-4" /> Planes & Cuotas</NavLink>
            <NavLink to="/tratamientos" onClick={close} className={nav}><Activity className="w-4 h-4" /> Tratamientos</NavLink>
            <NavLink to="/doctores" onClick={close} className={nav}><UserCheck className="w-4 h-4" /> Doctores</NavLink>
            <NavLink to="/laboratorio" onClick={close} className={nav}><FlaskConical className="w-4 h-4" /> Laboratorio Dental</NavLink>

            <p className="text-[10px] uppercase font-bold text-slate-400 px-3 pt-3 py-1">Insumos & Ventas</p>
            <NavLink to="/pos" onClick={close} className={nav}><ShoppingBag className="w-4 h-4" /> Punto de Venta (POS)</NavLink>
            <NavLink to="/ventas" onClick={close} className={nav}><Receipt className="w-4 h-4" /> Historial de Ventas</NavLink>
            <NavLink to="/inventario" onClick={close} className={nav}><Package className="w-4 h-4" /> Almacén & Kardex</NavLink>
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

# 5. Actualizar App.jsx con la ruta /comunicacion
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
import CentroComunicacion from './components/Comunicacion/CentroComunicacion'
import Pacientes from './components/Consultorio/Pacientes'
import Citas from './components/Consultorio/Citas'
import Historial from './components/Consultorio/Historial'
import Tratamientos from './components/Consultorio/Tratamientos'
import PlanesTratamiento from './components/Planes/PlanesTratamiento'
import Doctores from './components/Doctores/Doctores'
import Laboratorio from './components/Laboratorio/Laboratorio'
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
            <Route path="comunicacion" element={<CentroComunicacion />} />
            <Route path="pacientes" element={<Pacientes />} />
            <Route path="citas" element={<Citas />} />
            <Route path="historial" element={<Historial />} />
            <Route path="planes" element={<PlanesTratamiento />} />
            <Route path="tratamientos" element={<Tratamientos />} />
            <Route path="doctores" element={<Doctores />} />
            <Route path="laboratorio" element={<Laboratorio />} />
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

# 6. Compilar y verificar producción
echo "📦 Compilando módulo de Comunicaciones..."
npm run build

echo "🎉 ¡CENTRO DE COMUNICACIONES (WhatsApp, Llamadas y Correo) INSTALADO!"
