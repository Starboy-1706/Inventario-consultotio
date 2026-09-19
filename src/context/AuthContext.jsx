import { createContext, useContext, useState, useEffect } from 'react'
const AuthContext = createContext()
export function AuthProvider({ children }) {
  const [auth, setAuth] = useState(false)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const s = localStorage.getItem('odonto_auth_session')
    if (s === 'active') setAuth(true)
    setLoading(false)
  }, [])

  const login = (pass) => {
    const valid = import.meta.env.VITE_APP_PASSWORD || 'admin123'
    if (pass === valid) {
      localStorage.setItem('odonto_auth_session', 'active')
      setAuth(true)
      return true
    }
    return false
  }

  const logout = () => {
    localStorage.removeItem('odonto_auth_session')
    setAuth(false)
  }

  return <AuthContext.Provider value={{ auth, loading, login, logout }}>{children}</AuthContext.Provider>
}
export const useAuth = () => useContext(AuthContext)
