CREATE TABLE IF NOT EXISTS tratamiento_insumos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tratamiento_id UUID REFERENCES tratamientos(id) ON DELETE CASCADE,
  producto_id UUID REFERENCES productos(id) ON DELETE CASCADE,
  cantidad INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE tratamiento_insumos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "acc_ti" ON tratamiento_insumos;
CREATE POLICY "acc_ti" ON tratamiento_insumos FOR ALL USING (true) WITH CHECK (true);
