import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || ''
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || ''

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('⚠️ [SUPABASE] Faltan variables de entorno: VITE_SUPABASE_URL o VITE_SUPABASE_ANON_KEY no están definidas.')
}

export const supabase = createClient(
  supabaseUrl || 'https://placeholder.supabase.co',
  supabaseAnonKey || 'placeholder',
  {
    auth: {
      persistSession: false,
      autoRefreshToken: false
    }
  }
)

// Función para probar la conexión en tiempo real
export async function testSupabaseConnection() {
  if (!supabaseUrl || !supabaseAnonKey || supabaseUrl.includes('placeholder')) {
    return {
      ok: false,
      reason: 'MISSING_ENV',
      message: 'Faltan las variables VITE_SUPABASE_URL o VITE_SUPABASE_ANON_KEY en Vercel / .env'
    }
  }

  try {
    const start = Date.now()
    const { data, error, status } = await supabase
      .from('tasas_cambio')
      .select('moneda, tasa')
      .limit(1)

    const latency = Date.now() - start

    if (error) {
      return {
        ok: false,
        reason: 'QUERY_ERROR',
        status,
        message: error.message || 'Error al consultar la tabla en Supabase',
        details: error
      }
    }

    return {
      ok: true,
      latency,
      url: supabaseUrl.replace(/https?:\/\//, '').split('.')[0] + '.supabase.co',
      message: 'Conexión activa con Supabase'
    }
  } catch (err) {
    return {
      ok: false,
      reason: 'NETWORK_ERROR',
      message: err.message || 'Error de red al conectar con Supabase'
    }
  }
}
