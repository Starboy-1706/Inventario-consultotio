import * as XLSX from 'xlsx'

/**
 * Exporta un array de objetos a un archivo Excel (.xlsx) estándar
 */
export function exportarAExcel(datos, nombreArchivo = 'Reporte', nombreHoja = 'Datos') {
  if (!datos || datos.length === 0) {
    alert('No hay datos disponibles para exportar.')
    return
  }

  const worksheet = XLSX.utils.json_to_sheet(datos)
  const workbook = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(workbook, worksheet, nombreHoja)
  
  XLSX.writeFile(workbook, `${nombreArchivo}_${new Date().toISOString().split('T')[0]}.xlsx`)
}

/**
 * Genera un Excel formateado profesionalmente para un Recibo / Factura Médica
 */
export function exportarReciboAExcel(data, consultorio) {
  const config = consultorio || {
    nombre: 'CONSULTORIO ODONTOLÓGICO INTEGRAL',
    rif_nit: 'J-12345678-0',
    telefono: '+58 412-000-0000',
    direccion: 'Av. Principal, Centro Médico Profesional'
  }

  const baseImponible = Number(data.subtotal_usd || data.monto_usd || 0)
  const iva = Number(data.impuesto_usd || baseImponible * 0.16)
  const totalUSD = baseImponible + iva
  const totalVES = Number(data.total_ves || (totalUSD * (data.tasa_ves || 1)))

  const encabezado = [
    [config.nombre],
    [`RIF: ${config.rif_nit}`, '', `COMPROBANTE N°: ${data.factura || data.id || '0001'}`],
    [`Dirección: ${config.direccion}`, '', `FECHA: ${data.fecha || new Date().toLocaleDateString('es-VE')}`],
    [`Teléfono: ${config.telefono}`, '', `FORMA DE PAGO: ${(data.metodo_pago || 'EFECTIVO').toUpperCase()}`],
    [],
    ['DATOS DEL PACIENTE / CLIENTE', '', 'MÉDICO / PROFESIONAL TRATANTE'],
    [`Nombre: ${data.paciente_nombre || 'N/A'}`, '', `Dr(a): ${data.doctor_nombre || 'Tratante'}`],
    [`C.I. / RIF: ${data.paciente_cedula || 'N/A'}`, '', `Diagnóstico: ${data.diagnostico || 'N/A'}`],
    [`Teléfono: ${data.paciente_telefono || 'N/A'}`],
    [],
    ['CANT.', 'DESCRIPCIÓN DEL PROCEDIMIENTO / TRATAMIENTO', 'PIEZAS DENTALES', 'PRECIO UNIT. (USD)', 'TOTAL (USD)'],
    [
      1,
      data.procedimiento || 'Consulta Médica General',
      data.dientes_tratados || 'N/A',
      baseImponible.toFixed(2),
      baseImponible.toFixed(2)
    ],
    [],
    ['', '', '', 'SUBTOTAL (USD):', `$${baseImponible.toFixed(2)}`],
    ['', '', '', 'I.V.A. (16%):', `$${iva.toFixed(2)}`],
    ['', '', '', 'TOTAL FACTURA (USD):', `$${totalUSD.toFixed(2)}`],
    ['', '', '', 'TOTAL EN BOLÍVARES (VES):', `Bs. ${totalVES.toLocaleString('es-VE', { minimumFractionDigits: 2 })}`]
  ]

  if (data.total_cop > 0) {
    encabezado.push(['', '', '', 'TOTAL EN PESOS (COP):', `$ ${Number(data.total_cop).toLocaleString('es-CO')}`])
  }

  const worksheet = XLSX.utils.aoa_to_sheet(encabezado)

  // Ajuste automático de ancho de columnas
  worksheet['!cols'] = [
    { wch: 10 },
    { wch: 45 },
    { wch: 20 },
    { wch: 20 },
    { wch: 22 }
  ]

  const workbook = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(workbook, worksheet, 'Recibo Fiscal')

  const nombreArchivo = `Recibo_${data.factura || '001'}_${(data.paciente_nombre || 'Paciente').replace(/\s+/g, '_')}.xlsx`
  XLSX.writeFile(workbook, nombreArchivo)
}
