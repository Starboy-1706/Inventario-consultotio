import { useEffect, useRef } from 'react'
import { Html5QrcodeScanner } from 'html5-qrcode'
import { X } from 'lucide-react'

export default function QRScanner({ onScan, onClose }) {
  const scannerRef = useRef(null)

  useEffect(() => {
    const scanner = new Html5QrcodeScanner(
      'qr-reader-element',
      { 
        fps: 15, 
        qrbox: { width: 250, height: 250 },
        aspectRatio: 1.0
      },
      false
    )

    scanner.render(
      (decodedText) => {
        scanner.clear().then(() => {
          onScan(decodedText)
        }).catch(err => console.error("Error clearing scanner", err))
      },
      (error) => {
        // Ignorar errores de escaneo continuos en vivo
      }
    )

    return () => {
      scanner.clear().catch(err => console.warn("Scanner already cleared", err))
    }
  }, [onScan])

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-3xl p-6 w-full max-w-md shadow-2xl relative space-y-4">
        <div className="flex justify-between items-center border-b pb-2">
          <h3 className="font-bold text-sm text-slate-800">Cámara Escáner QR</h3>
          <button onClick={onClose} className="p-1 hover:bg-slate-100 rounded-lg text-slate-500">
            <X className="w-4 h-4" />
          </button>
        </div>
        
        <div id="qr-reader-element" className="overflow-hidden rounded-2xl border border-slate-100"></div>
        
        <p className="text-[11px] text-slate-400 text-center">
          Coloque el código QR del insumo frente a la cámara para procesarlo de forma automática.
        </p>
      </div>
    </div>
  )
}
