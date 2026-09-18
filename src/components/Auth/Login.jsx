import { useState } from 'react'
import { useAuth } from '../../context/AuthContext'
import { Lock } from 'lucide-react'
import toast from 'react-hot-toast'

export default function Login() {
  const [key, setKey] = useState('')
  const { login } = useAuth()

  const handle = (e) => {
    e.preventDefault()
    if (login(key)) toast.success('Acceso Autorizado')
    else { toast.error('Clave de acceso incorrecta'); setKey('') }
  }

  return (
    <div className="min-h-screen bg-slate-900 flex items-center justify-center p-4">
      <form onSubmit={handle} className="bg-white p-8 rounded-3xl w-full max-w-sm shadow-2xl space-y-6 text-center">
        <div className="w-16 h-16 bg-teal-100 text-teal-700 rounded-2xl flex items-center justify-center mx-auto text-3xl">🦷</div>
        <div>
          <h1 className="text-xl font-bold text-slate-800">Sistema Odontológico</h1>
          <p className="text-xs text-slate-400 mt-1">Consultorio & Ventas de Insumos</p>
        </div>
        <div className="text-left space-y-1">
          <label className="text-xs font-semibold text-slate-600">Clave de Acceso</label>
          <div className="flex items-center border rounded-xl px-3 py-2.5 bg-slate-50 focus-within:ring-2 focus-within:ring-teal-500">
            <Lock className="w-4 h-4 text-slate-400 mr-2" />
            <input type="password" placeholder="••••••••" value={key} onChange={e => setKey(e.target.value)} className="bg-transparent outline-none w-full text-sm" autoFocus />
          </div>
        </div>
        <button type="submit" className="w-full btn-primary justify-center py-3">Ingresar al Sistema</button>
      </form>
    </div>
  )
}
