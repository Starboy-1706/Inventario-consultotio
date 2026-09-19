export default async function handler(req, res) {
  // Permitir CORS por si se consulta externamente
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Methods', 'GET')
  res.setHeader('Cache-Control', 's-maxage=300, stale-while-revalidate')

  let ves = null
  let cop = null
  let bcvDate = new Date().toISOString()
  let copDate = new Date().toISOString()

  // 1. Obtener BCV Oficial
  try {
    const r = await fetch('https://ve.dolarapi.com/v1/dolares/oficial', { headers: { 'User-Agent': 'Mozilla/5.0' } })
    if (r.ok) {
      const d = await r.json()
      const val = Number(d.promedio || d.precio)
      if (val > 10 && val < 1000) {
        ves = val
        bcvDate = d.fechaActualizacion || bcvDate
      }
    }
  } catch (e) {
    console.warn('Fallo DolarAPI VE en servidor')
  }

  if (!ves) {
    try {
      const r = await fetch('https://pydolarve.org/api/v1/dollar?page=bcv', { headers: { 'User-Agent': 'Mozilla/5.0' } })
      if (r.ok) {
        const d = await r.json()
        const val = Number(d?.monitors?.usd?.price)
        if (val > 10 && val < 1000) {
          ves = val
          bcvDate = d?.datetime?.date || bcvDate
        }
      }
    } catch (e) {}
  }

  // 2. Obtener TRM Oficial Colombia
  try {
    const r = await fetch('https://co.dolarapi.com/v1/dolares/oficial', { headers: { 'User-Agent': 'Mozilla/5.0' } })
    if (r.ok) {
      const d = await r.json()
      const val = Number(d.promedio || d.precio)
      if (val > 2000 && val < 10000) {
        cop = val
        copDate = d.fechaActualizacion || copDate
      }
    }
  } catch (e) {}

  if (!cop) {
    try {
      const r = await fetch('https://open.er-api.com/v6/latest/USD')
      if (r.ok) {
        const d = await r.json()
        if (d?.rates?.COP) cop = Number(d.rates.COP)
      }
    } catch (e) {}
  }

  return res.status(200).json({
    VES: ves || 68.50,
    COP: cop || 4200.00,
    bcvDate,
    copDate,
    fuente: 'BCV Oficial / TRM Colombia'
  })
}
