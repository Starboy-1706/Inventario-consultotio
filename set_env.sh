#!/bin/bash
echo ""
echo "=============================================="
echo " 🔑 CONFIGURADOR DE VARIABLES DE ENTORNO"
echo "=============================================="
echo ""

read -p "1️⃣ Pega tu SUPABASE PROJECT URL: " RAW_URL
read -p "2️⃣ Pega tu SUPABASE ANON KEY: " RAW_KEY
read -p "3️⃣ Ingresa la Clave de Acceso deseada [Enter para 'admin123']: " RAW_PASS

# Limpieza automática de espacios, comillas y barras
CLEAN_URL=$(echo "$RAW_URL" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/["'"'"']//g' -e 's/\/rest\/v1\/?$//' -e 's/\/+$//')
CLEAN_KEY=$(echo "$RAW_KEY" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/["'"'"']//g')
CLEAN_PASS=${RAW_PASS:-admin123}
CLEAN_PASS=$(echo "$CLEAN_PASS" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/["'"'"']//g')

# Si la URL no empieza por https://, agregarlo
if [[ ! $CLEAN_URL =~ ^https?:// ]]; then
  CLEAN_URL="https://$CLEAN_URL"
fi

# Guardar archivo .env limpio
cat > .env << EOF
VITE_SUPABASE_URL=$CLEAN_URL
VITE_SUPABASE_ANON_KEY=$CLEAN_KEY
VITE_APP_PASSWORD=$CLEAN_PASS
EOF

echo ""
echo "✅ Archivo .env generado exitosamente con los siguientes valores:"
echo "--------------------------------------------------------------"
cat .env
echo "--------------------------------------------------------------"
echo ""

echo "🧪 Probando conexión directa con Supabase..."
node -e "
import('@supabase/supabase-js').then(async ({ createClient }) => {
  const client = createClient('$CLEAN_URL', '$CLEAN_KEY');
  const { data, error } = await client.from('tasas_cambio').select('*').limit(1);
  if (error) {
    console.error('❌ Error de conexión:', error.message);
  } else {
    console.log('🟢 ¡CONEXIÓN EXITOSA! Supabase respondió correctamente.');
  }
}).catch(e => console.error('Error:', e.message));
"
