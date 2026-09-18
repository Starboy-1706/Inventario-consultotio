import { createContext, useContext, useState, useEffect } from 'react'
const AuthContext = createContext()
export function AuthProvider({ children }) {
  const [auth, setAuth] = useState(false)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const ok = localStorage.getItem('odonto_access_token')
    if (ok === 'authorized') setAuth(true)
    setLoading(false)
  }, [])

  const login = (pass) => {
    const valid = import.meta.env.VITE_APP_PASSWORD || 'admin123'
    if (pass === valid) {
      localStorage.setItem('odonto_access_token', 'authorized')
      setAuth(true)
      return true
    }
    return false
  }

  const logout = () => {
    localStorage.removeItem('odonto_access_token')
    setAuth(false)
  }

  return <AuthContext.Provider value={{ auth, loading, login, logout }}>{children}</AuthContext.Provider>
}
export const useAuth = () => useContext(AuthContext)
