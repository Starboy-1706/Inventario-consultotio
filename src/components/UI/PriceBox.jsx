import { useCurrency } from '../../context/CurrencyContext'
import { fmt } from '../../utils/helpers'

export default function PriceBox({ usd, className = '', showAll = false }) {
  const { rates, activeCur } = useCurrency()
  const amountUSD = Number(usd || 0)
  const amountVES = amountUSD * rates.VES
  const amountCOP = amountUSD * rates.COP

  if (showAll) {
    return (
      <div className={`space-y-0.5 ${className}`}>
        <div className="font-bold text-teal-700">{fmt(amountUSD, 'USD')}</div>
        <div className="text-xs text-slate-500 font-medium">{fmt(amountVES, 'VES')}</div>
        <div className="text-[11px] text-amber-700 font-medium">{fmt(amountCOP, 'COP')}</div>
      </div>
    )
  }

  return (
    <span className={className}>
      {activeCur === 'USD' && fmt(amountUSD, 'USD')}
      {activeCur === 'VES' && fmt(amountVES, 'VES')}
      {activeCur === 'COP' && fmt(amountCOP, 'COP')}
    </span>
  )
}
