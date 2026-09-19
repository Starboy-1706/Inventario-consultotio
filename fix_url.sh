#!/bin/bash
set -e

echo "🧹 Limpiando y blindando el cliente de Supabase..."

cat > src/lib/supabase.js << 'EOF'
import { createClient } from '@supabase/supabase-js'

// Función para limpiar y extraer únicamente el dominio base (ej: https://xyz.supabase.co)
function sanitizeSupabaseUrl(rawUrl) {
  if (!rawUrl) return ''
  let cleaned = String(rawUrl).trim().replace(/^["']|["']$/g, '') // Quitar comillas
  if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
    cleaned = 'https://' + cleaned
  }
  try {
    const parsed = new URL(cleaned)
    // Extrae únicamente el origen (protocolo + host) sin /rest/v1 ni barras al final
    return parsed.origin
  } catch (e) {
    return cleaned.replace(/\/rest\/v1\/?$/, '').replace(/\/+$/, '')
  }
}

function sanitizeKey(rawKey) {
  if (!rawKey) return ''
  return String(rawKey).trim().replace(/^["']|["']$/g, '')
}

const rawUrl = import.meta.env.VITE_SUPABASE_URL || ''
const rawKey = import.meta.env.VITE_SUPABASE_ANON_KEY || ''

const supabaseUrl = sanitizeSupabaseUrl(rawUrl)
const supabaseAnonKey = sanitizeKey(rawKey)

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

export async function testSupabaseConnection() {
  if (!supabaseUrl || !supabaseAnonKey || supabaseUrl.includes('placeholder')) {
    return {
      ok: false,
      reason: 'MISSING_ENV',
      message: 'Faltan variables VITE_SUPABASE_URL o VITE_SUPABASE_ANON_KEY en Vercel / .env'
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
        message: error.message || 'Error en consulta SQL a Supabase',
        details: error
      }
    }

    return {
      ok: true,
      latency,
      url: supabaseUrl.replace('https://', ''),
      message: 'Conexión activa con Supabase'
    }
  } catch (err) {
    return {
      ok: false,
      reason: 'NETWORK_ERROR',
      message: err.message || 'Error de red con Supabase'
    }
  }
}
EOF

npm run build
echo "✅ Cliente Supabase auto-sanitizado y compilado exitosamente!"
