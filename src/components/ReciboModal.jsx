import React, { useState } from 'react'
import { Printer, X, MessageCircle, FileText, Receipt, CheckCircle } from 'lucide-react'

export default function ReciboModal({ isOpen, onClose, data, consultorio }) {
  const [formato, setFormato] = useState('carta')

  if (!isOpen || !data) return null

  const config = consultorio || {
    nombre: 'Consultorio Dental & Médico',
    rif_nit: 'J-12345678-0',
    telefono: '+58 412 000 0000',
    direccion: 'Av. Principal, Centro Profesional',
    email: 'contacto@consultorio.com',
    mensaje_recibo: 'Gracias por su confianza. ¡Cuidamos de su salud y su sonrisa!'
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

  const handlePrint = () => {
    window.print()
  }

  const handleWhatsApp = () => {
    const phone = String(paciente_telefono).replace(/[^0-9]/g, '')
    const mensaje = `Hola *${paciente_nombre}*, le compartimos el resumen de su recibo médico de *${config.nombre}*:%0A%0A` +
      `🧾 *Comprobante:* #${factura}%0A` +
      `📅 *Fecha:* ${fecha}%0A` +
      `🩺 *Tratamiento:* ${procedimiento}%0A` +
      (dientes_tratados ? `🦷 *Dientes:* ${dientes_tratados}%0A` : '') +
      `💵 *Monto:* $${Number(monto_usd).toFixed(2)} USD` +
      (total_ves > 0 ? ` (Bs. ${Number(total_ves).toLocaleString('es-VE')})` : '') +
      (total_cop > 0 ? ` ($ ${Number(total_cop).toLocaleString('es-CO')} COP)` : '') + `%0A` +
      `💳 *Método de Pago:* ${metodo_pago}%0A%0A` +
      `_${config.mensaje_recibo}_`

    window.open(`https://wa.me/${phone}?text=${mensaje}`, '_blank')
  }

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4 overflow-y-auto print:p-0 print:bg-white print:static">
      <div className="bg-white dark:bg-gray-800 w-full max-w-2xl rounded-2xl shadow-2xl border border-gray-200 dark:border-gray-700 overflow-hidden print:border-none print:shadow-none print:w-full print:max-w-none">
        
        {/* Barra superior de controles (Oculta al imprimir) */}
        <div className="p-4 bg-gray-50 dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700 flex flex-wrap items-center justify-between gap-3 print:hidden">
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
              className="bg-blue-600 hover:bg-blue-700 text-white text-xs font-medium px-3 py-1.5 rounded-lg inline-flex items-center gap-1.5 transition-colors shadow-sm"
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

        {/* FORMATO CARTA (A4 / FACTURA FORMAL) */}
        {formato === 'carta' && (
          <div id="area-recibo" className="p-8 bg-white text-gray-800 font-sans print:p-0">
            <div className="flex justify-between items-start border-b-2 border-blue-600 pb-6">
              <div>
                <div className="flex items-center gap-2">
                  <span className="text-2xl">🏥</span>
                  <h1 className="text-xl font-bold text-gray-900">{config.nombre}</h1>
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
                      {diagnostico && <p className="text-xs text-gray-500">{diagnostico}</p>}
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

        {/* FORMATO TICKET TÉRMICO (80MM) */}
        {formato === 'ticket' && (
          <div id="area-recibo-ticket" className="p-6 bg-white text-gray-900 font-mono text-xs max-w-[340px] mx-auto border-x border-dashed border-gray-300 print:border-none print:p-0 print:max-w-none">
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
