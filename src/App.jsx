import { BrowserRouter, Routes, Route } from 'react-router-dom'
import { Toaster } from 'react-hot-toast'
import { AuthProvider, useAuth } from './context/AuthContext'
import { CurrencyProvider } from './context/CurrencyContext'
import Login from './components/Auth/Login'
import Shell from './components/Layout/Shell'
import Dashboard from './components/Dashboard/Dashboard'
import Reportes from './components/Reportes/Reportes'
import Pacientes from './components/Consultorio/Pacientes'
import Citas from './components/Consultorio/Citas'
import Historial from './components/Consultorio/Historial'
import Tratamientos from './components/Consultorio/Tratamientos'
import PlanesTratamiento from './components/Planes/PlanesTratamiento'
import Doctores from './components/Doctores/Doctores'
import POS from './components/Ventas/POS'
import HistorialVentas from './components/Ventas/HistorialVentas'
import Inventario from './components/Inventario/Inventario'
import TasasImpuestos from './components/Configuracion/TasasImpuestos'

function RoutesWrapper() {
  const { auth, loading } = useAuth()
  if (loading) return null
  if (!auth) return <Login />

  return (
    <CurrencyProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Shell />}>
            <Route index element={<Dashboard />} />
            <Route path="reportes" element={<Reportes />} />
            <Route path="pacientes" element={<Pacientes />} />
            <Route path="citas" element={<Citas />} />
            <Route path="historial" element={<Historial />} />
            <Route path="planes" element={<PlanesTratamiento />} />
            <Route path="tratamientos" element={<Tratamientos />} />
            <Route path="doctores" element={<Doctores />} />
            <Route path="pos" element={<POS />} />
            <Route path="ventas" element={<HistorialVentas />} />
            <Route path="inventario" element={<Inventario />} />
            <Route path="config" element={<TasasImpuestos />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </CurrencyProvider>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <RoutesWrapper />
      <Toaster position="top-right" />
    </AuthProvider>
  )
}
