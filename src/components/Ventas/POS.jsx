import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { formatCurrency } from '../../utils/helpers'
import { ShoppingCart, Trash2, Check } from 'lucide-react'
import toast from 'react-hot-toast'

export default function POS() {
  const [prods, setProds] = useState([])
  const [cart, setCart] = useState([])
  const [client, setClient] = useState('')
  const { rates } = useCurrency()

  const load = async () => {
    const { data } = await supabase.from('productos').select('*, impuestos(porcentaje)').eq('activo', true).eq('es_vendible', true).gt('stock', 0)
    setProds(data || [])
  }
  useEffect(() => { load() }, [])

  const add = (p) => {
    const ex = cart.find(i => i.id === p.id)
    if (ex) {
      if (ex.cant >= p.stock) return toast.error('Sin stock suficiente')
      setCart(cart.map(i => i.id === p.id ? { ...i, cant: i.cant + 1 } : i))
    } else {
      setCart([...cart, { ...p, cant: 1, taxPct: p.impuestos?.porcentaje || 0 }])
    }
  }

  const subtotal = cart.reduce((acc, i) => acc + (i.precio_venta * i.cant), 0)
  const totalTax = cart.reduce((acc, i) => acc + (i.precio_venta * i.cant * (i.taxPct / 100)), 0)
  const totalUSD = subtotal + totalTax

  const checkout = async () => {
    if (!cart.length) return toast.error('Carrito vacío')
    const fac = `FAC-${Date.now().toString().slice(-6)}`

    const { error } = await supabase.from('ventas').insert([{
      factura: fac,
      cliente: client || 'Cliente General',
      subtotal_usd: subtotal,
      impuesto_usd: totalTax,
      total_usd: totalUSD,
      total_ves: totalUSD * rates.VES,
      total_cop: totalUSD * rates.COP,
      tasa_ves: rates.VES,
      tasa_cop: rates.COP
    }])

    if (error) return toast.error('Error procesando venta')

    for (const item of cart) {
      await supabase.from('productos').update({ stock: item.stock - item.cant }).eq('id', item.id)
    }

    toast.success(`¡Venta ${fac} procesada!`)
    setCart([]); setClient(''); load()
  }

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <div className="lg:col-span-2 space-y-4">
        <h1 className="text-xl font-bold">Punto de Venta de Insumos</h1>
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
          {prods.map(p => (
            <button key={p.id} onClick={() => add(p)} className="card-box text-left p-3 hover:border-teal-500 transition-all">
              <h4 className="font-bold text-xs truncate">{p.nombre}</h4>
              <p className="text-[10px] text-slate-400">Stock: {p.stock}</p>
              <p className="font-bold text-sm text-teal-700 mt-2">{formatCurrency(p.precio_venta)}</p>
            </button>
          ))}
        </div>
      </div>

      <div className="card-box space-y-4 h-fit">
        <h2 className="font-bold text-sm flex items-center gap-2 border-b pb-3"><ShoppingCart className="w-4 h-4" /> Carrito</h2>
        <input placeholder="Nombre del cliente" value={client} onChange={e => setClient(e.target.value)} className="input-field" />

        <div className="space-y-2 max-h-56 overflow-y-auto">
          {cart.map(i => (
            <div key={i.id} className="flex justify-between items-center text-xs bg-slate-50 p-2 rounded-xl">
              <div><p className="font-bold truncate w-28">{i.nombre}</p><span className="text-slate-400">{formatCurrency(i.precio_venta)} x {i.cant}</span></div>
              <button onClick={() => setCart(cart.filter(x => x.id !== i.id))} className="text-rose-500"><Trash2 className="w-4 h-4" /></button>
            </div>
          ))}
        </div>

        <div className="border-t pt-3 space-y-1 text-xs">
          <div className="flex justify-between text-slate-500"><span>Subtotal:</span><span>{formatCurrency(subtotal)}</span></div>
          <div className="flex justify-between text-slate-500"><span>Impuestos:</span><span>{formatCurrency(totalTax)}</span></div>
          <div className="flex justify-between text-base font-bold text-teal-900 border-t pt-2"><span>Total USD:</span><span>{formatCurrency(totalUSD, 'USD')}</span></div>
          <div className="flex justify-between text-xs font-bold text-slate-600"><span>Total Bs. (BCV):</span><span>{formatCurrency(totalUSD * rates.VES, 'VES')}</span></div>
          <div className="flex justify-between text-xs font-bold text-amber-700"><span>Total COP:</span><span>{formatCurrency(totalUSD * rates.COP, 'COP')}</span></div>
        </div>

        <button onClick={checkout} className="w-full btn-primary justify-center py-3"><Check className="w-4 h-4" /> Finalizar Venta</button>
      </div>
    </div>
  )
}
