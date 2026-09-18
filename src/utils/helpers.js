export const formatCurrency = (val, cur = 'USD') => {
  const n = Number(val || 0)
  if (cur === 'VES') return `Bs. ${n.toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
  if (cur === 'COP') return `COP ${n.toLocaleString('es-CO', { minimumFractionDigits: 0 })}`
  return `$ ${n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}
