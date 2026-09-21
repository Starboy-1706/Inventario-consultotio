import React, { useState } from 'react'
import { Printer, X, MessageCircle, FileText, Receipt, CheckCircle } from 'lucide-react'

export default function ReciboModal({ isOpen, onClose, data, consultorio }) {
  const [formato, setFormato] = useState('carta')

  if (!isOpen || !data) return null

  const config = consultorio || {
    nombre: 'Consultorio Dental & Médico',
    rif_nit: 'J-12345678-0',
    telefono: '+58 412 000 0000',
    direccion: 'Av. Principal, Centro Profesional, Piso 2',
    email: 'contacto@consultorio.com',
    mensaje_recibo: 'Gracias por su confianza. ¡Cuidamos de su salud!'
  }

  const {
    id,
    fecha = new Date().toLocaleDateString('es-ES'),
    paciente_nombre = 'Paciente General',
    paciente_cedula = 'N/A',
    paciente_telefono = '',
    doctor_nombre = 'Dr. Tratante',
    procedimiento = 'Consulta Médica General',
    diagnostico = '',
    dientes_tratados = '',
    metodo_pago = 'Efectivo',
    monto_usd = 0,
    subtotal_usd = monto_usd,
    impuesto_usd = 0,
    total_ves = 0,
    total_cop = 0,
    tasa_ves = 0,
    tasa_cop = 0,
    factura = id ? `REC-${String(id).slice(0, 8).toUpperCase()}` : 'REC-00001'
  } = data

  // Función de impresión infalible usando iframe invisible
  const handlePrint = () => {
    const targetId = formato === 'carta' ? 'area-recibo' : 'area-recibo-ticket'
    const element = document.getElementById(targetId)
    if (!element) return

    const iframe = document.createElement('iframe')
    iframe.style.position = 'fixed'
    iframe.style.right = '0'
    iframe.style.bottom = '0'
    iframe.style.width = '0'
    iframe.style.height = '0'
    iframe.style.border = '0'
    document.body.appendChild(iframe)

    const doc = iframe.contentWindow.document
    doc.open()
    doc.write(`
      <!DOCTYPE html>
      <html>
        <head>
          <title>Recibo - #${factura}</title>
          <style>
            * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
            body { background: #fff; color: #111827; }
            ${formato === 'ticket' ? `
              @page { size: 80mm auto; margin: 0; }
              body { width: 72mm; margin: 0 auto; padding: 12px 4px; font-family: monospace; font-size: 11px; }
            ` : `
              @page { size: letter portrait; margin: 12mm; }
              body { max-width: 800px; margin: 0 auto; padding: 10px; }
            `}
            .flex { display: flex; }
            .justify-between { justify-content: space-between; }
            .items-center { align-items: center; }
            .items-start { align-items: flex-start; }
            .text-right { text-align: right; }
            .text-center { text-align: center; }
            .font-bold { font-weight: bold; }
            .font-semibold { font-weight: 600; }
            .font-mono { font-family: monospace; }
            .text-xs { font-size: 11px; }
            .text-sm { font-size: 13px; }
            .text-base { font-size: 15px; }
            .text-lg { font-size: 17px; }
            .text-xl { font-size: 20px; }
            .text-2xl { font-size: 24px; }
            .text-gray-400 { color: #9ca3af; }
            .text-gray-500 { color: #6b7280; }
            .text-gray-600 { color: #4b5563; }
            .text-gray-700 { color: #374151; }
            .text-gray-800 { color: #1f2937; }
            .text-gray-900 { color: #111827; }
            .text-blue-600 { color: #2563eb; }
            .text-blue-700 { color: #1d4ed8; }
            .text-emerald-600 { color: #059669; }
            .bg-gray-50 { background-color: #f9fafb; }
            .bg-gray-100 { background-color: #f3f4f6; }
            .bg-blue-50 { background-color: #eff6ff; }
            .p-1\\.5 { padding: 6px; }
            .p-3 { padding: 10px 12px; }
            .p-4 { padding: 14px; }
            .p-6 { padding: 20px; }
            .p-8 { padding: 28px; }
            .py-2 { padding-top: 8px; padding-bottom: 8px; }
            .py-2\\.5 { padding-top: 10px; padding-bottom: 10px; }
            .pb-3 { padding-bottom: 12px; }
            .pb-6 { padding-bottom: 20px; }
            .pt-2 { padding-top: 8px; }
            .pt-3 { padding-top: 12px; }
            .pt-4 { padding-top: 16px; }
            .mt-0\\.5 { margin-top: 2px; }
            .mt-1 { margin-top: 4px; }
            .mt-2 { margin-top: 8px; }
            .mt-4 { margin-top: 16px; }
            .mt-8 { margin-top: 28px; }
            .mb-1 { margin-bottom: 4px; }
            .mb-2 { margin-bottom: 8px; }
            .my-6 { margin-top: 20px; margin-bottom: 20px; }
            .border { border: 1px solid #e5e7eb; }
            .border-b { border-bottom: 1px solid #e5e7eb; }
            .border-b-2 { border-bottom: 2px solid #2563eb; }
            .border-t { border-top: 1px solid #e5e7eb; }
            .border-dashed { border-style: dashed; }
            .border-gray-100 { border-color: #f3f4f6; }
            .border-gray-200 { border-color: #e5e7eb; }
            .border-gray-300 { border-color: #d1d5db; }
            .border-blue-200 { border-color: #bfdbfe; }
            .border-blue-600 { border-color: #2563eb; }
            .rounded { border-radius: 4px; }
            .rounded-lg { border-radius: 8px; }
            .rounded-xl { border-radius: 12px; }
            .rounded-full { border-radius: 9999px; }
            .grid { display: grid; }
            .grid-cols-2 { grid-template-columns: 1fr 1fr; }
            .gap-6 { gap: 24px; }
            .w-full { width: 100%; }
            .w-64 { width: 240px; }
            .uppercase { text-transform: uppercase; }
            .tracking-wider { letter-spacing: 0.05em; }
            .tracking-tight { letter-spacing: -0.025em; }
            .space-y-1 > * + * { margin-top: 4px; }
            .space-y-1\\.5 > * + * { margin-top: 6px; }
            .space-y-2 > * + * { margin-top: 8px; }
            table { width: 100%; border-collapse: collapse; }
            th { background-color: #f9fafb; font-size: 11px; text-transform: uppercase; color: #4b5563; font-weight: bold; border-bottom: 1px solid #e5e7eb; }
            td { border-bottom: 1px solid #e5e7eb; }
          </style>
        </head>
        <body>
          ${element.innerHTML}
        </body>
      </html>
    `)
    doc.close()

    setTimeout(() => {
      iframe.contentWindow.focus()
      iframe.contentWindow.print()
      setTimeout(() => {
        if (document.body.contains(iframe)) {
          document.body.removeChild(iframe)
        }
      }, 2000)
    }, 250)
  }

  const handleWhatsApp = () => {
    const phone = String(paciente_telefono).replace(/[^0-9]/g, '')
    const mensaje = `Hola *${paciente_nombre}*, le compartimos su comprobante de *${config.nombre}*:%0A%0A` +
      `🧾 *Recibo:* #${factura}%0A` +
      `📅 *Fecha:* ${fecha}%0A` +
      `🩺 *Tratamiento:* ${procedimiento}%0A` +
      (dientes_tratados ? `🦷 *Dientes:* ${dientes_tratados}%0A` : '') +
      `💵 *Monto Total:* $${Number(monto_usd).toFixed(2)} USD` +
      (total_ves > 0 ? ` (Bs. ${Number(total_ves).toLocaleString('es-VE')})` : '') +
      (total_cop > 0 ? ` ($ ${Number(total_cop).toLocaleString('es-CO')} COP)` : '') + `%0A` +
      `💳 *Pago:* ${metodo_pago}%0A%0A` +
      `_${config.mensaje_recibo}_`

    window.open(`https://wa.me/${phone}?text=${mensaje}`, '_blank')
  }

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4 overflow-y-auto">
      <div className="bg-white dark:bg-gray-800 w-full max-w-2xl rounded-2xl shadow-2xl border border-gray-200 dark:border-gray-700 overflow-hidden">
        
        {/* Controles superiores */}
        <div className="p-4 bg-gray-50 dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700 flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center bg-gray-200 dark:bg-gray-700 p-1 rounded-xl text-xs font-semibold">
            <button
              onClick={() => setFormato('carta')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg transition-all ${
                formato === 'carta' ? 'bg-white dark:bg-gray-800 shadow-sm text-blue-600 font-bold' : 'text-gray-500'
              }`}
            >
              <FileText className="w-3.5 h-3.5" /> Carta / A4
            </button>
            <button
              onClick={() => setFormato('ticket')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg transition-all ${
                formato === 'ticket' ? 'bg-white dark:bg-gray-800 shadow-sm text-blue-600 font-bold' : 'text-gray-500'
              }`}
            >
              <Receipt className="w-3.5 h-3.5" /> Ticket (80mm)
            </button>
          </div>

          <div className="flex items-center gap-2">
            {paciente_telefono && (
              <button
                onClick={handleWhatsApp}
                className="bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-medium px-3 py-1.5 rounded-lg inline-flex items-center gap-1.5 transition-colors shadow-sm"
              >
                <MessageCircle className="w-4 h-4" /> WhatsApp
              </button>
            )}
            <button
              onClick={handlePrint}
              className="bg-blue-600 hover:bg-blue-700 text-white text-xs font-medium px-4 py-1.5 rounded-lg inline-flex items-center gap-1.5 transition-colors shadow-sm font-bold"
            >
              <Printer className="w-4 h-4" /> Imprimir
            </button>
            <button
              onClick={onClose}
              className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 p-1.5 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* FORMATO CARTA / FACTURA */}
        {formato === 'carta' && (
          <div id="area-recibo" className="p-8 bg-white text-gray-800 font-sans">
            <div className="flex justify-between items-start border-b-2 border-blue-600 pb-6">
              <div>
                <div className="flex items-center gap-2">
                  <span className="text-2xl">🏥</span>
                  <h1 className="text-xl font-bold text-gray-900 tracking-tight">{config.nombre}</h1>
                </div>
                <p className="text-xs text-gray-500 mt-1">RIF/NIT: {config.rif_nit}</p>
                <p className="text-xs text-gray-500">{config.direccion}</p>
                <p className="text-xs text-gray-500">Tel: {config.telefono} | {config.email}</p>
              </div>
              <div className="text-right">
                <span className="inline-block bg-blue-50 text-blue-700 font-bold text-xs uppercase px-3 py-1 rounded-full border border-blue-200 mb-2">
                  Comprobante de Pago
                </span>
                <p className="text-lg font-mono font-bold text-gray-800">#{factura}</p>
                <p className="text-xs text-gray-500">Fecha: {fecha}</p>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-6 my-6 bg-gray-50 p-4 rounded-xl border border-gray-100">
              <div>
                <p className="text-xs font-semibold text-gray-400 uppercase">Paciente</p>
                <p className="text-sm font-bold text-gray-900">{paciente_nombre}</p>
                <p className="text-xs text-gray-600">Doc: {paciente_cedula}</p>
                {paciente_telefono && <p className="text-xs text-gray-600">Tel: {paciente_telefono}</p>}
              </div>
              <div className="text-right">
                <p className="text-xs font-semibold text-gray-400 uppercase">Profesional Tratante</p>
                <p className="text-sm font-bold text-gray-900">{doctor_nombre}</p>
                <p className="text-xs text-emerald-600 font-medium flex items-center justify-end gap-1 mt-0.5">
                  <CheckCircle className="w-3.5 h-3.5" /> Pago Verificado
                </p>
              </div>
            </div>

            <div className="overflow-hidden border border-gray-200 rounded-xl my-6">
              <table className="w-full text-left text-sm">
                <thead className="bg-gray-100 text-gray-600 uppercase text-[11px] font-bold">
                  <tr>
                    <th className="p-3">Descripción / Tratamiento</th>
                    <th className="p-3 text-center">Piezas</th>
                    <th className="p-3 text-right">Monto (USD)</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200">
                  <tr>
                    <td className="p-3">
                      <p className="font-semibold text-gray-900">{procedimiento}</p>
                      {diagnostico && <p className="text-xs text-gray-500 mt-0.5">{diagnostico}</p>}
                    </td>
                    <td className="p-3 text-center font-mono text-xs text-gray-600">{dientes_tratados || '—'}</td>
                    <td className="p-3 text-right font-bold text-gray-900">${Number(subtotal_usd || monto_usd).toFixed(2)}</td>
                  </tr>
                </tbody>
              </table>
            </div>

            <div className="flex justify-between items-start gap-6 border-t border-gray-200 pt-4">
              <div className="text-xs text-gray-500 space-y-1">
                <p><span className="font-semibold text-gray-700">Método de Pago:</span> {metodo_pago}</p>
                {tasa_ves > 0 && <p><span className="font-semibold text-gray-700">Tasa VES:</span> Bs. {Number(tasa_ves).toFixed(2)}</p>}
                {tasa_cop > 0 && <p><span className="font-semibold text-gray-700">Tasa COP:</span> $ {Number(tasa_cop).toFixed(2)}</p>}
              </div>
              <div className="w-64 space-y-1.5">
                <div className="flex justify-between text-base font-bold text-blue-700 border-t border-gray-200 pt-2">
                  <span>Total USD:</span>
                  <span>${Number(monto_usd).toFixed(2)}</span>
                </div>
                {total_ves > 0 && (
                  <div className="flex justify-between text-xs font-semibold text-gray-700 bg-gray-50 p-1.5 rounded">
                    <span>Total VES:</span>
                    <span>Bs. {Number(total_ves).toLocaleString('es-VE', { minimumFractionDigits: 2 })}</span>
                  </div>
                )}
                {total_cop > 0 && (
                  <div className="flex justify-between text-xs font-semibold text-gray-700 bg-gray-50 p-1.5 rounded">
                    <span>Total COP:</span>
                    <span>$ {Number(total_cop).toLocaleString('es-CO')}</span>
                  </div>
                )}
              </div>
            </div>

            <div className="mt-8 pt-4 border-t border-gray-200 text-center text-xs text-gray-400">
              <p className="font-medium text-gray-600">{config.mensaje_recibo}</p>
            </div>
          </div>
        )}

        {/* FORMATO TICKET TÉRMICO */}
        {formato === 'ticket' && (
          <div id="area-recibo-ticket" className="p-6 bg-white text-gray-900 font-mono text-xs max-w-[340px] mx-auto border-x border-dashed border-gray-300">
            <div className="text-center space-y-1 border-b border-dashed border-gray-300 pb-3">
              <h2 className="text-sm font-black uppercase">{config.nombre}</h2>
              <p className="text-[11px] text-gray-600">RIF: {config.rif_nit}</p>
              <p className="text-[10px] text-gray-500">{config.direccion}</p>
              <p className="text-[11px] text-gray-600">Tel: {config.telefono}</p>
            </div>

            <div className="py-2.5 border-b border-dashed border-gray-300 space-y-0.5 text-[11px]">
              <div className="flex justify-between font-bold"><span>RECIBO:</span><span>#{factura}</span></div>
              <div className="flex justify-between"><span>FECHA:</span><span>{fecha}</span></div>
              <div className="flex justify-between"><span>PACIENTE:</span><span className="truncate max-w-[170px]">{paciente_nombre}</span></div>
              <div className="flex justify-between"><span>DOC:</span><span>{paciente_cedula}</span></div>
              <div className="flex justify-between"><span>MÉDICO:</span><span className="truncate max-w-[170px]">{doctor_nombre}</span></div>
            </div>

            <div className="py-2.5 border-b border-dashed border-gray-300">
              <p className="font-bold text-[11px] uppercase mb-1">{procedimiento}</p>
              {dientes_tratados && <p className="text-[10px] text-gray-600">Dientes: {dientes_tratados}</p>}
              <div className="flex justify-between font-bold text-sm mt-2">
                <span>TOTAL USD:</span><span>${Number(monto_usd).toFixed(2)}</span>
              </div>
              {total_ves > 0 && (
                <div className="flex justify-between text-[11px] text-gray-700 mt-1">
                  <span>TOTAL BS:</span><span>Bs. {Number(total_ves).toLocaleString('es-VE', { minimumFractionDigits: 2 })}</span>
                </div>
              )}
              {total_cop > 0 && (
                <div className="flex justify-between text-[11px] text-gray-700">
                  <span>TOTAL COP:</span><span>$ {Number(total_cop).toLocaleString('es-CO')}</span>
                </div>
              )}
            </div>

            <div className="pt-2 text-[10px] text-gray-600">
              <p>PAGO: {metodo_pago.toUpperCase()}</p>
            </div>

            <div className="mt-4 pt-3 border-t border-dashed border-gray-300 text-center text-[10px] text-gray-500">
              <p className="font-bold">{config.mensaje_recibo}</p>
              <p className="mt-1 text-[9px]">*** GRACIAS POR SU VISITA ***</p>
            </div>
          </div>
        )}

      </div>
    </div>
  )
}
