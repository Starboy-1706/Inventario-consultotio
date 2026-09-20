#!/bin/bash
set -e

echo "🤖 Instalando Motores Serverless de WhatsApp, Correo Automático y Vercel Cron..."

# 1. Configurar vercel.json con el Cron Job Diario
cat > vercel.json << 'EOF'
{
  "crons": [
    {
      "path": "/api/cron-reminders",
      "schedule": "0 12 * * *"
    }
  ],
  "rewrites": [
    { "source": "/api/(.*)", "destination": "/api/$1" },
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
EOF

# 2. Serverless Function: Disparador Cron Diario (/api/cron-reminders)
cat > api/cron-reminders.js << 'EOF'
import { createClient } from '@supabase/supabase-js'

export default async function handler(req, res) {
  // Inicializar Supabase en backend
  const supabaseUrl = process.env.VITE_SUPABASE_URL || process.env.SUPABASE_URL
  const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY || process.env.SUPABASE_ANON_KEY

  if (!supabaseUrl || !supabaseKey) {
    return res.status(500).json({ error: 'Faltan credenciales de Supabase en variables de entorno' })
  }

  const supabase = createClient(supabaseUrl, supabaseKey)

  try {
    // 1. Cargar Configuración de Notificaciones
    const { data: cfgList } = await supabase.from('configuracion_notificaciones').select('*').limit(1)
    const cfg = cfgList?.[0]

    if (!cfg || !cfg.auto_cron_activo) {
      return res.status(200).json({ message: 'El Cron automático está desactivado en la configuración' })
    }

    // 2. Buscar citas para mañana
    const manana = new Date()
    manana.setDate(manana.getDate() + 1)
    const mananaStr = manana.toISOString().split('T')[0]

    const { data: citas } = await supabase
      .from('citas')
      .select('*, pacientes(nombres, apellidos, telefono, email), tratamientos(nombre), doctores(nombres, apellidos)')
      .gte('fecha', `${mananaStr}T00:00:00`)
      .lte('fecha', `${mananaStr}T23:59:59`)
      .in('estado', ['programada', 'confirmada'])

    const { data: clinicaList } = await supabase.from('configuracion_consultorio').select('*').limit(1)
    const clinica = clinicaList?.[0] || { nombre: 'Consultorio Odontológico' }

    const resultados = []

    for (const cita of (citas || [])) {
      const pac = cita.pacientes
      if (!pac) continue

      const fechaFmt = new Date(cita.fecha).toLocaleDateString('es-VE', { weekday: 'long', day: 'numeric', month: 'long' })
      const horaFmt = new Date(cita.fecha).toLocaleTimeString('es-VE', { hour: '2-digit', minute: '2-digit' })
      const trat = cita.tratamientos?.nombre || 'Consulta Odontológica'

      const msg = `🦷 *${clinica.nombre}*\n¡Hola, *${pac.nombres}*! Le recordamos su cita programada para mañana:\n📅 *Fecha:* ${fechaFmt}\n⏰ *Hora:* ${horaFmt}\n👨‍⚕️ *Tratamiento:* ${trat}\n📍 *Dirección:* ${clinica.direccion || 'Sede Principal'}\n\nPor favor, responda *CONFIRMO* para asegurar su lugar.`

      // A. Enviar WhatsApp en segundo plano si está configurado
      if (cfg.whatsapp_token && pac.telefono) {
        let phone = String(pac.telefono).replace(/\D/g, '')
        if (phone.startsWith('0')) phone = '58' + phone.substring(1)
        if (phone.length === 10) phone = '58' + phone

        try {
          let sent = false
          if (cfg.whatsapp_provider === 'ultramsg' && cfg.whatsapp_instance_id) {
            const r = await fetch(`https://api.ultramsg.com/${cfg.whatsapp_instance_id}/messages/chat`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
              body: new URLSearchParams({ token: cfg.whatsapp_token, to: phone, body: msg })
            })
            sent = r.ok
          } else if (cfg.whatsapp_provider === 'wassenger') {
            const r = await fetch('https://api.wassenger.com/v1/messages', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json', 'Token': cfg.whatsapp_token },
              body: JSON.stringify({ phone: `+${phone}`, message: msg })
            })
            sent = r.ok
          }

          await supabase.from('logs_notificaciones').insert({
            canal: 'whatsapp',
            destinatario: phone,
            tipo_mensaje: 'Recordatorio Cron Cita',
            contenido: msg,
            estado: sent ? 'enviado' : 'fallido'
          })
          resultados.push({ paciente: pac.nombres, canal: 'whatsapp', estado: sent ? 'ok' : 'fail' })
        } catch (err) {
          console.error('Error enviando WhatsApp:', err)
        }
      }

      // B. Enviar Correo en segundo plano si tiene Resend configurado
      if (cfg.resend_api_key && pac.email) {
        try {
          const emailHtml = `<div style="font-family: sans-serif; padding: 20px; color: #1e293b;"><h2 style="color: #0d9488;">🦷 ${clinica.nombre}</h2><p>Estimado/a <b>${pac.nombres} ${pac.apellidos}</b>,</p><p>Le recordamos su cita odontológica programada:</p><div style="background: #f1f5f9; padding: 15px; border-radius: 10px;"><p>📅 <b>Fecha:</b> ${fechaFmt}</p><p>⏰ <b>Hora:</b> ${horaFmt}</p><p>👨‍⚕️ <b>Procedimiento:</b> ${trat}</p></div><p style="font-size: 12px; color: #64748b; margin-top: 20px;">${clinica.direccion || ''}</p></div>`

          const r = await fetch('https://api.resend.com/emails', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${cfg.resend_api_key}`
            },
            body: JSON.stringify({
              from: cfg.email_from || 'OdontoCare <onboarding@resend.dev>',
              to: [pac.email],
              subject: `Recordatorio de Cita Odontológica - ${fechaFmt}`,
              html: emailHtml
            })
          })

          await supabase.from('logs_notificaciones').insert({
            canal: 'email',
            destinatario: pac.email,
            tipo_mensaje: 'Recordatorio Cron Cita',
            contenido: `Recordatorio enviado a ${pac.email}`,
            estado: r.ok ? 'enviado' : 'fallido'
          })
          resultados.push({ paciente: pac.nombres, canal: 'email', estado: r.ok ? 'ok' : 'fail' })
        } catch (err) {
          console.error('Error enviando Email:', err)
        }
      }
    }

    return res.status(200).json({
      success: true,
      fechaRecordada: mananaStr,
      totalCitasProcesadas: (citas || []).length,
      detalles: resultados
    })
  } catch (error) {
    return res.status(500).json({ error: error.message })
  }
}
EOF

# 3. Serverless Function: Envío Inmediato / Test (/api/send-auto-message)
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

  if (!cfg) return res.status(400).json({ error: 'No hay configuración de mensajería guardada' })

  try {
    if (canal === 'whatsapp') {
      if (!cfg.whatsapp_token) return res.status(400).json({ error: 'Falta configurar el Token de WhatsApp' })

      let phone = String(destinatario).replace(/\D/g, '')
      if (phone.startsWith('0')) phone = '58' + phone.substring(1)
      if (phone.length === 10) phone = '58' + phone

      let ok = false
      let respData = null

      if (cfg.whatsapp_provider === 'ultramsg') {
        const r = await fetch(`https://api.ultramsg.com/${cfg.whatsapp_instance_id}/messages/chat`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ token: cfg.whatsapp_token, to: phone, body: mensaje })
        })
        respData = await r.json()
        ok = r.ok
      } else if (cfg.whatsapp_provider === 'wassenger') {
        const r = await fetch('https://api.wassenger.com/v1/messages', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Token': cfg.whatsapp_token },
          body: JSON.stringify({ phone: `+${phone}`, message: mensaje })
        })
        respData = await r.json()
        ok = r.ok
      }

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

    if (canal === 'email') {
      if (!cfg.resend_api_key) return res.status(400).json({ error: 'Falta configurar la API Key de Resend' })

      const r = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${cfg.resend_api_key}`
        },
        body: JSON.stringify({
          from: cfg.email_from || 'OdontoCare <onboarding@resend.dev>',
          to: [destinatario],
          subject: asunto || 'Información de su Consulta Odontológica',
          html: html || `<p>${mensaje}</p>`
        })
      })

      const data = await r.json()

      await supabase.from('logs_notificaciones').insert({
        canal: 'email',
        destinatario,
        tipo_mensaje: 'Envío Directo',
        contenido: mensaje,
        estado: r.ok ? 'enviado' : 'fallido',
        error_detalle: r.ok ? null : JSON.stringify(data)
      })

      return res.status(200).json({ success: r.ok, response: data })
    }

    return res.status(400).json({ error: 'Canal no válido' })
  } catch (err) {
    return res.status(500).json({ error: err.message })
  }
}
EOF

# 4. Actualizar Interfaz de Comunicación con Panel de Configuración Automática y Logs
cat > src/components/Comunicacion/CentroComunicacion.jsx << 'EOF'
import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import {
  msgRecordatorioCita, msgCobroCuota, msgPostOperatorio,
  msgControlSemestral, openWhatsApp, makePhoneCall
} from '../../utils/comunicaciones'
import {
  MessageSquare, Phone, Mail, Send, Calendar,
  CreditCard, Bot, Zap, Save, CheckCircle2, AlertTriangle,
  History, Settings, Play
} from 'lucide-react'
import toast from 'react-hot-toast'

export default function CentroComunicacion() {
  const { rates } = useCurrency()
  const [tab, setTab] = useState('mensajes') // mensajes | automatico | logs
  const [pacs, setPacs] = useState([])
  const [citas, setCitas] = useState([])
  const [planes, setPlanes] = useState([])
  const [clinica, setClinica] = useState(null)
  const [logs, setLogs] = useState([])

  const [selectedPacId, setSelectedPacId] = useState('')
  const [tipoPlantilla, setTipoPlantilla] = useState('cita')
  const [mensajePersonalizado, setMensajePersonalizado] = useState('')
  const [sendingAuto, setSendingAuto] = useState(false)

  // Configuración de Automatización en DB
  const [config, setConfig] = useState({
    whatsapp_provider: 'ultramsg',
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

  // Generar mensaje
  useEffect(() => {
    if (!pacienteActual) {
      setMensajePersonalizado('')
      return
    }

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

  // Guardar configuración de APIs
  const saveConfig = async (e) => {
    e.preventDefault()
    if (config.id) {
      await supabase.from('configuracion_notificaciones').update(config).eq('id', config.id)
    } else {
      await supabase.from('configuracion_notificaciones').insert([config])
    }
    toast.success('Configuración de automatización guardada')
    loadData()
  }

  // Enviar mensaje en segundo plano (Serverless API)
  const sendBackgroundWhatsApp = async () => {
    if (!pacienteActual?.telefono) return toast.error('El paciente no tiene teléfono')
    if (!config.whatsapp_token) return toast.error('Configura primero tu Token de WhatsApp en la pestaña "Automatización"')

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
        toast.success('¡WhatsApp enviado en segundo plano con éxito!')
        loadData()
      } else {
        toast.error(`Fallo de entrega: ${res.error || 'Verifica tus credenciales'}`)
      }
    } catch (err) {
      toast.error('Error al conectar con el servidor')
    } finally {
      setSendingAuto(false)
    }
  }

  // Ejecutar prueba del Cron Job de mañana ahora mismo
  const ejecutarCronPrueba = async () => {
    toast.loading('Ejecutando escaneo automático de citas...')
    try {
      const r = await fetch('/api/cron-reminders')
      const res = await r.json()
      toast.dismiss()
      if (res.success) {
        toast.success(`Cron completado: ${res.totalCitasProcesadas} citas procesadas`)
        loadData()
      } else {
        toast.error(res.message || 'Error en ejecución de Cron')
      }
    } catch {
      toast.dismiss()
      toast.error('Error al ejecutar Cron')
    }
  }

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-xl font-bold text-slate-800 flex items-center gap-2">
          <Bot className="w-5 h-5 text-teal-600" /> Centro de Automatización & Comunicaciones
        </h1>
        <p className="text-xs text-slate-400">Recordatorios automáticos en segundo plano (WhatsApp + Email) y Cron Job diario</p>
      </div>

      {/* Tabs */}
      <div className="flex border-b border-slate-200 gap-2">
        <button onClick={() => setTab('mensajes')} className={`pb-2.5 px-3 text-xs font-bold border-b-2 flex items-center gap-1.5 ${tab === 'mensajes' ? 'border-teal-600 text-teal-700' : 'border-transparent text-slate-400'}`}>
          <MessageSquare className="w-3.5 h-3.5" /> Enviar Mensajes
        </button>
        <button onClick={() => setTab('automatico')} className={`pb-2.5 px-3 text-xs font-bold border-b-2 flex items-center gap-1.5 ${tab === 'automatico' ? 'border-teal-600 text-teal-700' : 'border-transparent text-slate-400'}`}>
          <Zap className="w-3.5 h-3.5 text-amber-500" /> Configurar Auto-Bot & APIs
        </button>
        <button onClick={() => setTab('logs')} className={`pb-2.5 px-3 text-xs font-bold border-b-2 flex items-center gap-1.5 ${tab === 'logs' ? 'border-teal-600 text-teal-700' : 'border-transparent text-slate-400'}`}>
          <History className="w-3.5 h-3.5" /> Bitácora de Envíos ({logs.length})
        </button>
      </div>

      {/* TAB 1: MENSAJES Y DISPARO */}
      {tab === 'mensajes' && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2 card-box space-y-4">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className="text-xs font-semibold text-slate-600 block mb-1">Paciente *</label>
                <select className="input-field text-xs" value={selectedPacId} onChange={e => setSelectedPacId(e.target.value)}>
                  <option value="">Seleccione un paciente...</option>
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
              {/* Botón 1: Automático en segundo plano */}
              <button
                onClick={sendBackgroundWhatsApp}
                disabled={sendingAuto || !pacienteActual?.telefono}
                className="btn-primary bg-slate-900 hover:bg-slate-800 text-xs py-2.5 px-4 justify-center"
              >
                <Zap className="w-3.5 h-3.5 text-amber-400" /> {sendingAuto ? 'Enviando en segundo plano...' : 'Auto-Enviar WhatsApp (Sin abrir App)'}
              </button>

              {/* Botón 2: Abrir WhatsApp Web */}
              <button
                onClick={() => openWhatsApp(pacienteActual?.telefono, mensajePersonalizado)}
                disabled={!pacienteActual?.telefono}
                className="btn-secondary text-xs py-2.5 text-emerald-700 bg-emerald-50 hover:bg-emerald-100"
              >
                💬 Abrir en WhatsApp Web
              </button>
            </div>
          </div>

          <div className="card-box space-y-3 h-fit">
            <h3 className="font-bold text-sm text-slate-800 border-b pb-2">Estado del Servidor</h3>
            <div className="space-y-2 text-xs">
              <div className="flex justify-between items-center p-2 bg-slate-50 rounded-lg">
                <span>WhatsApp Bot:</span>
                <span className={`badge ${config.whatsapp_token ? 'bg-emerald-100 text-emerald-800' : 'bg-rose-100 text-rose-800'}`}>
                  {config.whatsapp_token ? '✓ Vinculado' : 'Pendiente'}
                </span>
              </div>
              <div className="flex justify-between items-center p-2 bg-slate-50 rounded-lg">
                <span>Cron Job Diario (8 AM):</span>
                <span className={`badge ${config.auto_cron_activo ? 'bg-teal-100 text-teal-800' : 'bg-slate-100 text-slate-600'}`}>
                  {config.auto_cron_activo ? 'Activo' : 'Pausado'}
                </span>
              </div>
            </div>
            <button onClick={ejecutarCronPrueba} className="w-full btn-secondary text-xs justify-center py-2">
              <Play className="w-3.5 h-3.5 text-teal-600" /> Probar Escaneo de Citas de Mañana
            </button>
          </div>
        </div>
      )}

      {/* TAB 2: CONFIGURACIÓN DE APIS (UltraMsg / Wassenger / Resend) */}
      {tab === 'automatico' && (
        <form onSubmit={saveConfig} className="card-box space-y-5 max-w-2xl">
          <div className="border-b pb-3">
            <h2 className="font-bold text-sm text-slate-800 flex items-center gap-2">
              <Settings className="w-4 h-4 text-teal-600" /> Credenciales de Mensajería Automática
            </h2>
            <p className="text-[11px] text-slate-400 mt-0.5">Conecta tu número escaneando el QR de tu pasarela para enviar en segundo plano</p>
          </div>

          {/* WhatsApp */}
          <div className="space-y-3">
            <h3 className="text-xs font-bold text-slate-700 uppercase">1. Pasarela de WhatsApp</h3>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Proveedor</label>
                <select className="input-field text-xs font-bold" value={config.whatsapp_provider} onChange={e => setConfig({...config, whatsapp_provider: e.target.value})}>
                  <option value="ultramsg">UltraMsg (Recomendado)</option>
                  <option value="wassenger">Wassenger API</option>
                </select>
              </div>
              <div>
                <label className="text-[11px] font-semibold text-slate-500 block mb-1">Instance ID (UltraMsg)</label>
                <input className="input-field text-xs font-mono" value={config.whatsapp_instance_id} onChange={e => setConfig({...config, whatsapp_instance_id: e.target.value})} placeholder="instance12345" />
              </div>
            </div>
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Token de Acceso / API Key</label>
              <input type="password" className="input-field text-xs font-mono" value={config.whatsapp_token} onChange={e => setConfig({...config, whatsapp_token: e.target.value})} placeholder="••••••••••••••••" />
            </div>
          </div>

          {/* Email (Resend) */}
          <div className="space-y-3 border-t pt-3">
            <h3 className="text-xs font-bold text-slate-700 uppercase">2. Correos Automáticos (Resend)</h3>
            <div>
              <label className="text-[11px] font-semibold text-slate-500 block mb-1">Resend API Key</label>
              <input type="password" className="input-field text-xs font-mono" value={config.resend_api_key} onChange={e => setConfig({...config, resend_api_key: e.target.value})} placeholder="re_123456789..." />
            </div>
          </div>

          {/* Cron Toggle */}
          <div className="border-t pt-3 flex items-center justify-between">
            <div>
              <p className="text-xs font-bold text-slate-800">Cron Job Automático Diario</p>
              <p className="text-[11px] text-slate-400">Escanea las citas del día siguiente a las 8:00 AM y envía los recordatorios</p>
            </div>
            <label className="flex items-center gap-2 cursor-pointer">
              <input type="checkbox" checked={config.auto_cron_activo} onChange={e => setConfig({...config, auto_cron_activo: e.target.checked})} className="w-4 h-4 rounded text-teal-600" />
              <span className="text-xs font-bold">Activo</span>
            </label>
          </div>

          <button type="submit" className="btn-primary w-full justify-center">
            <Save className="w-4 h-4" /> Guardar Configuración
          </button>
        </form>
      )}

      {/* TAB 3: BITÁCORA / LOGS */}
      {tab === 'logs' && (
        <div className="card-box p-0 overflow-hidden border">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-50 border-b text-slate-500 font-bold uppercase">
              <tr>
                <th className="p-3">Fecha</th>
                <th className="p-3">Canal</th>
                <th className="p-3">Destinatario</th>
                <th className="p-3">Tipo</th>
                <th className="p-3">Estado</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {logs.length === 0 ? (
                <tr><td colSpan={5} className="p-6 text-center text-slate-400">No hay registros de envíos aún</td></tr>
              ) : (
                logs.map(l => (
                  <tr key={l.id} className="hover:bg-slate-50">
                    <td className="p-3 text-slate-400">{new Date(l.created_at).toLocaleString('es-VE')}</td>
                    <td className="p-3"><span className="badge bg-slate-100">{l.canal}</span></td>
                    <td className="p-3 font-mono font-bold">{l.destinatario}</td>
                    <td className="p-3">{l.tipo_mensaje}</td>
                    <td className="p-3">
                      <span className={`badge ${l.estado === 'enviado' ? 'bg-emerald-100 text-emerald-700' : 'bg-rose-100 text-rose-700'}`}>
                        {l.estado}
                      </span>
                    </td>
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

# 5. Compilar y verificar
echo "📦 Compilando sistema con soporte de Cron y automatización..."
npm run build

echo "🎉 ¡AUTOMATIZACIÓN EN SEGUNDO PLANO Y CRON JOB INSTALADOS CON ÉXITO!"
