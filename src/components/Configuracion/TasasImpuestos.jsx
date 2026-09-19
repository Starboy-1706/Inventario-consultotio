import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { useCurrency } from '../../context/CurrencyContext'
import { DollarSign, Percent, Save, Plus, RefreshCw, Building2, CheckCircle2 } from 'lucide-react'
import toast from 'react-hot-toast'

export default function TasasImpuestos() {
  const { rates, setRates, loadData, syncOfficialRates, loadingRates } = useCurrency()
  const [tab, setTab] = useState('clinica') // clinica | tasas
  const [ves, setVes] = useState(rates.VES)
  const [cop, setCop] = useState(rates.COP)
  const [taxes, setTaxes] = useState([])
  const [newTax, setNewTax] = useState({ nombre: '', porcentaje: '' })

  // Membrete de la clínica
  const [clinica, setClinica] = useState({
    nombre: '',
    rif_nit: '',
    telefono: '',
    email: '',
    direccion: '',
    mensaje_recibo: ''
  })

  useEffect(() => {
    setVes(rates.VES)
    setCop(rates.COP)
  }, [rates])

  const loadClinicaData = async () => {
    const [cRes, iRes] = await Promise.all([
      supabase.from('configuracion_consultorio').select('*').limit(1),
      supabase.from('impuestos').select('*')
    ])

    if (cRes.data?.[0]) setClinica(cRes.data[0])
    if (iRes.data) setTaxes(iRes.data)
  }

  useEffect(() => { loadClinicaData() }, [])

  const saveClinica = async e => {
    e.preventDefault()
    if (clinica.id) {
      await supabase.from('configuracion_consultorio').update(clinica).eq('id', clinica.id)
    } else {
      await supabase.from('configuracion_consultorio').insert([clinica])
    }
    toast.success('Datos del consultorio actualizados para los recibos')
  }

  const saveRates = async (e) => {
    e.preventDefault()
    const numVes = Number(ves)
    const numCop = Number(cop)
    await supabase.from('tasas_cambio').upsert({ moneda: 'VES', tasa: numVes, fuente: 'Manual' }, { onConflict: 'moneda' })
    await supabase.from('tasas_cambio').upsert({ moneda: 'COP', tasa: numCop, fuente: 'Manual' }, { onConflict: 'moneda' })
    setRates({ VES: numVes, COP: numCop })
    toast.success('Tasas guardadas en Supabase')
  }

  const addTax = async (e) => {
    e.preventDefault()
    await supabase.from('impuestos').insert([newTax])
    toast.success('Impuesto agregado')
    setNewTax({ nombre: '', porcentaje: '' })
    const { data } = await supabase.from('impuestos').select('*')
    setTaxes(data || [])
    loadData()
  }

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Ajustes & Membrete de la Clínica</h1>
          <p className="text-xs text-slate-400">Datos fiscales de los recibos, tasas BCV e impuestos</p>
        </div>
        <button onClick={() => syncOfficialRates(true)} disabled={loadingRates} className="btn-primary">
          <RefreshCw className={`w-4 h-4 ${loadingRates ? 'animate-spin' : ''}`} /> Sincronizar BCV de Hoy
        </button>
      </div>

      {/* Selector de Tabs */}
      <div className="flex border-b border-slate-200 gap-2">
        <button onClick={() => setTab('clinica')} className={`pb-2.5 px-3 text-xs font-bold border-b-2 flex items-center gap-1.5 ${tab === 'clinica' ? 'border-teal-600 text-teal-700' : 'border-transparent text-slate-400'}`}>
          <Building2 className="w-3.5 h-3.5" /> Datos del Consultorio (Membrete de Recibos)
        </button>
        <button onClick={() => setTab('tasas')} className={`pb-2.5 px-3 text-xs font-bold border-b-2 flex items-center gap-1.5 ${tab === 'tasas' ? 'border-teal-600 text-teal-700' : 'border-transparent text-slate-400'}`}>
          <DollarSign className="w-3.5 h-3.5" /> Tasas Oficiales & Impuestos
        </button>
      </div>

      {/* TAB 1: DATOS DEL CONSULTORIO */}
      {tab === 'clinica' && (
        <form onSubmit={saveClinica} className="card-box space-y-4 max-w-2xl">
          <h2 className="font-bold text-sm text-slate-800 flex items-center gap-2 border-b pb-2">
            <Building2 className="w-4 h-4 text-teal-600" /> Información que aparecerá en Facturas y Tickets
          </h2>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-semibold text-slate-600 block mb-1">Nombre del Consultorio / Clínica *</label>
              <input required className="input-field font-bold" value={clinica.nombre} onChange={e => setClinica({...clinica, nombre: e.target.value})} placeholder="Ej: Clínica Dental San Lucas" />
            </div>
            <div>
              <label className="text-xs font-semibold text-slate-600 block mb-1">RIF / NIT / Identificación Fiscal *</label>
              <input required className="input-field" value={clinica.rif_nit} onChange={e => setClinica({...clinica, rif_nit: e.target.value})} placeholder="RIF: J-12345678-0" />
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-semibold text-slate-600 block mb-1">Teléfono de Contacto</label>
              <input className="input-field" value={clinica.telefono} onChange={e => setClinica({...clinica, telefono: e.target.value})} placeholder="+58 412-1234567" />
            </div>
            <div>
              <label className="text-xs font-semibold text-slate-600 block mb-1">Correo Electrónico</label>
              <input type="email" className="input-field" value={clinica.email} onChange={e => setClinica({...clinica, email: e.target.value})} placeholder="contacto@clinicadental.com" />
            </div>
          </div>

          <div>
            <label className="text-xs font-semibold text-slate-600 block mb-1">Dirección Física</label>
            <input className="input-field" value={clinica.direccion} onChange={e => setClinica({...clinica, direccion: e.target.value})} placeholder="Av. Principal, Edif. Médico, Piso 2, Consultorio 204" />
          </div>

          <div>
            <label className="text-xs font-semibold text-slate-600 block mb-1">Mensaje de Pie de Página en Recibos</label>
            <textarea rows={2} className="input-field" value={clinica.mensaje_recibo} onChange={e => setClinica({...clinica, mensaje_recibo: e.target.value})} placeholder="¡Gracias por su visita! Cita de control en 6 meses." />
          </div>

          <button type="submit" className="btn-primary w-full justify-center">
            <Save className="w-4 h-4" /> Guardar Membrete de la Clínica
          </button>
        </form>
      )}

      {/* TAB 2: TASAS E IMPUESTOS */}
      {tab === 'tasas' && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <form onSubmit={saveRates} className="card-box space-y-4">
            <h2 className="font-bold text-sm text-slate-800 flex items-center gap-2">
              <DollarSign className="w-4 h-4 text-teal-600" /> Tasas del Sistema
            </h2>
            <div>
              <label className="text-xs font-semibold text-slate-600 block mb-1">Tasa Bolívares (VES por 1 USD)</label>
              <input type="number" step="0.01" className="input-field font-bold text-teal-800" value={ves} onChange={e => setVes(e.target.value)} />
            </div>
            <div>
              <label className="text-xs font-semibold text-slate-600 block mb-1">Tasa Pesos Colombianos (COP por 1 USD)</label>
              <input type="number" step="1" className="input-field font-bold text-amber-800" value={cop} onChange={e => setCop(e.target.value)} />
            </div>
            <button type="submit" className="btn-secondary w-full justify-center text-xs font-bold py-2.5">
              <Save className="w-4 h-4" /> Guardar Tasas en Supabase
            </button>
          </form>

          <div className="card-box space-y-4">
            <h2 className="font-bold text-sm text-slate-800 flex items-center gap-2">
              <Percent className="w-4 h-4 text-teal-600" /> Impuestos Configurados
            </h2>
            <div className="space-y-2">
              {taxes.map(t => (
                <div key={t.id} className="flex justify-between items-center text-xs p-2.5 bg-slate-50 rounded-xl">
                  <span className="font-bold text-slate-800">{t.nombre}</span>
                  <span className="font-mono bg-teal-100 text-teal-800 px-2.5 py-0.5 rounded-full font-bold">{t.porcentaje}%</span>
                </div>
              ))}
            </div>
            <form onSubmit={addTax} className="flex gap-2 pt-2">
              <input required placeholder="Nuevo Impuesto (ej. IVA 16%)" className="input-field text-xs" value={newTax.nombre} onChange={e => setNewTax({...newTax, nombre: e.target.value})} />
              <input required type="number" placeholder="%" className="input-field w-20 text-xs" value={newTax.porcentaje} onChange={e => setNewTax({...newTax, porcentaje: e.target.value})} />
              <button type="submit" className="btn-primary"><Plus className="w-4 h-4" /></button>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
