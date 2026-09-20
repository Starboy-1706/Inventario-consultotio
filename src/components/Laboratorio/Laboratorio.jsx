import { useState, useEffect } from 'react'
import { supabase } from '../../lib/supabase'
import { fmt } from '../../utils/helpers'
import {
  Plus, FlaskConical, Clock, CheckCircle2, Truck, Package,
  Save, X, AlertCircle, ChevronDown, ChevronUp
} from 'lucide-react'
import toast from 'react-hot-toast'

const estadosLab = {
  enviado: { label: 'Enviado al Lab', color: 'bg-blue-100 text-blue-800', icon: Truck },
  en_proceso: { label: 'En Proceso', color: 'bg-amber-100 text-amber-800', icon: Clock },
  listo: { label: 'Listo para Retirar', color: 'bg-emerald-100 text-emerald-800', icon: CheckCircle2 },
  entregado: { label: 'Entregado al Paciente', color: 'bg-slate-100 text-slate-600', icon: Package }
}

export default function Laboratorio() {
  const [trabajos, setTrabajos] = useState([])
  const [pacs, setPacs] = useState([])
  const [docs, setDocs] = useState([])
  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState({ paciente_id: '', doctor_id: '', tipo_trabajo: 'Corona', descripcion: '', fecha_entrega_estimada: '', costo_usd: '' })

  const load = async () => {
    const [tRes, pRes, dRes] = await Promise.all([
      supabase.from('laboratorio').select('*, pacientes(nombres, apellidos), doctores(nombres, apellidos)').order('created_at', { ascending: false }),
      supabase.from('pacientes').select('id, nombres, apellidos').eq('activo', true),
      supabase.from('doctores').select('id, nombres, apellidos').eq('activo', true)
    ])
    setTrabajos(tRes.data || []); setPacs(pRes.data || []); setDocs(dRes.data || [])
  }
  useEffect(() => { load() }, [])

  const save = async (e) => {
    e.preventDefault()
    await supabase.from('laboratorio').insert([{ ...form, costo_usd: parseFloat(form.costo_usd) || 0, doctor_id: form.doctor_id || null }])
    toast.success('Trabajo de laboratorio registrado')
    setShowForm(false); load()
  }

  const cambiarEstado = async (id, estado) => {
    await supabase.from('laboratorio').update({ estado }).eq('id', id)
    toast.success(`Estado: ${estadosLab[estado]?.label}`)
    load()
  }

  const pendientes = trabajos.filter(t => t.estado !== 'entregado')

  return (
    <div className="space-y-5">
      <div className="flex justify-between items-center flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-bold text-slate-800">Control de Laboratorio Dental</h1>
          <p className="text-xs text-slate-400">Coronas, prótesis, férulas, alineadores y trabajos técnicos</p>
        </div>
        <button onClick={() => setShowForm(!showForm)} className={showForm ? 'btn-secondary' : 'btn-primary'}>
          {showForm ? <><X className="w-4 h-4" /> Cerrar</> : <><Plus className="w-4 h-4" /> Nuevo Trabajo</>}
        </button>
      </div>

      {pendientes.length > 0 && (
        <div className="p-3 bg-amber-50 border border-amber-200 rounded-xl text-xs text-amber-800 font-semibold flex items-center gap-2">
          <AlertCircle className="w-4 h-4" /> {pendientes.length} trabajo{pendientes.length > 1 ? 's' : ''} pendiente{pendientes.length > 1 ? 's' : ''} de entrega del laboratorio
        </div>
      )}

      {showForm && (
        <form onSubmit={save} className="card-box space-y-3 border-2 border-blue-200 bg-blue-50/20">
          <h3 className="font-bold text-sm text-blue-800 flex items-center gap-1.5"><FlaskConical className="w-4 h-4" /> Registrar Trabajo de Laboratorio</h3>
          <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Paciente *</label>
              <select required className="input-field" value={form.paciente_id} onChange={e => setForm({...form, paciente_id: e.target.value})}>
                <option value="">Seleccionar...</option>{pacs.map(p => <option key={p.id} value={p.id}>{p.nombres} {p.apellidos}</option>)}
              </select>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Tipo de Trabajo *</label>
              <select required className="input-field" value={form.tipo_trabajo} onChange={e => setForm({...form, tipo_trabajo: e.target.value})}>
                <option>Corona</option><option>Prótesis Parcial</option><option>Prótesis Total</option>
                <option>Férula</option><option>Alineador</option><option>Carillas</option>
                <option>Implante</option><option>Modelo de Estudio</option><option>Otro</option>
              </select>
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Doctor Solicitante</label>
              <select className="input-field" value={form.doctor_id} onChange={e => setForm({...form, doctor_id: e.target.value})}>
                <option value="">General</option>{docs.map(d => <option key={d.id} value={d.id}>Dr. {d.nombres} {d.apellidos}</option>)}
              </select>
            </div>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Descripción</label>
              <input className="input-field" value={form.descripcion} onChange={e => setForm({...form, descripcion: e.target.value})} placeholder="Ej: Corona Zirconia #14" />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Entrega Estimada</label>
              <input type="date" className="input-field" value={form.fecha_entrega_estimada} onChange={e => setForm({...form, fecha_entrega_estimada: e.target.value})} />
            </div>
            <div><label className="text-[11px] font-semibold text-slate-500 block mb-1">Costo Lab ($ USD)</label>
              <input type="number" step="0.01" className="input-field" value={form.costo_usd} onChange={e => setForm({...form, costo_usd: e.target.value})} />
            </div>
          </div>
          <div className="flex gap-2">
            <button type="submit" className="btn-primary"><Save className="w-4 h-4" /> Enviar al Laboratorio</button>
            <button type="button" onClick={() => setShowForm(false)} className="btn-secondary">Cancelar</button>
          </div>
        </form>
      )}

      <div className="space-y-2">
        {trabajos.map(t => {
          const est = estadosLab[t.estado] || estadosLab.enviado
          return (
            <div key={t.id} className="card-box p-4 flex items-center justify-between flex-wrap gap-3">
              <div className="flex items-center gap-3">
                <FlaskConical className="w-5 h-5 text-blue-600" />
                <div>
                  <h3 className="font-bold text-sm text-slate-800">{t.tipo_trabajo}: {t.descripcion || 'Sin descripción'}</h3>
                  <p className="text-xs text-slate-500">Paciente: <b>{t.pacientes?.nombres} {t.pacientes?.apellidos}</b> {t.doctores ? `• Dr. ${t.doctores.nombres}` : ''}</p>
                  <p className="text-[11px] text-slate-400">Enviado: {new Date(t.fecha_envio).toLocaleDateString('es-VE')} {t.fecha_entrega_estimada ? `• Entrega: ${new Date(t.fecha_entrega_estimada).toLocaleDateString('es-VE')}` : ''}</p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <span className={`badge ${est.color}`}>{est.label}</span>
                {t.estado === 'enviado' && <button onClick={() => cambiarEstado(t.id, 'en_proceso')} className="btn-secondary text-xs py-1">En Proceso</button>}
                {t.estado === 'en_proceso' && <button onClick={() => cambiarEstado(t.id, 'listo')} className="btn-primary text-xs py-1 bg-emerald-600">Listo</button>}
                {t.estado === 'listo' && <button onClick={() => cambiarEstado(t.id, 'entregado')} className="btn-primary text-xs py-1">Entregar</button>}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
