import { useEffect } from 'react'
import { Html5QrcodeScanner } from 'html5-qrcode'
import { X } from 'lucide-react'

export default function QRScanner({ onScan, onClose }) {
  useEffect(() => {
    const scanner = new Html5QrcodeScanner(
      'qr-reader-box',
      { fps: 15, qrbox: { width: 220, height: 220 }, aspectRatio: 1.0 },
      false
    )

    scanner.render(
      (text) => {
        scanner.clear().then(() => onScan(text)).catch(() => onScan(text))
      },
      () => {}
    )

    return () => {
      scanner.clear().catch(() => {})
    }
  }, [onScan])

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-3xl p-6 w-full max-w-md shadow-2xl space-y-4">
        <div className="flex justify-between items-center border-b pb-2">
          <h3 className="font-bold text-sm text-slate-800">Cámara Escáner QR de Insumo</h3>
          <button onClick={onClose} className="p-1 hover:bg-slate-100 rounded-lg text-slate-500"><X className="w-4 h-4" /></button>
        </div>
        <div id="qr-reader-box" className="overflow-hidden rounded-2xl border border-slate-100"></div>
        <p className="text-[11px] text-slate-400 text-center">Coloca el código QR del material frente a la cámara.</p>
      </div>
    </div>
  )
}
