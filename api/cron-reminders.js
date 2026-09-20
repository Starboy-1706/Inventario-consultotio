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
