#!/bin/bash
set -e

echo "🆓 Configurando soporte para APIs 100% Gratuitas (Meta Cloud API, Green-API, Resend)..."

# 1. Actualizar endpoint backend para soportar Meta Cloud API y Green-API
cat > api/send-auto-message.js << 'EOF'
import { createClient } from '@supabase/supabase-js'

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método no permitido' })

  const { canal, destinatario, mensaje, asunto, html } = req.body

  const supabaseUrl = process.env.VITE_SUPABASE_URL || process.env.SUPABASE_URL
  const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY || process.env.SUPABASE_ANON_KEY
  const supabase = createClient(supabaseUrl, supabaseKey)

  const { data: cfgList } = await supabase.from('configuracion_notificaciones').select('*').limit(1)
  const cfg = cfgList?.[0]

  if (!cfg) return res.status(400).json({ error: 'No hay configuración guardada' })

  try {
    // ==========================================
    // CANAL WHATSAPP (APIs GRATUITAS)
    // ==========================================
    if (canal === 'whatsapp') {
      let phone = String(destinatario).replace(/\D/g, '')
      if (phone.startsWith('0')) phone = '58' + phone.substring(1)
      if (phone.length === 10) phone = '58' + phone

      let ok = false
      let respData = null

      // 1. META CLOUD API (1.000 GRATIS/MES)
      if (cfg.whatsapp_provider === 'meta') {
        if (!cfg.whatsapp_token || !cfg.whatsapp_instance_id) {
          return res.status(400).json({ error: 'Falta Phone Number ID o Token de Meta' })
        }

        const r = await fetch(`https://graph.facebook.com/v19.0/${cfg.whatsapp_instance_id}/messages`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${cfg.whatsapp_token}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            messaging_product: 'whatsapp',
            to: phone,
            type: 'text',
            text: { body: mensaje }
          })
        })
        respData = await r.json()
        ok = r.ok
      }

      // 2. GREEN-API (PLAN GRATIS QR)
      else if (cfg.whatsapp_provider === 'green_api') {
        if (!cfg.whatsapp_instance_id || !cfg.whatsapp_token) {
          return res.status(400).json({ error: 'Falta Instance ID o API Token de Green-API' })
        }

        const r = await fetch(`https://api.green-api.com/waInstance${cfg.whatsapp_instance_id}/sendMessage/${cfg.whatsapp_token}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            chatId: `${phone}@c.us`,
            message: mensaje
          })
        })
        respData = await r.json()
        ok = r.ok
      }

      // 3. ULTRAMSG / WASSENGER
      else if (cfg.whatsapp_provider === 'ultramsg') {
        const r = await fetch(`https://api.ultramsg.com/${cfg.whatsapp_instance_id}/messages/chat`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ token: cfg.whatsapp_token, to: phone, body: mensaje })
        })
        respData = await r.json()
        ok = r.ok
      }

      // Guardar en bitácora
      await supabase.from('logs_notificaciones').insert({
        canal: 'whatsapp',
        destinatario: phone,
        tipo_mensaje: 'Envío Directo',
        contenido: mensaje,
        estado: ok ? 'enviado' : 'fallido',
        error_detalle: ok ? null : JSON.stringify(respData)
      })

      return res.status(200).json({ success: ok, response: respData })
    }

    // ==========================================
    // CANAL CORREO (RESEND 3.000 GRATIS/MES)
    // ==========================================
    if (canal === 'email') {
      if (!cfg.resend_api_key) return res.status(400).json({ error: 'Falta la API Key de Resend' })

      const r = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${cfg.resend_api_key}`
        },
        body: JSON.stringify({
          from: cfg.email_from || 'OdontoCare <onboarding@resend.dev>',
          to: [destinatario],
          subject: asunto || 'Consulta Odontológica',
          html: html || `<p>${mensaje}</p>`
        })
      })

      const data = await r.json()
      await supabase.from('logs_notificaciones').insert({
        canal: 'email',
        destinatario,
        tipo_mensaje: 'Envío Directo',
        contenido: mensaje,
        estado: r.ok ? 'enviado' : 'fallido'
      })

      return res.status(200).json({ success: r.ok, response: data })
    }

    return res.status(400).json({ error: 'Canal inválido' })
  } catch (err) {
    return res.status(500).json({ error: err.message })
  }
}
EOF

# 2. Actualizar Cron Job para usar las APIs gratuitas
cat > api/cron-reminders.js << 'EOF'
import { createClient } from '@supabase/supabase-js'

export default async function handler(req, res) {
  const supabaseUrl = process.env.VITE_SUPABASE_URL || process.env.SUPABASE_URL
  const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY || process.env.SUPABASE_ANON_KEY
  const supabase = createClient(supabaseUrl, supabaseKey)

  try {
    const { data: cfgList } = await supabase.from('configuracion_notificaciones').select('*').limit(1)
    const cfg = cfgList?.[0]

    if (!cfg || !cfg.auto_cron_activo) {
      return res.status(200).json({ message: 'Cron inactivo' })
    }

    const manana = new Date()
    manana.setDate(manana.getDate() + 1)
    const mananaStr = manana.toISOString().split('T')[0]

    const { data: citas } = await supabase
      .from('citas')
      .select('*, pacientes(nombres, apellidos, telefono, email), tratamientos(nombre)')
      .gte('fecha', `${mananaStr}T00:00:00`)
      .lte('fecha', `${mananaStr}T23:59:59`)
      .in('estado', ['programada', 'confirmada'])

    const { data: clinicaList } = await supabase.from('configuracion_consultorio').select('*').limit(1)
    const clinica = clinicaList?.[0] || { nombre: 'Consultorio Odontológico' }

    for (const cita of (citas || [])) {
      const pac = cita.pacientes
      if (!pac) continue

      const fechaFmt = new Date(cita.fecha).toLocaleDateString('es-VE', { weekday: 'long', day: 'numeric', month: 'long' })
      const horaFmt = new Date(cita.fecha).toLocaleTimeString('es-VE', { hour: '2-digit', minute: '2-digit' })
      const trat = cita.tratamientos?.nombre || 'Consulta'

      const msg = `🦷 *${clinica.nombre}*\nHola *${pac.nombres}*, le recordamos su cita para mañana:\n📅 *Fecha:* ${fechaFmt}\n⏰ *Hora:* ${horaFmt}\n👨‍⚕️ *Tratamiento:* ${trat}\n\nPor favor, responda *CONFIRMO* para asegurar su lugar.`

      // WhatsApp
      if (pac.telefono && cfg.whatsapp_token) {
        let phone = String(pac.telefono).replace(/\D/g, '')
        if (phone.startsWith('0')) phone = '58' + phone.substring(1)
        if (phone.length === 10) phone = '58' + phone

        try {
          if (cfg.whatsapp_provider === 'meta' && cfg.whatsapp_instance_id) {
            await fetch(`https://graph.facebook.com/v19.0/${cfg.whatsapp_instance_id}/messages`, {
              method: 'POST',
              headers: { 'Authorization': `Bearer ${cfg.whatsapp_token}`, 'Content-Type': 'application/json' },
              body: JSON.stringify({ messaging_product: 'whatsapp', to: phone, type: 'text', text: { body: msg } })
            })
          } else if (cfg.whatsapp_provider === 'green_api' && cfg.whatsapp_instance_id) {
            await fetch(`https://api.green-api.com/waInstance${cfg.whatsapp_instance_id}/sendMessage/${cfg.whatsapp_token}`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ chatId: `${phone}@c.us`, message: msg })
            })
          }
        } catch (e) {}
      }

      // Email
      if (pac.email && cfg.resend_api_key) {
        try {
          await fetch('https://api.resend.com/emails', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${cfg.resend_api_key}` },
            body: JSON.stringify({
              from: cfg.email_from || 'OdontoCare <onboarding@resend.dev>',
              to: [pac.email],
              subject: `Recordatorio de Cita Odontológica`,
              html: `<p>Estimado/a <b>${pac.nombres}</b>,</p><p>Le recordamos su cita para mañana <b>${fechaFmt}</b> a las <b>${horaFmt}</b>.</p>`
            })
          })
        } catch (e) {}
      }
    }

    return res.status(200).json({ success: true, citasProcesadas: (citas || []).length })
  } catch (err) {
    return res.status(500).json({ error: err.message })
  }
}
EOF

# 3. Interfaz con selector de proveedores gratuitos y guía paso a paso
cat > src/components/Comunicacion/CentroComunicacion.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import {
  msgRecordatorioCita, msgCobroCuota, msgPostOperatorio,
  msgControlSemestral, openWhatsApp
} from '../../utils/comunicaciones'
import {
  MessageSquare, Send, Calendar, CreditCard, Bot, Zap,
  Save, History, Settings, Play, Gift, ShieldCheck
} from 'lucide-react'
import toast from 'react-hot-toast'

export default function CentroComunicacion() {
  const { rates } = useCurrency()
  const [tab, setTab] = useState('mensajes')
  const [pacs, setPacs] = useState([])
  const [citas, setCitas] = useState([])
  const [planes, setPlanes] = useState([])
  const [clinica, setClinica] = useState(null)
  const [logs, setLogs] = useState([])

  const [selectedPacId, setSelectedPacId] = useState('')
  const [tipoPlantilla, setTipoPlantilla] = useState('cita')
  const [mensajePersonalizado, setMensajePersonalizado] = useState('')
  const [sendingAuto, setSendingAuto] = useState(false)

  const [config, setConfig] = useState({
    whatsapp_provider: 'green_api',
    whatsapp_instance_id: '',
    whatsapp_token: '',
    resend_api_key: '',
    email_from: 'OdontoCare <onboarding@resend.dev>',
    auto_cron_activo: true
  })

  const loadData = async () => {
    const [pRes, cRes, plRes, clRes, cfgRes, logRes] = await Promise.all([
      supabase.from('pacientes').select('*').eq('activo', true).order('nombres'),
      supabase.from('citas').select('*, pacientes(nombres, apellidos), tratamientos(nombre)').order('fecha', { ascending: false }).limit(30),
      supabase.from('planes_tratamiento').select('*, pacientes(nombres, apellidos)').eq('estado', 'activo'),
      supabase.from('configuracion_consultorio').select('*').limit(1),
      supabase.from('configuracion_notificaciones').select('*').limit(1),
      supabase.from('logs_notificaciones').select('*').order('created_at', { ascending: false }).limit(30)
    ])

    setPacs(pRes.data || [])
    setCitas(cRes.data || [])
    setPlanes(plRes.data || [])
    if (clRes.data?.[0]) setClinica(clRes.data[0])
    if (cfgRes.data?.[0]) setConfig(cfgRes.data[0])
    setLogs(logRes.data || [])
  }

  useEffect(() => { loadData() }, [])

  const pacienteActual = pacs.find(p => p.id === selectedPacId)

  useEffect(() => {
    if (!pacienteActual) { setMensajePersonalizado(''); return }
    let texto = ''
    if (tipoPlantilla === 'cita') {
      const cita = citas.find(c => c.paciente_id === selectedPacId)
      texto = msgRecordatorioCita({ paciente: pacienteActual, cita, clinica })
    } else if (tipoPlantilla === 'cobro') {
      const plan = planes.find(p => p.paciente_id === selectedPacId)
      texto = msgCobroCuota({ paciente: pacienteActual, plan, rates, clinica })
    } else if (tipoPlantilla === 'post') {
      texto = msgPostOperatorio({ paciente: pacienteActual, procedimiento: 'su tratamiento dental', clinica })
    } else if (tipoPlantilla === 'control') {
      texto = msgControlSemestral({ paciente: pacienteActual, clinica })
    }
    if (tipoPlantilla !== 'libre') setMensajePersonalizado(texto)
  }, [selectedPacId, tipoPlantilla, rates, clinica])

  const saveConfig = async (e) => {
    e.preventDefault()
    if (config.id) {
      await supabase.from('configuracion_notificaciones').update(config).eq('id', config.id)
    } else {
      await supabase.from('configuracion_notificaciones').insert([config])
    }
    toast.success('Configuración guardada')
    loadData()
  }

  const sendBackgroundWhatsApp = async () => {
    if (!pacienteActual?.telefono) return toast.error('El paciente no tiene teléfono')
    if (!config.whatsapp_token) return toast.error('Configura tu API gratuita en la pestaña "APIs Gratuitas"')

    setSendingAuto(true)
    try {
      const r = await fetch('/api/send-auto-message', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          canal: 'whatsapp',
          destinatario: pacienteActual.telefono,
          mensaje: mensajePersonalizado
        })
      })

      const res = await r.json()
      if (res.success) {
        toast.success('¡WhatsApp enviado en segundo plano!')
        loadData()
      } else {
        toast.error(`Error: ${res.error || 'Verifica credenciales'}`)
      }
    } catch {
      toast.error('Error al conectar con el servidor')
    } finally {
      setSendingAuto(false)
    }
  }

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-xl font-bold text-slate-800 flex items-center gap-2">
          <Bot className="w-5 h-5 text-teal-600" /> Mensajería Automática (WhatsApp & Email Gratis)
        </h1>
        <p className="text-xs text-slate-400">Recordatorios automáticos en segundo plano usando servicios 100% gratuitos</p>
      </div>

      <div className="flex border-b border-slate-200 gap-2">
        <button onClick={() => setTab('mensajes')} className={`pb-2.5 px-3 text-xs font-bold border-b-2 flex items-center gap-1.5 ${tab === 'mensajes' ? 'border-teal-600 text-teal-700' : 'border-transparent text-slate-400'}`}>
          <MessageSquare className="w-3.5 h-3.5" /> Enviar Mensajes
        </button>
        <button onClick={() => setTab('automatico')} className={`pb-2.5 px-3 text-xs font-bold border-b-2 flex items-center gap-1.5 ${tab === 'automatico' ? 'border-teal-600 text-teal-700' : 'border-transparent text-slate-400'}`}>
          <Gift className="w-3.5 h-3.5 text-amber-500" /> Configurar APIs Gratuitas
        </button>
        <button onClick={() => setTab('logs')} className={`pb-2.5 px-3 text-xs font-bold border-b-2 flex items-center gap-1.5 ${tab === 'logs' ? 'border-teal-600 text-teal-700' : 'border-transparent text-slate-400'}`}>
          <History className="w-3.5 h-3.5" /> Bitácora ({logs.length})
        </button>
      </div>

      {tab === 'mensajes' && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2 card-box space-y-4">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className="text-xs font-semibold text-slate-600 block mb-1">Paciente *</label>
                <select className="input-field text-xs" value={selectedPacId} onChange={e => setSelectedPacId(e.target.value)}>
                  <option value="">Seleccione paciente...</option>
                  {pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos} ({p.telefono || 'Sin tel'})</option>)}
                </select>
              </div>
              <div>
                <label className="text-xs font-semibold text-slate-600 block mb-1">Plantilla</label>
                <select className="input-field text-xs font-bold text-teal-800" value={tipoPlantilla} onChange={e => setTipoPlantilla(e.target.value)}>
                  <option value="cita">📅 Recordatorio de Cita</option>
                  <option value="cobro">💵 Recordatorio de Cuota / Saldo</option>
                  <option value="post">🩹 Cuidados Post-Operatorios</option>
                  <option value="control">✨ Control Preventivo (6 Meses)</option>
                  <option value="libre">✍️ Mensaje Libre</option>
                </select>
              </div>
            </div>

            <textarea
              rows={8}
              className="input-field font-mono text-xs leading-relaxed bg-slate-50"
              value={mensajePersonalizado}
              onChange={e => setMensajePersonalizado(e.target.value)}
              placeholder="Seleccione un paciente para generar el mensaje..."
            />

            <div className="flex flex-wrap gap-2 pt-2 border-t">
              <button
                onClick={sendBackgroundWhatsApp}
                disabled={sendingAuto || !pacienteActual?.telefono}
                className="btn-primary bg-slate-900 hover:bg-slate-800 text-xs py-2.5 px-4 justify-center"
              >
                <Zap className="w-3.5 h-3.5 text-amber-400" /> {sendingAuto ? 'Enviando...' : 'Auto-Enviar WhatsApp (Segundo Plano)'}
              </button>

              <button
                onClick={() => openWhatsApp(pacienteActual?.telefono, mensajePersonalizado)}
                disabled={!pacienteActual?.telefono}
                className="btn-secondary text-xs py-2.5 text-emerald-700 bg-emerald-50"
              >
                💬 Abrir en WhatsApp Web
              </button>
            </div>
          </div>

          <div className="card-box space-y-3 h-fit">
            <h3 className="font-bold text-sm text-slate-800 border-b pb-2">Estado del Servicio Gratuito</h3>
            <div className="space-y-2 text-xs">
              <div className="flex justify-between items-center p-2 bg-slate-50 rounded-lg">
                <span>WhatsApp API:</span>
                <span className={`badge ${config.whatsapp_token ? 'bg-emerald-100 text-emerald-800' : 'bg-rose-100 text-rose-800'}`}>
                  {config.whatsapp_token ? '✓ Conectado' : 'Sin Configurar'}
                </span>
              </div>
              <div className="flex justify-between items-center p-2 bg-slate-50 rounded-lg">
                <span>Cron 8:00 AM:</span>
                <span className={`badge ${config.auto_cron_activo ? 'bg-teal-100 text-teal-800' : 'bg-slate-100 text-slate-600'}`}>
                  {config.auto_cron_activo ? 'Activo' : 'Pausado'}
                </span>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* CONFIGURACIÓN DE APIS GRATUITAS */}
      {tab === 'automatico' && (
        <form onSubmit={saveConfig} className="card-box space-y-5 max-w-2xl">
          <div className="p-4 bg-teal-50 border border-teal-200 rounded-2xl space-y-2 text-xs text-teal-900">
            <p className="font-bold flex items-center gap-1.5"><Gift className="w-4 h-4 text-teal-600" /> Opciones 100% Gratuitas Disponibles:</p>
            <ul className="list-disc pl-4 space-y-1 text-[11px] text-teal-800">
              <li><b>Green-API (Recomendado):</b> Crea una cuenta gratis en <u>green-api.com</u>, escanea el QR con tu WhatsApp y pega aquí tu <i>IdInstance</i> y <i>ApiTokenInstance</i>.</li>
              <li><b>Meta Cloud API:</b> Da 1.000 conversaciones gratis al mes desde <u>developers.facebook.com</u>.</li>
              <li><b>Resend (Email):</b> Da 3.000 correos gratis al mes desde <u>resend.com</u>.</li>
            </ul>
          </div>

          <div className="space-y-3">
            <h3 className="text-xs font-bold text-slate-700 uppercase">1. Proveedor de WhatsApp Gratuito</h3>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Servicio</label>
                <select className="input-field text-xs font-bold" value={config.whatsapp_provider} onChange={e => setConfig({...config, whatsapp_provider: e.target.value})}>
                  <option value="green_api">Green-API (Escaneo QR Gratis)</option>
                  <option value="meta">Meta Cloud API (1.000 gratis/mes)</option>
                  <option value="ultramsg">UltraMsg</option>
                </select>
              </div>
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">
                  {config.whatsapp_provider === 'meta' ? 'Phone Number ID' : 'Instance ID'}
                </label>
                <input className="input-field text-xs font-mono" value={config.whatsapp_instance_id} onChange={e => setConfig({...config, whatsapp_instance_id: e.target.value})} placeholder="Ej: 1101234567" />
              </div>
            </div>
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">API Token / Clave de Acceso</label>
              <input type="password" className="input-field text-xs font-mono" value={config.whatsapp_token} onChange={e => setConfig({...config, whatsapp_token: e.target.value})} placeholder="••••••••••••••••" />
            </div>
          </div>

          <div className="space-y-3 border-t pt-3">
            <h3 className="text-xs font-bold text-slate-700 uppercase">2. Correos Gratis con Resend (3.000/mes)</h3>
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">API Key de Resend</label>
              <input type="password" className="input-field text-xs font-mono" value={config.resend_api_key} onChange={e => setConfig({...config, resend_api_key: e.target.value})} placeholder="re_123456789..." />
            </div>
          </div>

          <div className="border-t pt-3 flex items-center justify-between">
            <div>
              <p className="text-xs font-bold text-slate-800">Cron Job Diario Automático (8:00 AM)</p>
              <p className="text-[11px] text-slate-400">Escanea las citas de mañana y las envía solo</p>
            </div>
            <label className="flex items-center gap-2 cursor-pointer">
              <input type="checkbox" checked={config.auto_cron_activo} onChange={e => setConfig({...config, auto_cron_activo: e.target.checked})} className="w-4 h-4 rounded text-teal-600" />
              <span className="text-xs font-bold">Activo</span>
            </label>
          </div>

          <button type="submit" className="btn-primary w-full justify-center">
            <Save className="w-4 h-4" /> Guardar Credenciales Gratuitas
          </button>
        </form>
      )}

      {tab === 'logs' && (
        <div className="card-box p-0 overflow-hidden border">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-50 border-b text-slate-500 font-bold uppercase">
              <tr><th className="p-3">Fecha</th><th className="p-3">Canal</th><th className="p-3">Destinatario</th><th className="p-3">Estado</th></tr>
            </thead>
            <tbody className="divide-y">
              {logs.length === 0 ? (
                <tr><td colSpan={4} className="p-6 text-center text-slate-400">Sin envíos registrados</td></tr>
              ) : (
                logs.map(l => (
                  <tr key={l.id} className="hover:bg-slate-50">
                    <td className="p-3 text-slate-400">{new Date(l.created_at).toLocaleString('es-VE')}</td>
                    <td className="p-3"><span className="badge bg-slate-100">{l.canal}</span></td>
                    <td className="p-3 font-mono font-bold">{l.destinatario}</td>
                    <td className="p-3"><span className={`badge ${l.estado === 'enviado' ? 'bg-emerald-100 text-emerald-700' : 'bg-rose-100 text-rose-700'}`}>{l.estado}</span></td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
EOF

npm run build
echo "✅ Soporte de APIs 100% gratuitas instalado y compilado con éxito!"
