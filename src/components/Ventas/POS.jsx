import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { fmt } from '../../utils/helpers'
import TicketModal from '../UI/TicketModal'
import { ShoppingBag, Trash2, CheckCircle } from 'lucide-react'
import toast from 'react-hot-toast'

export default function POS() {
  const [prods, setProds] = useState([])
  const [cart, setCart] = useState([])
  const [client, setClient] = useState('')
  const [cedula, setCedula] = useState('')
  const [taxId, setTaxId] = useState('')
  const [lastSale, setLastSale] = useState(null)
  const { rates, taxes } = useCurrency()

  const load = async () => {
    const { data } = await supabase.from('productos').select('*, impuestos(porcentaje)').eq('activo', true).eq('es_vendible', true).gt('stock', 0)
    setProds(data || [])
  }
  useEffect(() => { load() }, [])

  const addToCart = (p) => {
    const ex = cart.find(i => i.id === p.id)
    if (ex) {
      if (ex.cant >= p.stock) return toast.error('Sin stock suficiente')
      setCart(cart.map(i => i.id === p.id ? { ...i, cant: i.cant + 1 } : i))
    } else {
      setCart([...cart, { ...p, cant: 1 }])
    }
  }

  const selectedTax = taxes.find(t => t.id === taxId)
  const taxPct = selectedTax ? selectedTax.porcentaje : 0

  const subtotalUSD = cart.reduce((acc, i) => acc + (i.precio_venta * i.cant), 0)
  const taxUSD = subtotalUSD * (taxPct / 100)
  const totalUSD = subtotalUSD + taxUSD

  const checkout = async () => {
    if (!cart.length) return toast.error('El carrito está vacío')
    const fac = `FAC-${Date.now().toString().slice(-6)}`

    const salePayload = {
      factura: fac,
      cliente: client || 'Cliente General',
      cedula_cliente: cedula || null,
      subtotal_usd: subtotalUSD,
      impuesto_usd: taxUSD,
      total_usd: totalUSD,
      total_ves: totalUSD * rates.VES,
      total_cop: totalUSD * rates.COP,
      tasa_ves: rates.VES,
      tasa_cop: rates.COP
    }

    const { data: v, error } = await supabase.from('ventas').insert([salePayload]).select().single()

    if (error) return toast.error('Error al procesar venta')

    for (const item of cart) {
      await supabase.from('productos').update({ stock: item.stock - item.cant }).eq('id', item.id)
      await supabase.from('movimientos').insert({
        producto_id: item.id,
        tipo: 'venta',
        cantidad: -item.cant,
        stock_antes: item.stock,
        stock_despues: item.stock - item.cant,
        referencia: `Factura: ${fac}`
      })
    }

    toast.success(`¡Venta ${fac} procesada!`)
    setLastSale(v)
    setCart([]); setClient(''); setCedula(''); load()
  }

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
      {/* Catálogo */}
      <div className="lg:col-span-2 space-y-4">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Punto de Venta (Insumos Dentales)</h1>
          <p className="text-xs text-slate-400">Seleccione materiales dentales para facturar</p>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
          {prods.map(p => (
            <button key={p.id} onClick={() => addToCart(p)} className="card-box text-left p-3.5 hover:border-teal-500 transition-all group">
              <h4 className="font-bold text-xs text-slate-800 truncate group-hover:text-teal-700">{p.nombre}</h4>
              <p className="text-[10px] text-slate-400 mt-0.5">Stock disponible: {p.stock}</p>
              <div className="mt-3 flex items-center justify-between">
                <span className="font-bold text-sm text-teal-700">{fmt(p.precio_venta, 'USD')}</span>
                <span className="text-[10px] bg-slate-100 text-slate-600 px-2 py-0.5 rounded-full font-bold">Añadir +</span>
              </div>
            </button>
          ))}
        </div>
      </div>

      {/* Ticket / Carrito */}
      <div className="card-pro space-y-4 h-fit border-2 border-slate-100">
        <h2 className="font-bold text-sm text-slate-800 flex items-center gap-2 border-b pb-3">
          <ShoppingBag className="w-4 h-4 text-teal-600" /> Resumen de Venta
        </h2>

        <div className="space-y-2">
          <input placeholder="Nombre del Comprador" value={client} onChange={e => setClient(e.target.value)} className="input-field text-xs" />
          <input placeholder="Cédula / Documento (Opcional)" value={cedula} onChange={e => setCedula(e.target.value)} className="input-field text-xs" />
          <select value={taxId} onChange={e => setTaxId(e.target.value)} className="input-field text-xs">
            <option value="">Impuesto Global (Exento)</option>
            {taxes.map(t => <option key={t.id} value={t.id}>{t.nombre} ({t.porcentaje}%)</option>)}
          </select>
        </div>

        <div className="space-y-2 max-h-52 overflow-y-auto pr-1">
          {cart.map(i => (
            <div key={i.id} className="flex justify-between items-center text-xs bg-slate-50 p-2 rounded-xl">
              <div>
                <p className="font-bold text-slate-800 truncate w-32">{i.nombre}</p>
                <span className="text-slate-400">{fmt(i.precio_venta)} x {i.cant}</span>
              </div>
              <button onClick={() => setCart(cart.filter(x => x.id !== i.id))} className="text-slate-400 hover:text-rose-600">
                <Trash2 className="w-4 h-4" />
              </button>
            </div>
          ))}
        </div>

        {/* Totales */}
        <div className="border-t border-slate-100 pt-3 space-y-1.5 text-xs">
          <div className="flex justify-between text-slate-500"><span>Subtotal:</span><span>{fmt(subtotalUSD, 'USD')}</span></div>
          {taxPct > 0 && (
            <div className="flex justify-between text-teal-700"><span>Impuesto ({taxPct}%):</span><span>{fmt(taxUSD, 'USD')}</span></div>
          )}
          <div className="flex justify-between text-base font-bold text-slate-900 border-t border-slate-100 pt-2">
            <span>Total USD:</span><span>{fmt(totalUSD, 'USD')}</span>
          </div>
          <div className="flex justify-between text-xs font-bold text-teal-700">
            <span>Total Bs. (BCV):</span><span>{fmt(totalUSD * rates.VES, 'VES')}</span>
          </div>
          <div className="flex justify-between text-xs font-bold text-amber-700">
            <span>Total COP:</span><span>{fmt(totalUSD * rates.COP, 'COP')}</span>
          </div>
        </div>

        <button onClick={checkout} className="w-full btn-primary justify-center py-3 shadow-lg shadow-teal-600/10">
          <CheckCircle className="w-4 h-4" /> Finalizar y Emitir Ticket
        </button>
      </div>

      {lastSale && <TicketModal venta={lastSale} onClose={() => setLastSale(null)} />}
    </div>
  )
}
