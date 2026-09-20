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
