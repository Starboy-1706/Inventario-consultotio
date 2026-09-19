import { useState } from 'react'
import { useAuth } from '../../context/AuthContext'
import { Lock, ArrowRight } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Login() {
  const [pass, setPass] = useState('')
  const { login } = useAuth()

  const handle = (e) => {
    e.preventDefault()
    if (login(pass)) toast.success('Acceso correcto')
    else { toast.error('Clave de acceso incorrecta'); setPass('') }
  }

  return (
    <div className="min-h-screen bg-slate-950 flex items-center justify-center p-4 relative overflow-hidden">
      <div className="absolute -top-40 -left-40 w-96 h-96 bg-teal-500/10 rounded-full blur-3xl"></div>
      <div className="absolute -bottom-40 -right-40 w-96 h-96 bg-cyan-500/10 rounded-full blur-3xl"></div>

      <form onSubmit={handle} className="relative bg-white/95 backdrop-blur-md p-8 rounded-3xl w-full max-w-sm border border-white/20 shadow-2xl space-y-6 text-center">
        <div className="w-16 h-16 bg-teal-50 text-teal-600 rounded-2xl flex items-center justify-center mx-auto text-3xl shadow-inner">
          🦷
        </div>
        <div>
          <h1 className="text-xl font-bold text-slate-800">Sistema Odontológico</h1>
          <p className="text-xs text-slate-400 mt-1">Consultorio & Ventas de Insumos</p>
        </div>

        <div className="text-left space-y-1.5">
          <label className="text-xs font-semibold text-slate-600">Clave de Acceso</label>
          <div className="flex items-center border border-slate-200 rounded-xl px-3.5 py-2.5 bg-slate-50/50 focus-within:ring-2 focus-within:ring-teal-500 focus-within:bg-white transition-all">
            <Lock className="w-4 h-4 text-slate-400 mr-2 shrink-0" />
            <input type="password" placeholder="••••••••" value={pass} onChange={e => setPass(e.target.value)} className="bg-transparent outline-none w-full text-sm" autoFocus />
          </div>
        </div>

        <button type="submit" className="w-full btn-primary py-3 justify-center shadow-lg shadow-teal-600/20">
          Ingresar al Sistema <ArrowRight className="w-4 h-4" />
        </button>
      </form>
    </div>
  )
}
