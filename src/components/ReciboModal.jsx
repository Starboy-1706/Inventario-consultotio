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

  // GENERADOR DE IMPRESIÓN DIRECTA E INDEPENDIENTE
  const handlePrint = () => {
    const printWindow = window.open('', '_blank', 'width=850,height=900')
    if (!printWindow) {
      alert('Por favor permite las ventanas emergentes (pop-ups) para imprimir el recibo.')
      return
    }

    const htmlContent = `
      <!DOCTYPE html>
      <html lang="es">
      <head>
        <meta charset="UTF-8">
        <title>Recibo #${factura}</title>
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; }
          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            color: #1f2937;
            background: #ffffff;
            -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
          }

          ${formato === 'ticket' ? `
            /* ESTILOS TICKET 80MM */
            @page { size: 80mm auto; margin: 0; }
            body { width: 72mm; margin: 0 auto; padding: 10px 4px; font-family: monospace; font-size: 11px; }
            .ticket-header { text-align: center; border-bottom: 1px dashed #9ca3af; padding-bottom: 8px; margin-bottom: 8px; }
            .ticket-title { font-size: 13px; font-weight: bold; text-transform: uppercase; }
            .ticket-row { display: flex; justify-content: space-between; margin-bottom: 3px; font-size: 11px; }
            .ticket-total { font-size: 14px; font-weight: bold; border-top: 1px dashed #9ca3af; border-bottom: 1px dashed #9ca3af; padding: 6px 0; margin: 8px 0; }
            .ticket-footer { text-align: center; font-size: 10px; color: #4b5563; margin-top: 12px; }
          ` : `
            /* ESTILOS CARTA / A4 */
            @page { size: letter portrait; margin: 15mm; }
            body { max-width: 800px; margin: 0 auto; padding: 20px; font-size: 13px; }
            .header { display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid #2563eb; padding-bottom: 16px; margin-bottom: 20px; }
            .clinic-name { font-size: 20px; font-weight: bold; color: #111827; }
            .doc-tag { background: #eff6ff; color: #1d4ed8; font-weight: bold; font-size: 11px; text-transform: uppercase; padding: 4px 10px; border-radius: 9999px; border: 1px solid #bfdbfe; display: inline-block; margin-bottom: 6px; }
            .info-box { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; background: #f9fafb; border: 1px solid #e5e7eb; border-radius: 10px; padding: 14px; margin-bottom: 20px; }
            .info-title { font-size: 10px; font-weight: bold; text-transform: uppercase; color: #6b7280; margin-bottom: 2px; }
            table { width: 100%; border-collapse: collapse; margin-bottom: 20px; border: 1px solid #e5e7eb; border-radius: 8px; overflow: hidden; }
            th { background: #f3f4f6; color: #374151; font-size: 11px; text-transform: uppercase; padding: 10px; text-align: left; border-bottom: 1px solid #e5e7eb; }
            td { padding: 12px 10px; border-bottom: 1px solid #e5e7eb; vertical-align: top; }
            .totals-container { display: flex; justify-content: space-between; align-items: flex-start; gap: 20px; border-top: 1px solid #e5e7eb; padding-top: 14px; }
            .total-row { display: flex; justify-content: space-between; font-size: 12px; margin-bottom: 4px; }
            .total-usd { font-size: 16px; font-weight: bold; color: #1d4ed8; border-top: 1px solid #e5e7eb; padding-top: 6px; margin-top: 6px; }
            .alt-currency { background: #f9fafb; padding: 6px 8px; border-radius: 6px; margin-top: 4px; font-weight: 600; font-size: 11px; color: #374151; }
            .footer { text-align: center; font-size: 11px; color: #6b7280; border-top: 1px solid #e5e7eb; padding-top: 16px; margin-top: 30px; }
          `}
        </style>
      </head>
      <body>
        ${formato === 'ticket' ? `
          <!-- CONTENIDO TICKET -->
          <div class="ticket-header">
            <div class="ticket-title">${config.nombre}</div>
            <div>RIF: ${config.rif_nit}</div>
            <div>${config.direccion}</div>
            <div>Tel: ${config.telefono}</div>
          </div>

          <div style="border-bottom: 1px dashed #9ca3af; padding-bottom: 6px; margin-bottom: 6px;">
            <div class="ticket-row"><span>RECIBO:</span><strong>#${factura}</strong></div>
            <div class="ticket-row"><span>FECHA:</span><span>${fecha}</span></div>
            <div class="ticket-row"><span>PACIENTE:</span><span>${paciente_nombre}</span></div>
            <div class="ticket-row"><span>C.I./DOC:</span><span>${paciente_cedula}</span></div>
            <div class="ticket-row"><span>MÉDICO:</span><span>${doctor_nombre}</span></div>
          </div>

          <div style="margin-bottom: 6px;">
            <div style="font-weight: bold; margin-bottom: 2px;">${procedimiento}</div>
            ${dientes_tratados ? `<div>Dientes: ${dientes_tratados}</div>` : ''}
          </div>

          <div class="ticket-total">
            <div class="ticket-row" style="font-size: 13px;">
              <span>TOTAL USD:</span>
              <span>$${Number(monto_usd).toFixed(2)}</span>
            </div>
            ${total_ves > 0 ? `
              <div class="ticket-row" style="font-size: 11px; font-weight: normal; margin-top: 3px;">
                <span>TOTAL BS:</span>
                <span>Bs. ${Number(total_ves).toLocaleString('es-VE', { minimumFractionDigits: 2 })}</span>
              </div>
            ` : ''}
            ${total_cop > 0 ? `
              <div class="ticket-row" style="font-size: 11px; font-weight: normal;">
                <span>TOTAL COP:</span>
                <span>$ ${Number(total_cop).toLocaleString('es-CO')}</span>
              </div>
            ` : ''}
          </div>

          <div class="ticket-row" style="margin-bottom: 8px;">
            <span>PAGO:</span>
            <span>${metodo_pago.toUpperCase()}</span>
          </div>

          <div class="ticket-footer">
            <div>${config.mensaje_recibo}</div>
            <div style="margin-top: 4px;">*** GRACIAS POR SU VISITA ***</div>
          </div>
        ` : `
          <!-- CONTENIDO CARTA -->
          <div class="header">
            <div>
              <div class="clinic-name">🏥 ${config.nombre}</div>
              <div style="font-size: 12px; color: #6b7280; margin-top: 3px;">RIF / NIT: ${config.rif_nit}</div>
              <div style="font-size: 12px; color: #6b7280;">${config.direccion}</div>
              <div style="font-size: 12px; color: #6b7280;">Tel: ${config.telefono} | ${config.email}</div>
            </div>
            <div style="text-align: right;">
              <div class="doc-tag">Comprobante de Pago</div>
              <div style="font-size: 17px; font-weight: bold; font-family: monospace;">#${factura}</div>
              <div style="font-size: 12px; color: #6b7280; margin-top: 2px;">Fecha: ${fecha}</div>
            </div>
          </div>

          <div class="info-box">
            <div>
              <div class="info-title">Paciente</div>
              <div style="font-size: 14px; font-weight: bold; color: #111827;">${paciente_nombre}</div>
              <div style="color: #4b5563;">Doc / Cédula: ${paciente_cedula}</div>
              ${paciente_telefono ? `<div style="color: #4b5563;">Tel: ${paciente_telefono}</div>` : ''}
            </div>
            <div style="text-align: right;">
              <div class="info-title">Profesional Tratante</div>
              <div style="font-size: 14px; font-weight: bold; color: #111827;">${doctor_nombre}</div>
              <div style="color: #059669; font-weight: 600; margin-top: 2px;">✓ Pago Verificado</div>
            </div>
          </div>

          <table>
            <thead>
              <tr>
                <th>Descripción / Tratamiento</th>
                <th style="text-align: center; width: 140px;">Piezas / Dientes</th>
                <th style="text-align: right; width: 140px;">Monto USD</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>
                  <div style="font-weight: 600; color: #111827;">${procedimiento}</div>
                  ${diagnostico ? `<div style="font-size: 11px; color: #6b7280; margin-top: 2px;">${diagnostico}</div>` : ''}
                </td>
                <td style="text-align: center; font-family: monospace; color: #4b5563;">
                  ${dientes_tratados || '—'}
                </td>
                <td style="text-align: right; font-weight: bold; color: #111827;">
                  $${Number(subtotal_usd || monto_usd).toFixed(2)}
                </td>
              </tr>
            </tbody>
          </table>

          <div class="totals-container">
            <div style="font-size: 12px; color: #4b5563; max-width: 320px;">
              <div><strong>Método de Pago:</strong> ${metodo_pago}</div>
              ${tasa_ves > 0 ? `<div><strong>Tasa VES:</strong> Bs. ${Number(tasa_ves).toFixed(2)}</div>` : ''}
              ${tasa_cop > 0 ? `<div><strong>Tasa COP:</strong> $ ${Number(tasa_cop).toFixed(2)}</div>` : ''}
            </div>
            <div style="width: 260px;">
              <div class="total-row">
                <span style="color: #6b7280;">Subtotal:</span>
                <span>$${Number(subtotal_usd || monto_usd).toFixed(2)}</span>
              </div>
              ${impuesto_usd > 0 ? `
                <div class="total-row">
                  <span style="color: #6b7280;">Impuesto:</span>
                  <span>$${Number(impuesto_usd).toFixed(2)}</span>
                </div>
              ` : ''}
              <div class="total-row total-usd">
                <span>TOTAL USD:</span>
                <span>$${Number(monto_usd).toFixed(2)}</span>
              </div>
              ${total_ves > 0 ? `
                <div class="total-row alt-currency">
                  <span>Equivalente VES:</span>
                  <span>Bs. ${Number(total_ves).toLocaleString('es-VE', { minimumFractionDigits: 2 })}</span>
                </div>
              ` : ''}
              ${total_cop > 0 ? `
                <div class="total-row alt-currency">
                  <span>Equivalente COP:</span>
                  <span>$ ${Number(total_cop).toLocaleString('es-CO')}</span>
                </div>
              ` : ''}
            </div>
          </div>

          <div class="footer">
            <div style="font-weight: 500; color: #4b5563;">${config.mensaje_recibo}</div>
            <div style="font-size: 10px; margin-top: 4px;">Comprobante de atención médica generado electrónicamente.</div>
          </div>
        `}
      </body>
      </html>
    `

    printWindow.document.open()
    printWindow.document.write(htmlContent)
    printWindow.document.close()

    // Ejecutar impresión automática al cargar la ventana
    printWindow.onload = () => {
      printWindow.focus()
      printWindow.print()
    }
  }

  const handleWhatsApp = () => {
    const phone = String(paciente_telefono).replace(/[^0-9]/g, '')
    const mensaje = `Hola *${paciente_nombre}*, le compartimos su recibo médico de *${config.nombre}*:%0A%0A` +
      `🧾 *Comprobante:* #${factura}%0A` +
      `📅 *Fecha:* ${fecha}%0A` +
      `🩺 *Tratamiento:* ${procedimiento}%0A` +
      (dientes_tratados ? `🦷 *Dientes:* ${dientes_tratados}%0A` : '') +
      `💵 *Monto Total:* $${Number(monto_usd).toFixed(2)} USD` +
      (total_ves > 0 ? ` (Bs. ${Number(total_ves).toLocaleString('es-VE')})` : '') +
      (total_cop > 0 ? ` ($ ${Number(total_cop).toLocaleString('es-CO')} COP)` : '') + `%0A` +
      `💳 *Forma de Pago:* ${metodo_pago}%0A%0A` +
      `_${config.mensaje_recibo}_`

    window.open(`https://wa.me/${phone}?text=${mensaje}`, '_blank')
  }

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4 overflow-y-auto">
      <div className="bg-white dark:bg-gray-800 w-full max-w-2xl rounded-2xl shadow-2xl border border-gray-200 dark:border-gray-700 overflow-hidden">
        
        {/* Barra superior de controles */}
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
              className="bg-blue-600 hover:bg-blue-700 text-white text-xs font-bold px-4 py-1.5 rounded-lg inline-flex items-center gap-1.5 transition-colors shadow-sm cursor-pointer"
            >
              <Printer className="w-4 h-4" /> Imprimir Recibo
            </button>
            <button
              onClick={onClose}
              className="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 p-1.5 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Vista previa en pantalla (Formato Carta) */}
        {formato === 'carta' && (
          <div className="p-8 bg-white text-gray-800 font-sans max-h-[75vh] overflow-y-auto">
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
                <p className="text-xs font-semibold text-gray-400 uppercase">Profesional</p>
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
          </div>
        )}

        {/* Vista previa en pantalla (Formato Ticket) */}
        {formato === 'ticket' && (
          <div className="p-6 bg-white text-gray-900 font-mono text-xs max-w-[340px] mx-auto border-x border-dashed border-gray-300 my-4 max-h-[75vh] overflow-y-auto">
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
