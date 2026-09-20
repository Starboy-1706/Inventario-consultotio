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
