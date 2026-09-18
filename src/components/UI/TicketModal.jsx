import { Printer, X } from 'lucide-react'
import { fmt } from '../../utils/helpers'

export default function TicketModal({ venta, onClose }) {
  if (!venta) return null

  const printTicket = () => {
    window.print()
  }

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-3xl p-6 w-full max-w-sm shadow-2xl space-y-4 text-center">
        <div className="flex justify-between items-center border-b pb-2">
          <span className="text-xs font-bold text-slate-400">COMPROBANTE DE PAGO</span>
          <button onClick={onClose} className="p-1 hover:bg-slate-100 rounded-lg text-slate-500"><X className="w-4 h-4" /></button>
        </div>

        <div className="text-center space-y-1">
          <div className="text-3xl">🦷</div>
          <h2 className="font-bold text-base text-slate-800">CONSULTORIO DENTAL</h2>
          <p className="text-[11px] text-slate-400">Venta de Insumos & Atención Odontológica</p>
          <p className="text-xs font-mono font-bold text-teal-700 pt-1">{venta.factura}</p>
          <p className="text-[10px] text-slate-400">{new Date(venta.created_at || Date.now()).toLocaleString()}</p>
        </div>

        <div className="text-left text-xs bg-slate-50 p-3 rounded-xl space-y-1">
          <p><span className="text-slate-400">Cliente:</span> <b>{venta.cliente}</b></p>
          {venta.cedula_cliente && <p><span className="text-slate-400">Documento:</span> <b>{venta.cedula_cliente}</b></p>}
        </div>

        <div className="space-y-1 text-xs border-t border-b py-2 text-left">
          <div className="flex justify-between text-slate-500"><span>Subtotal:</span><span>{fmt(venta.subtotal_usd, 'USD')}</span></div>
          {Number(venta.impuesto_usd) > 0 && (
            <div className="flex justify-between text-teal-700"><span>Impuestos:</span><span>{fmt(venta.impuesto_usd, 'USD')}</span></div>
          )}
          <div className="flex justify-between text-sm font-bold text-slate-900 pt-1">
            <span>TOTAL USD:</span><span>{fmt(venta.total_usd, 'USD')}</span>
          </div>
          <div className="flex justify-between font-bold text-teal-700">
            <span>TOTAL BS:</span><span>{fmt(venta.total_ves, 'VES')}</span>
          </div>
          <div className="flex justify-between font-bold text-amber-700">
            <span>TOTAL COP:</span><span>{fmt(venta.total_cop, 'COP')}</span>
          </div>
        </div>

        <div className="flex gap-2 pt-2">
          <button onClick={onClose} className="w-1/2 btn-secondary justify-center">Cerrar</button>
          <button onClick={printTicket} className="w-1/2 btn-primary justify-center"><Printer className="w-4 h-4" /> Imprimir</button>
        </div>
      </div>
    </div>
  )
}
