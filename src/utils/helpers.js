export const fmt = (amount, cur = 'USD') => {
  const n = Number(amount || 0)
  if (cur === 'VES') return `Bs. ${n.toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
  if (cur === 'COP') return `COP ${n.toLocaleString('es-CO', { minimumFractionDigits: 0 })}`
  return `$ ${n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}

export const formatDate = (d) => {
  if (!d) return ''
  return new Date(d).toLocaleDateString('es-VE', { day: '2-digit', month: 'short', year: 'numeric' })
}

export const formatDateTime = (d) => {
  if (!d) return ''
  return new Date(d).toLocaleString('es-VE', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
}
