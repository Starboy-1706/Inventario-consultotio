import React, { useState } from 'react'
import { Printer, X, MessageCircle, FileText, Receipt, FileSpreadsheet } from 'lucide-react'
import { exportarReciboAExcel } from '../utils/exportExcel'

export default function ReciboModal({ isOpen, onClose, data, consultorio }) {
  const [formato, setFormato] = useState('factura')

  if (!isOpen || !data) return null

  const config = consultorio || {
    nombre: 'CONSULTORIO ODONTOLÓGICO INTEGRAL, C.A.',
    rif_nit: 'J-12345678-0',
    telefono: '+58 412-000-00-00',
    direccion: 'Av. Bolívar, Torre Médica Profesional, Piso 3, Of. 3-A, Caracas',
    email: 'admin@consultorio.com',
    mensaje_recibo: 'Este documento es un comprobante de pago válido según las disposiciones del SENIAT.',
    contribuyente: 'CONTRIBUYENTE FORMAL'
  }

  const {
    id,
    fecha = new Date().toLocaleDateString('es-VE'),
    paciente_nombre = 'Paciente General',
    paciente_cedula = 'V-00000000',
    paciente_telefono = '',
    paciente_direccion = '',
    doctor_nombre = 'Dr. Tratante',
    procedimiento = 'Consulta Odontológica General',
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
    factura = id ? `00${String(id).slice(0, 6).toUpperCase()}` : '000001',
    numero_control = id ? `00-${String(id).slice(0, 8).toUpperCase()}` : '00-00000001'
  } = data

  const baseImponible = Number(subtotal_usd || monto_usd)
  const iva = impuesto_usd > 0 ? Number(impuesto_usd) : baseImponible * 0.16
  const exento = 0
  const totalFactura = baseImponible + iva
  const totalBs = total_ves > 0 ? Number(total_ves) : totalFactura * Number(tasa_ves || 1)

  const numeroALetras = (num) => {
    const unidades = ['','UNO','DOS','TRES','CUATRO','CINCO','SEIS','SIETE','OCHO','NUEVE']
    const decenas = ['','DIEZ','VEINTE','TREINTA','CUARENTA','CINCUENTA','SESENTA','SETENTA','OCHENTA','NOVENTA']
    const centenas = ['','CIEN','DOSCIENTOS','TRESCIENTOS','CUATROCIENTOS','QUINIENTOS','SEISCIENTOS','SETECIENTOS','OCHOCIENTOS','NOVECIENTOS']
    const n = Math.floor(num)
    if (n === 0) return 'CERO'
    if (n < 10) return unidades[n]
    if (n < 20) return 'DIECI' + unidades[n - 10]
    if (n < 100) return decenas[Math.floor(n / 10)] + (n % 10 > 0 ? ' Y ' + unidades[n % 10] : '')
    if (n < 1000) return centenas[Math.floor(n / 100)] + (n % 100 > 0 ? ' ' + numeroALetras(n % 100) : '')
    return num.toFixed(2).toString()
  }

  const montoLetras = `${numeroALetras(Math.floor(totalFactura))} DÓLARES CON ${String(Math.round((totalFactura % 1) * 100)).padStart(2, '0')}/100`

  const handlePrint = () => {
    const printWindow = window.open('', '_blank', 'width=900,height=1000')
    if (!printWindow) {
      alert('Permite las ventanas emergentes para imprimir.')
      return
    }

    const html = `
      <!DOCTYPE html>
      <html lang="es">
      <head>
        <meta charset="UTF-8">
        <title>Factura #${factura}</title>
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; }
          body { font-family: "Arial", sans-serif; color: #000; background: #fff; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
          ${formato === 'ticket' ? `
            @page { size: 80mm auto; margin: 0; }
            body { width: 72mm; margin: 0 auto; padding: 8px 3px; font-size: 10px; font-family: monospace; }
            .sep { border-top: 1px dashed #000; margin: 4px 0; }
            .row { display: flex; justify-content: space-between; }
            .center { text-align: center; }
            .bold { font-weight: bold; }
            .small { font-size: 9px; }
            .title { font-size: 12px; font-weight: bold; text-transform: uppercase; }
          ` : `
            @page { size: letter portrait; margin: 10mm 12mm; }
            body { max-width: 210mm; margin: 0 auto; padding: 0; font-size: 11px; }
            .factura-header { display: flex; justify-content: space-between; align-items: flex-start; border: 2px solid #000; padding: 12px 16px; }
            .empresa-info h1 { font-size: 15px; font-weight: bold; margin-bottom: 2px; }
            .empresa-info p { font-size: 10px; color: #333; line-height: 1.4; }
            .rif-box { border: 2px solid #000; padding: 8px 14px; text-align: center; min-width: 180px; }
            .rif-box .label { font-size: 9px; font-weight: bold; text-transform: uppercase; }
            .rif-box .rif-num { font-size: 16px; font-weight: bold; margin: 2px 0; }
            .rif-box .doc-type { font-size: 11px; font-weight: bold; border-top: 1px solid #000; padding-top: 4px; margin-top: 4px; }
            .factura-datos { display: grid; grid-template-columns: 1fr 1fr; border: 2px solid #000; border-top: none; }
            .factura-datos .col { padding: 8px 12px; }
            .factura-datos .col:first-child { border-right: 1px solid #000; }
            .dato-label { font-size: 9px; font-weight: bold; text-transform: uppercase; color: #555; }
            .dato-valor { font-size: 11px; font-weight: bold; }
            .dato-row { margin-bottom: 3px; }
            .tabla-items { width: 100%; border-collapse: collapse; border: 2px solid #000; border-top: none; }
            .tabla-items th { background: #000; color: #fff; font-size: 9px; text-transform: uppercase; padding: 6px 8px; text-align: left; font-weight: bold; }
            .tabla-items td { padding: 8px; border-bottom: 1px solid #ccc; font-size: 11px; }
            .tabla-items .text-right { text-align: right; }
            .tabla-items .text-center { text-align: center; }
            .resumen-fiscal { display: flex; justify-content: space-between; border: 2px solid #000; border-top: none; }
            .resumen-izq { flex: 1; padding: 8px 12px; border-right: 1px solid #000; }
            .resumen-der { width: 280px; padding: 8px 12px; }
            .fiscal-row { display: flex; justify-content: space-between; font-size: 11px; margin-bottom: 2px; }
            .fiscal-total { font-size: 14px; font-weight: bold; border-top: 2px solid #000; padding-top: 4px; margin-top: 4px; }
            .monto-letras { font-size: 9px; font-style: italic; color: #333; margin-top: 4px; padding: 4px; background: #f5f5f5; border: 1px solid #ccc; }
            .pie-fiscal { border: 2px solid #000; border-top: none; padding: 8px 12px; text-align: center; font-size: 9px; color: #333; }
            .pie-fiscal .contribuyente { font-weight: bold; font-size: 10px; color: #000; }
          `}
        </style>
      </head>
      <body>
        ${formato === 'ticket' ? `
          <div class="center">
            <div class="title">${config.nombre}</div>
            <div>RIF: ${config.rif_nit}</div>
            <div class="small">${config.direccion}</div>
            <div class="small">Tel: ${config.telefono}</div>
          </div>
          <div class="sep"></div>
          <div class="row bold"><span>FACTURA</span><span>#${factura}</span></div>
          <div class="row"><span>CONTROL:</span><span>${numero_control}</span></div>
          <div class="row"><span>FECHA:</span><span>${fecha}</span></div>
          <div class="sep"></div>
          <div class="row"><span>CLIENTE:</span><span>${paciente_nombre}</span></div>
          <div class="row"><span>RIF/CI:</span><span>${paciente_cedula}</span></div>
          <div class="sep"></div>
          <div class="bold">${procedimiento}</div>
          ${dientes_tratados ? `<div class="small">Dientes: ${dientes_tratados}</div>` : ''}
          <div class="sep"></div>
          <div class="row"><span>BASE IMP.:</span><span>$${baseImponible.toFixed(2)}</span></div>
          <div class="row"><span>IVA 16%:</span><span>$${iva.toFixed(2)}</span></div>
          <div class="row bold" style="font-size:12px;"><span>TOTAL USD:</span><span>$${totalFactura.toFixed(2)}</span></div>
          ${totalBs > 0 ? `<div class="row"><span>TOTAL BS:</span><span>Bs. ${totalBs.toLocaleString('es-VE', {minimumFractionDigits:2})}</span></div>` : ''}
          <div class="sep"></div>
          <div class="row"><span>PAGO:</span><span>${metodo_pago.toUpperCase()}</span></div>
          <div class="sep"></div>
          <div class="center small" style="margin-top:6px;">
            <div class="bold">${config.contribuyente}</div>
            <div>${config.mensaje_recibo}</div>
            <div style="margin-top:4px;">*** GRACIAS POR SU VISITA ***</div>
          </div>
        ` : `
          <div class="factura-header">
            <div class="empresa-info">
              <h1>🏥 ${config.nombre}</h1>
              <p>${config.direccion}</p>
              <p>Tel: ${config.telefono} | Email: ${config.email}</p>
            </div>
            <div class="rif-box">
              <div class="label">R.I.F.</div>
              <div class="rif-num">${config.rif_nit}</div>
              <div class="doc-type">FACTURA</div>
            </div>
          </div>

          <div class="factura-datos">
            <div class="col">
              <div class="dato-row"><span class="dato-label">Cliente / Paciente:</span> <span class="dato-valor">${paciente_nombre}</span></div>
              <div class="dato-row"><span class="dato-label">RIF / C.I.:</span> <span class="dato-valor">${paciente_cedula}</span></div>
              <div class="dato-row"><span class="dato-label">Dirección:</span> <span class="dato-valor">${paciente_direccion || 'No especificada'}</span></div>
              <div class="dato-row"><span class="dato-label">Teléfono:</span> <span class="dato-valor">${paciente_telefono || 'N/A'}</span></div>
            </div>
            <div class="col">
              <div class="dato-row"><span class="dato-label">Nº Factura:</span> <span class="dato-valor">${factura}</span></div>
              <div class="dato-row"><span class="dato-label">Nº Control:</span> <span class="dato-valor">${numero_control}</span></div>
              <div class="dato-row"><span class="dato-label">Fecha Emisión:</span> <span class="dato-valor">${fecha}</span></div>
              <div class="dato-row"><span class="dato-label">Profesional:</span> <span class="dato-valor">${doctor_nombre}</span></div>
              ${tasa_ves > 0 ? `<div class="dato-row"><span class="dato-label">Tasa BCV (Bs/USD):</span> <span class="dato-valor">Bs. ${Number(tasa_ves).toFixed(2)}</span></div>` : ''}
            </div>
          </div>

          <table class="tabla-items">
            <thead>
              <tr>
                <th style="width:40px;">Cant.</th>
                <th>Descripción del Servicio</th>
                <th style="width:80px;" class="text-center">Piezas</th>
                <th style="width:100px;" class="text-right">P. Unit. USD</th>
                <th style="width:100px;" class="text-right">Total USD</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td class="text-center">1</td>
                <td><strong>${procedimiento}</strong>${diagnostico ? `<br><span style="font-size:10px;color:#555;">Dx: ${diagnostico}</span>` : ''}</td>
                <td class="text-center" style="font-family:monospace;">${dientes_tratados || '—'}</td>
                <td class="text-right">$${baseImponible.toFixed(2)}</td>
                <td class="text-right"><strong>$${baseImponible.toFixed(2)}</strong></td>
              </tr>
              <tr><td colspan="5" style="height:40px;border:none;"></td></tr>
            </tbody>
          </table>

          <div class="resumen-fiscal">
            <div class="resumen-izq">
              <div class="monto-letras"><strong>SON:</strong> ${montoLetras}</div>
              <div style="margin-top:6px;"><span class="dato-label">Forma de Pago:</span> <span class="dato-valor">${metodo_pago.toUpperCase()}</span></div>
            </div>
            <div class="resumen-der">
              <div class="fiscal-row"><span>Base Imponible:</span><span>$${baseImponible.toFixed(2)}</span></div>
              <div class="fiscal-row"><span>Exento / Exonerado:</span><span>$${exento.toFixed(2)}</span></div>
              <div class="fiscal-row"><span>Sub-Total:</span><span>$${baseImponible.toFixed(2)}</span></div>
              <div class="fiscal-row"><span>I.V.A. (16%):</span><span>$${iva.toFixed(2)}</span></div>
              <div class="fiscal-row fiscal-total"><span>TOTAL FACTURA (USD):</span><span>$${totalFactura.toFixed(2)}</span></div>
              ${totalBs > 0 ? `<div class="fiscal-row" style="font-weight:bold;"><span>TOTAL (Bs.):</span><span>Bs. ${totalBs.toLocaleString('es-VE', {minimumFractionDigits:2})}</span></div>` : ''}
              ${total_cop > 0 ? `<div class="fiscal-row" style="color:#555;"><span>Ref. COP:</span><span>$ ${Number(total_cop).toLocaleString('es-CO')}</span></div>` : ''}
            </div>
          </div>

          <div class="pie-fiscal">
            <div class="contribuyente">${config.contribuyente}</div>
            <div style="margin-top:3px;">${config.mensaje_recibo}</div>
            <div style="margin-top:2px;">Providencia Administrativa N° 0071 del SENIAT.</div>
          </div>
        `}
      </body>
      </html>
    `

    printWindow.document.open()
    printWindow.document.write(html)
    printWindow.document.close()
    printWindow.onload = () => { printWindow.focus(); printWindow.print() }
  }

  const handleExcel = () => {
    exportarReciboAExcel(data, config)
  }

  const handleWhatsApp = () => {
    const phone = String(paciente_telefono).replace(/[^0-9]/g, '')
    const msg = `*${config.nombre}*%0ARIF: ${config.rif_nit}%0A%0A` +
      `FACTURA N° ${factura}%0A` +
      `Fecha: ${fecha}%0A%0A` +
      `Estimado/a *${paciente_nombre}*:%0A` +
      `🩺 ${procedimiento}%0A` +
      (dientes_tratados ? `🦷 Dientes: ${dientes_tratados}%0A` : '') +
      `%0A💰 Base: $${baseImponible.toFixed(2)}%0A` +
      `📊 IVA 16%: $${iva.toFixed(2)}%0A` +
      `✅ *TOTAL: $${totalFactura.toFixed(2)}*%0A` +
      (totalBs > 0 ? `(Bs. ${totalBs.toLocaleString('es-VE', {minimumFractionDigits:2})})%0A` : '') +
      `💳 Pago: ${metodo_pago}%0A%0A` +
      `_${config.contribuyente}_%0A${config.mensaje_recibo}`
    window.open(`https://wa.me/${phone}?text=${msg}`, '_blank')
  }

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4 overflow-y-auto">
      <div className="bg-white w-full max-w-3xl rounded-2xl shadow-2xl border border-gray-200 overflow-hidden">
        
        {/* Barra superior con botón de Excel */}
        <div className="p-4 bg-gray-50 border-b flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center bg-gray-200 p-1 rounded-xl text-xs font-semibold">
            <button onClick={() => setFormato('factura')} className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg ${formato === 'factura' ? 'bg-white shadow-sm text-blue-600 font-bold' : 'text-gray-500'}`}>
              <FileText className="w-3.5 h-3.5" /> Factura SENIAT
            </button>
            <button onClick={() => setFormato('ticket')} className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg ${formato === 'ticket' ? 'bg-white shadow-sm text-blue-600 font-bold' : 'text-gray-500'}`}>
              <Receipt className="w-3.5 h-3.5" /> Ticket 80mm
            </button>
          </div>

          <div className="flex items-center gap-2">
            <button onClick={handleExcel} className="bg-green-700 hover:bg-green-800 text-white text-xs font-bold px-3 py-1.5 rounded-lg inline-flex items-center gap-1.5 shadow-sm transition-colors cursor-pointer" title="Descargar en Excel .xlsx">
              <FileSpreadsheet className="w-4 h-4" /> Excel (.xlsx)
            </button>
            {paciente_telefono && (
              <button onClick={handleWhatsApp} className="bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-medium px-3 py-1.5 rounded-lg inline-flex items-center gap-1.5">
                <MessageCircle className="w-4 h-4" /> WhatsApp
              </button>
            )}
            <button onClick={handlePrint} className="bg-blue-600 hover:bg-blue-700 text-white text-xs font-bold px-4 py-1.5 rounded-lg inline-flex items-center gap-1.5">
              <Printer className="w-4 h-4" /> Imprimir
            </button>
            <button onClick={onClose} className="text-gray-400 hover:text-gray-600 p-1.5 rounded-lg hover:bg-gray-100">
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Vista previa en pantalla */}
        <div className="p-6 max-h-[75vh] overflow-y-auto bg-gray-100">
          <div className="bg-white max-w-[800px] mx-auto shadow-lg border-2 border-black p-0 text-[11px] font-sans text-black">
            <div className="flex justify-between items-start border-b-2 border-black p-4">
              <div>
                <h1 className="text-base font-bold">🏥 {config.nombre}</h1>
                <p className="text-[10px] text-gray-600">{config.direccion}</p>
                <p className="text-[10px] text-gray-600">Tel: {config.telefono}</p>
              </div>
              <div className="border-2 border-black p-2 text-center min-w-[140px]">
                <p className="text-[9px] font-bold">R.I.F.</p>
                <p className="text-sm font-bold">{config.rif_nit}</p>
                <p className="text-[10px] font-bold border-t border-black mt-1 pt-1">FACTURA</p>
              </div>
            </div>
            <div className="grid grid-cols-2 border-b-2 border-black">
              <div className="p-3 border-r border-black space-y-1">
                <p><strong>Cliente:</strong> {paciente_nombre}</p>
                <p><strong>RIF/CI:</strong> {paciente_cedula}</p>
                <p><strong>Tel:</strong> {paciente_telefono || 'N/A'}</p>
              </div>
              <div className="p-3 space-y-1">
                <p><strong>N° Factura:</strong> {factura}</p>
                <p><strong>N° Control:</strong> {numero_control}</p>
                <p><strong>Fecha:</strong> {fecha}</p>
                {tasa_ves > 0 && <p><strong>Tasa BCV:</strong> Bs. {Number(tasa_ves).toFixed(2)}</p>}
              </div>
            </div>
            <table className="w-full border-collapse">
              <thead><tr className="bg-black text-white text-[9px] uppercase">
                <th className="p-2 text-left">Descripción</th>
                <th className="p-2 text-center w-16">Piezas</th>
                <th className="p-2 text-right w-24">P.Unit</th>
                <th className="p-2 text-right w-24">Total</th>
              </tr></thead>
              <tbody>
                <tr className="border-b">
                  <td className="p-2"><strong>{procedimiento}</strong>{diagnostico && <span className="text-[10px] text-gray-500 block">Dx: {diagnostico}</span>}</td>
                  <td className="p-2 text-center font-mono">{dientes_tratados || '—'}</td>
                  <td className="p-2 text-right">${baseImponible.toFixed(2)}</td>
                  <td className="p-2 text-right font-bold">${baseImponible.toFixed(2)}</td>
                </tr>
              </tbody>
            </table>
            <div className="flex border-t-2 border-black">
              <div className="flex-1 p-3 border-r border-black">
                <p className="text-[9px] italic bg-gray-100 p-1 border"><strong>SON:</strong> {montoLetras}</p>
                <p className="mt-2"><strong>Pago:</strong> {metodo_pago}</p>
              </div>
              <div className="w-64 p-3 space-y-1">
                <div className="flex justify-between"><span>Base Imponible:</span><span>${baseImponible.toFixed(2)}</span></div>
                <div className="flex justify-between"><span>IVA 16%:</span><span>${iva.toFixed(2)}</span></div>
                <div className="flex justify-between font-bold text-sm border-t-2 border-black pt-1 mt-1"><span>TOTAL USD:</span><span>${totalFactura.toFixed(2)}</span></div>
                {totalBs > 0 && <div className="flex justify-between font-bold"><span>Total Bs.:</span><span>Bs. {totalBs.toLocaleString('es-VE',{minimumFractionDigits:2})}</span></div>}
              </div>
            </div>
            <div className="text-center text-[9px] p-2 border-t-2 border-black bg-gray-50">
              <p className="font-bold">{config.contribuyente}</p>
              <p>{config.mensaje_recibo}</p>
              <p>Providencia Administrativa N° 0071 SENIAT</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
