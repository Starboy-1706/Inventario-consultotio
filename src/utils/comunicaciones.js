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
