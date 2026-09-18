import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { Toaster } from 'react-hot-toast'
import { AuthProvider, useAuth } from './context/AuthContext'
import { CurrencyProvider } from './context/CurrencyContext'
import Login from './components/Auth/Login'
import Shell from './components/Layout/Shell'
import Pacientes from './components/Consultorio/Pacientes'
import Citas from './components/Consultorio/Citas'
import Historial from './components/Consultorio/Historial'
import Tratamientos from './components/Consultorio/Tratamientos'
import POS from './components/Ventas/POS'
import Inventario from './components/Ventas/Inventario'
import Configuracion from './components/Config/Configuracion'

function AppContent() {
  const { auth, loading } = useAuth()
  if (loading) return null
  if (!auth) return <Login />

  return (
    <CurrencyProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Shell />}>
            <Route index element={<Navigate to="/pacientes" replace />} />
            <Route path="pacientes" element={<Pacientes />} />
            <Route path="citas" element={<Citas />} />
            <Route path="historial" element={<Historial />} />
            <Route path="tratamientos" element={<Tratamientos />} />
            <Route path="pos" element={<POS />} />
            <Route path="inventario" element={<Inventario />} />
            <Route path="config" element={<Configuracion />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </CurrencyProvider>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <AppContent />
      <Toaster position="top-right" />
    </AuthProvider>
  )
}
