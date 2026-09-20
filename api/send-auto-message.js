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
