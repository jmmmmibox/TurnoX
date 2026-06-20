-- ============================================================
-- TURNOX - Schema completo
-- Supabase project: jjabwsitruoxcpolvzph
-- ============================================================

-- EXTENSIONES
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- PLANTAS
-- ============================================================
CREATE TABLE plantas (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre TEXT NOT NULL,
  descripcion TEXT,
  activa BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- AREAS DE TRABAJO
-- ============================================================
CREATE TABLE areas (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  planta_id UUID REFERENCES plantas(id) ON DELETE CASCADE,
  nombre TEXT NOT NULL,
  color TEXT DEFAULT '#3B82F6',
  permite_polivalencia BOOLEAN DEFAULT true,
  orden INT DEFAULT 0,
  activa BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- LETRAS (grupos de turno)
-- ============================================================
CREATE TABLE letras (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  planta_id UUID REFERENCES plantas(id) ON DELETE CASCADE,
  nombre TEXT NOT NULL, -- A, B, C, D, E, ER
  color TEXT DEFAULT '#6366F1',
  activa BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- USUARIOS (gestores - Supabase Auth)
-- ============================================================
CREATE TABLE gestores (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nombre TEXT NOT NULL,
  email TEXT NOT NULL,
  planta_id UUID REFERENCES plantas(id),
  rol TEXT DEFAULT 'gestor', -- 'admin' | 'gestor'
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- EMPLEADOS (auth propia sin email)
-- ============================================================
CREATE TABLE empleados (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  planta_id UUID REFERENCES plantas(id) ON DELETE CASCADE,
  letra_id UUID REFERENCES letras(id),
  area_principal_id UUID REFERENCES areas(id),
  nombre TEXT NOT NULL,
  apellidos TEXT NOT NULL,
  username TEXT UNIQUE NOT NULL, -- login sin email
  password_hash TEXT NOT NULL,   -- bcrypt o simple hash
  telefono TEXT,
  notas TEXT,                    -- solo visible para gestores
  activo BOOLEAN DEFAULT true,
  primer_login BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- POLIVALENCIAS (empleado puede cubrir otras áreas)
-- ============================================================
CREATE TABLE polivalencias (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  empleado_id UUID REFERENCES empleados(id) ON DELETE CASCADE,
  area_id UUID REFERENCES areas(id) ON DELETE CASCADE,
  UNIQUE(empleado_id, area_id)
);

-- ============================================================
-- FESTIVOS
-- ============================================================
CREATE TABLE festivos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  planta_id UUID REFERENCES plantas(id) ON DELETE CASCADE,
  fecha DATE NOT NULL,
  nombre TEXT NOT NULL,
  ambito TEXT DEFAULT 'nacional', -- 'nacional' | 'provincial' | 'local'
  año INT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(planta_id, fecha)
);

-- ============================================================
-- CONFIGURACION ANUAL DE CICLOS POR LETRA
-- ============================================================
CREATE TABLE ciclos_config (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  letra_id UUID REFERENCES letras(id) ON DELETE CASCADE,
  año INT NOT NULL,
  orden INT NOT NULL, -- 1, 2, 3 (puede haber varios períodos por año)
  tipo TEXT NOT NULL, -- 'turno' | 'refuerzo'
  fecha_inicio DATE NOT NULL,
  fecha_fin DATE NOT NULL,
  turno_inicial TEXT, -- 'M' | 'T' | 'N' | 'D' (solo para tipo='turno')
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TURNOS GENERADOS (calendario real día a día)
-- ============================================================
CREATE TABLE turnos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  empleado_id UUID REFERENCES empleados(id) ON DELETE CASCADE,
  fecha DATE NOT NULL,
  tipo TEXT NOT NULL, -- 'M' | 'T' | 'N' | 'D' | 'R' | 'V' | 'B' | 'L'
  -- M=Mañana T=Tarde N=Noche D=Descanso R=Refuerzo V=Vacaciones B=Baja L=Licencia
  area_id UUID REFERENCES areas(id),
  editado_manualmente BOOLEAN DEFAULT false,
  notas TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(empleado_id, fecha)
);

-- ============================================================
-- VACACIONES - RONDAS
-- ============================================================
CREATE TABLE vacaciones_rondas (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  planta_id UUID REFERENCES plantas(id) ON DELETE CASCADE,
  año INT NOT NULL,
  numero_ronda INT NOT NULL, -- 1, 2, 3
  nombre TEXT NOT NULL,
  descripcion TEXT,
  dias INT NOT NULL, -- 6, 6, 4
  abierta BOOLEAN DEFAULT false,
  fecha_apertura TIMESTAMPTZ,
  fecha_cierre TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- VACACIONES - SOLICITUDES
-- ============================================================
CREATE TABLE vacaciones_solicitudes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  empleado_id UUID REFERENCES empleados(id) ON DELETE CASCADE,
  ronda_id UUID REFERENCES vacaciones_rondas(id) ON DELETE CASCADE,
  fecha_inicio DATE NOT NULL,
  fecha_fin DATE NOT NULL,
  dias_solicitados INT NOT NULL,
  estado TEXT DEFAULT 'pendiente', -- 'pendiente' | 'aprobada' | 'rechazada'
  notas_empleado TEXT,
  notas_gestor TEXT,
  revisada_por UUID REFERENCES gestores(id),
  revisada_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INTERCAMBIOS DE TURNO
-- ============================================================
CREATE TABLE intercambios (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  solicitante_id UUID REFERENCES empleados(id) ON DELETE CASCADE,
  receptor_id UUID REFERENCES empleados(id) ON DELETE CASCADE,
  fecha_solicitante DATE NOT NULL,
  fecha_receptor DATE NOT NULL,
  estado TEXT DEFAULT 'pendiente', -- 'pendiente' | 'aceptado' | 'rechazado' | 'aprobado' | 'denegado'
  -- pendiente=esperando receptor, aceptado=receptor acepta, aprobado=gestor aprueba
  confirmado_receptor BOOLEAN DEFAULT false,
  confirmado_gestor BOOLEAN DEFAULT false,
  notas TEXT,
  revisada_por UUID REFERENCES gestores(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- AUSENCIAS Y COBERTURAS
-- ============================================================
CREATE TABLE ausencias (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  empleado_id UUID REFERENCES empleados(id) ON DELETE CASCADE,
  fecha_inicio DATE NOT NULL,
  fecha_fin DATE NOT NULL,
  tipo TEXT NOT NULL, -- 'baja' | 'licencia' | 'ausencia'
  motivo TEXT,
  cobertura_tipo TEXT, -- 'refuerzo' | 'polivalente' | '12h' | 'sin_cobertura'
  cobertura_empleado_id UUID REFERENCES empleados(id),
  modo_12h BOOLEAN DEFAULT false,
  registrada_por UUID REFERENCES gestores(id),
  notas TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- NOTIFICACIONES
-- ============================================================
CREATE TABLE notificaciones (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  destinatario_empleado_id UUID REFERENCES empleados(id) ON DELETE CASCADE,
  destinatario_gestor_id UUID REFERENCES gestores(id) ON DELETE CASCADE,
  tipo TEXT NOT NULL, -- 'intercambio' | 'vacaciones' | 'ausencia' | 'turno' | 'aviso'
  titulo TEXT NOT NULL,
  mensaje TEXT NOT NULL,
  leida BOOLEAN DEFAULT false,
  referencia_id UUID, -- id del intercambio, solicitud, etc.
  referencia_tipo TEXT, -- 'intercambio' | 'vacacion' | 'ausencia'
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDICES
-- ============================================================
CREATE INDEX idx_turnos_empleado_fecha ON turnos(empleado_id, fecha);
CREATE INDEX idx_turnos_fecha ON turnos(fecha);
CREATE INDEX idx_empleados_letra ON empleados(letra_id);
CREATE INDEX idx_empleados_planta ON empleados(planta_id);
CREATE INDEX idx_notificaciones_empleado ON notificaciones(destinatario_empleado_id, leida);
CREATE INDEX idx_notificaciones_gestor ON notificaciones(destinatario_gestor_id, leida);

-- ============================================================
-- RLS - DESACTIVADO para MVP (igual que otras apps de Juanma)
-- ============================================================
ALTER TABLE plantas DISABLE ROW LEVEL SECURITY;
ALTER TABLE areas DISABLE ROW LEVEL SECURITY;
ALTER TABLE letras DISABLE ROW LEVEL SECURITY;
ALTER TABLE gestores DISABLE ROW LEVEL SECURITY;
ALTER TABLE empleados DISABLE ROW LEVEL SECURITY;
ALTER TABLE polivalencias DISABLE ROW LEVEL SECURITY;
ALTER TABLE festivos DISABLE ROW LEVEL SECURITY;
ALTER TABLE ciclos_config DISABLE ROW LEVEL SECURITY;
ALTER TABLE turnos DISABLE ROW LEVEL SECURITY;
ALTER TABLE vacaciones_rondas DISABLE ROW LEVEL SECURITY;
ALTER TABLE vacaciones_solicitudes DISABLE ROW LEVEL SECURITY;
ALTER TABLE intercambios DISABLE ROW LEVEL SECURITY;
ALTER TABLE ausencias DISABLE ROW LEVEL SECURITY;
ALTER TABLE notificaciones DISABLE ROW LEVEL SECURITY;

-- ============================================================
-- DATOS DEMO - PLANTA
-- ============================================================
INSERT INTO plantas (id, nombre, descripcion) VALUES
('a1b2c3d4-0001-0001-0001-000000000001', 'Planta Huelva', 'Planta piloto MOEVE - Huelva');

-- ============================================================
-- DATOS DEMO - AREAS
-- ============================================================
INSERT INTO areas (id, planta_id, nombre, color, permite_polivalencia, orden) VALUES
('a1b2c3d4-0002-0001-0001-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'Jefe de Turno', '#1E3A5F', false, 1),
('a1b2c3d4-0002-0001-0001-000000000002', 'a1b2c3d4-0001-0001-0001-000000000001', 'Control', '#2563EB', false, 2),
('a1b2c3d4-0002-0001-0001-000000000003', 'a1b2c3d4-0001-0001-0001-000000000001', 'RX/RG', '#7C3AED', true, 3),
('a1b2c3d4-0002-0001-0001-000000000004', 'a1b2c3d4-0001-0001-0001-000000000001', 'Área A', '#059669', true, 4),
('a1b2c3d4-0002-0001-0001-000000000005', 'a1b2c3d4-0001-0001-0001-000000000001', 'Área B', '#D97706', true, 5),
('a1b2c3d4-0002-0001-0001-000000000006', 'a1b2c3d4-0001-0001-0001-000000000001', 'Azufre', '#DC2626', true, 6);

-- ============================================================
-- DATOS DEMO - LETRAS
-- ============================================================
INSERT INTO letras (id, planta_id, nombre, color) VALUES
('a1b2c3d4-0003-0001-0001-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'A', '#EF4444'),
('a1b2c3d4-0003-0001-0001-000000000002', 'a1b2c3d4-0001-0001-0001-000000000001', 'B', '#F97316'),
('a1b2c3d4-0003-0001-0001-000000000003', 'a1b2c3d4-0001-0001-0001-000000000001', 'C', '#EAB308'),
('a1b2c3d4-0003-0001-0001-000000000004', 'a1b2c3d4-0001-0001-0001-000000000001', 'D', '#22C55E'),
('a1b2c3d4-0003-0001-0001-000000000005', 'a1b2c3d4-0001-0001-0001-000000000001', 'E', '#3B82F6'),
('a1b2c3d4-0003-0001-0001-000000000006', 'a1b2c3d4-0001-0001-0001-000000000001', 'ER', '#8B5CF6');

-- ============================================================
-- DATOS DEMO - CICLOS CONFIG 2026
-- ============================================================
INSERT INTO ciclos_config (letra_id, año, orden, tipo, fecha_inicio, fecha_fin, turno_inicial) VALUES
-- LETRA A
('a1b2c3d4-0003-0001-0001-000000000001', 2026, 1, 'refuerzo', '2026-01-01', '2026-01-28', NULL),
('a1b2c3d4-0003-0001-0001-000000000001', 2026, 2, 'turno',    '2026-01-31', '2026-10-04', 'M'),
('a1b2c3d4-0003-0001-0001-000000000001', 2026, 3, 'refuerzo', '2026-10-05', '2026-10-28', NULL),
('a1b2c3d4-0003-0001-0001-000000000001', 2026, 4, 'turno',    '2026-10-31', '2026-12-31', 'M'),
-- LETRA B
('a1b2c3d4-0003-0001-0001-000000000002', 2026, 1, 'turno',    '2026-01-05', '2026-10-26', 'M'),
('a1b2c3d4-0003-0001-0001-000000000002', 2026, 2, 'refuerzo', '2026-10-29', '2026-12-31', NULL),
-- LETRA C
('a1b2c3d4-0003-0001-0001-000000000003', 2026, 1, 'turno',    '2026-01-03', '2026-03-29', 'M'),
('a1b2c3d4-0003-0001-0001-000000000003', 2026, 2, 'refuerzo', '2026-04-01', '2026-06-03', NULL),
('a1b2c3d4-0003-0001-0001-000000000003', 2026, 3, 'turno',    '2026-06-06', '2026-12-31', 'M'),
-- LETRA D
('a1b2c3d4-0003-0001-0001-000000000004', 2026, 1, 'turno',    '2026-01-01', '2026-01-26', 'M'),
('a1b2c3d4-0003-0001-0001-000000000004', 2026, 2, 'refuerzo', '2026-01-29', '2026-03-31', NULL),
('a1b2c3d4-0003-0001-0001-000000000004', 2026, 3, 'turno',    '2026-04-03', '2026-12-31', 'M'),
-- LETRA E
('a1b2c3d4-0003-0001-0001-000000000005', 2026, 1, 'turno',    '2026-01-01', '2026-06-04', 'N'),
('a1b2c3d4-0003-0001-0001-000000000005', 2026, 2, 'refuerzo', '2026-06-05', '2026-08-04', NULL),
('a1b2c3d4-0003-0001-0001-000000000005', 2026, 3, 'turno',    '2026-08-07', '2026-12-31', 'M'),
-- LETRA ER
('a1b2c3d4-0003-0001-0001-000000000006', 2026, 1, 'turno',    '2026-01-01', '2026-08-02', 'T'),
('a1b2c3d4-0003-0001-0001-000000000006', 2026, 2, 'refuerzo', '2026-08-05', '2026-10-02', NULL),
('a1b2c3d4-0003-0001-0001-000000000006', 2026, 3, 'turno',    '2026-10-05', '2026-12-31', 'M');

-- ============================================================
-- DATOS DEMO - FESTIVOS 2026 (España + Huelva)
-- ============================================================
INSERT INTO festivos (planta_id, fecha, nombre, ambito, año) VALUES
('a1b2c3d4-0001-0001-0001-000000000001', '2026-01-01', 'Año Nuevo', 'nacional', 2026),
('a1b2c3d4-0001-0001-0001-000000000001', '2026-01-06', 'Reyes Magos', 'nacional', 2026),
('a1b2c3d4-0001-0001-0001-000000000001', '2026-03-19', 'San José', 'nacional', 2026),
('a1b2c3d4-0001-0001-0001-000000000001', '2026-04-02', 'Jueves Santo', 'nacional', 2026),
('a1b2c3d4-0001-0001-0001-000000000001', '2026-04-03', 'Viernes Santo', 'nacional', 2026),
('a1b2c3d4-0001-0001-0001-000000000001', '2026-05-01', 'Día del Trabajador', 'nacional', 2026),
('a1b2c3d4-0001-0001-0001-000000000001', '2026-08-15', 'Asunción de la Virgen', 'nacional', 2026),
('a1b2c3d4-0001-0001-0001-000000000001', '2026-10-12', 'Fiesta Nacional de España', 'nacional', 2026),
('a1b2c3d4-0001-0001-0001-000000000001', '2026-11-02', 'Día de Todos los Santos', 'nacional', 2026),
('a1b2c3d4-0001-0001-0001-000000000001', '2026-12-07', 'Inmaculada Concepción (lunes)', 'nacional', 2026),
('a1b2c3d4-0001-0001-0001-000000000001', '2026-12-25', 'Navidad', 'nacional', 2026),
-- Andalucía
('a1b2c3d4-0001-0001-0001-000000000001', '2026-02-28', 'Día de Andalucía', 'provincial', 2026),
-- Huelva local
('a1b2c3d4-0001-0001-0001-000000000001', '2026-08-03', 'Fiestas Colombinas', 'local', 2026),
('a1b2c3d4-0001-0001-0001-000000000001', '2026-09-08', 'Virgen de la Cinta', 'local', 2026);

-- ============================================================
-- DATOS DEMO - EMPLEADOS (42 empleados, 7 por letra)
-- passwords: todos usan 'Turnox2026' hasheado como texto plano para demo
-- En producción usar bcrypt
-- ============================================================

-- LETRA A (7 empleados)
INSERT INTO empleados (id, planta_id, letra_id, area_principal_id, nombre, apellidos, username, password_hash) VALUES
('emp-a001-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000001', 'a1b2c3d4-0002-0001-0001-000000000001', 'Carlos', 'Moreno Díaz', 'c.moreno', 'Turnox2026'),
('emp-a002-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000001', 'a1b2c3d4-0002-0001-0001-000000000002', 'Laura', 'Sánchez Pérez', 'l.sanchez', 'Turnox2026'),
('emp-a003-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000001', 'a1b2c3d4-0002-0001-0001-000000000003', 'Miguel', 'García Ruiz', 'm.garcia', 'Turnox2026'),
('emp-a004-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000001', 'a1b2c3d4-0002-0001-0001-000000000004', 'Ana', 'López Martín', 'a.lopez', 'Turnox2026'),
('emp-a005-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000001', 'a1b2c3d4-0002-0001-0001-000000000005', 'José', 'Romero Vega', 'j.romero', 'Turnox2026'),
('emp-a006-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000001', 'a1b2c3d4-0002-0001-0001-000000000006', 'María', 'Fernández Cruz', 'm.fernandez', 'Turnox2026'),
('emp-a007-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000001', 'a1b2c3d4-0002-0001-0001-000000000004', 'Antonio', 'Jiménez Moya', 'a.jimenez', 'Turnox2026'),

-- LETRA B (7 empleados)
('emp-b001-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000002', 'a1b2c3d4-0002-0001-0001-000000000001', 'Pedro', 'González Alba', 'p.gonzalez', 'Turnox2026'),
('emp-b002-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000002', 'a1b2c3d4-0002-0001-0001-000000000002', 'Carmen', 'Vargas Reyes', 'c.vargas', 'Turnox2026'),
('emp-b003-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000002', 'a1b2c3d4-0002-0001-0001-000000000003', 'Raúl', 'Torres Blanco', 'r.torres', 'Turnox2026'),
('emp-b004-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000002', 'a1b2c3d4-0002-0001-0001-000000000004', 'Isabel', 'Molina Cano', 'i.molina', 'Turnox2026'),
('emp-b005-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000002', 'a1b2c3d4-0002-0001-0001-000000000005', 'Francisco', 'Navarro Pons', 'f.navarro', 'Turnox2026'),
('emp-b006-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000002', 'a1b2c3d4-0002-0001-0001-000000000006', 'Elena', 'Ramos Fuentes', 'e.ramos', 'Turnox2026'),
('emp-b007-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000002', 'a1b2c3d4-0002-0001-0001-000000000005', 'David', 'Serrano Gil', 'd.serrano', 'Turnox2026'),

-- LETRA C (7 empleados)
('emp-c001-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000003', 'a1b2c3d4-0002-0001-0001-000000000001', 'Manuel', 'Delgado Vera', 'm.delgado', 'Turnox2026'),
('emp-c002-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000003', 'a1b2c3d4-0002-0001-0001-000000000002', 'Rosa', 'Ortega Leal', 'r.ortega', 'Turnox2026'),
('emp-c003-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000003', 'a1b2c3d4-0002-0001-0001-000000000003', 'Javier', 'Castillo Mora', 'j.castillo', 'Turnox2026'),
('emp-c004-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000003', 'a1b2c3d4-0002-0001-0001-000000000004', 'Pilar', 'Herrera Santos', 'p.herrera', 'Turnox2026'),
('emp-c005-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000003', 'a1b2c3d4-0002-0001-0001-000000000005', 'Roberto', 'Medina Ríos', 'r.medina', 'Turnox2026'),
('emp-c006-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000003', 'a1b2c3d4-0002-0001-0001-000000000006', 'Lucía', 'Guerrero Palma', 'l.guerrero', 'Turnox2026'),
('emp-c007-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000003', 'a1b2c3d4-0002-0001-0001-000000000003', 'Sergio', 'Flores Parra', 's.flores', 'Turnox2026'),

-- LETRA D (7 empleados)
('emp-d001-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000004', 'a1b2c3d4-0002-0001-0001-000000000001', 'Álvaro', 'Ibáñez Rueda', 'a.ibanez', 'Turnox2026'),
('emp-d002-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000004', 'a1b2c3d4-0002-0001-0001-000000000002', 'Cristina', 'Muñoz Soler', 'c.munoz', 'Turnox2026'),
('emp-d003-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000004', 'a1b2c3d4-0002-0001-0001-000000000003', 'Fernando', 'Aguilar Mesa', 'f.aguilar', 'Turnox2026'),
('emp-d004-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000004', 'a1b2c3d4-0002-0001-0001-000000000004', 'Natalia', 'Campos Duro', 'n.campos', 'Turnox2026'),
('emp-d005-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000004', 'a1b2c3d4-0002-0001-0001-000000000005', 'Héctor', 'Vidal Llanos', 'h.vidal', 'Turnox2026'),
('emp-d006-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000004', 'a1b2c3d4-0002-0001-0001-000000000006', 'Silvia', 'Pascual Nieto', 's.pascual', 'Turnox2026'),
('emp-d007-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000004', 'a1b2c3d4-0002-0001-0001-000000000004', 'Andrés', 'Rubio Cuesta', 'a.rubio', 'Turnox2026'),

-- LETRA E (7 empleados)
('emp-e001-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000005', 'a1b2c3d4-0002-0001-0001-000000000001', 'Tomás', 'Carrasco Bernal', 't.carrasco', 'Turnox2026'),
('emp-e002-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000005', 'a1b2c3d4-0002-0001-0001-000000000002', 'Beatriz', 'Prieto Cano', 'b.prieto', 'Turnox2026'),
('emp-e003-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000005', 'a1b2c3d4-0002-0001-0001-000000000003', 'Ignacio', 'Bravo Salas', 'i.bravo', 'Turnox2026'),
('emp-e004-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000005', 'a1b2c3d4-0002-0001-0001-000000000004', 'Patricia', 'Domínguez Vela', 'p.dominguez', 'Turnox2026'),
('emp-e005-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000005', 'a1b2c3d4-0002-0001-0001-000000000005', 'Marcos', 'Lozano Toro', 'm.lozano', 'Turnox2026'),
('emp-e006-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000005', 'a1b2c3d4-0002-0001-0001-000000000006', 'Verónica', 'Alonso Pino', 'v.alonso', 'Turnox2026'),
('emp-e007-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000005', 'a1b2c3d4-0002-0001-0001-000000000003', 'Diego', 'Cortés Malo', 'd.cortes', 'Turnox2026'),

-- LETRA ER (7 empleados)
('emp-er01-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000006', 'a1b2c3d4-0002-0001-0001-000000000001', 'Pablo', 'Santana Dios', 'p.santana', 'Turnox2026'),
('emp-er02-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000006', 'a1b2c3d4-0002-0001-0001-000000000002', 'Marta', 'León Cid', 'm.leon', 'Turnox2026'),
('emp-er03-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000006', 'a1b2c3d4-0002-0001-0001-000000000003', 'Rubén', 'Vicente Polo', 'r.vicente', 'Turnox2026'),
('emp-er04-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000006', 'a1b2c3d4-0002-0001-0001-000000000004', 'Nuria', 'Gallego Mir', 'n.gallego', 'Turnox2026'),
('emp-er05-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000006', 'a1b2c3d4-0002-0001-0001-000000000005', 'Víctor', 'Cano Roca', 'v.cano', 'Turnox2026'),
('emp-er06-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000006', 'a1b2c3d4-0002-0001-0001-000000000006', 'Inés', 'Marín Abad', 'i.marin', 'Turnox2026'),
('emp-er07-0000-0000-0000-000000000001', 'a1b2c3d4-0001-0001-0001-000000000001', 'a1b2c3d4-0003-0001-0001-000000000006', 'a1b2c3d4-0002-0001-0001-000000000005', 'Hugo', 'Peña Lago', 'h.pena', 'Turnox2026');

-- ============================================================
-- POLIVALENCIAS
-- JT y Control: sin polivalencias
-- RX/RG, Área A, Área B, Azufre: 2-3 polivalencias cruzadas
-- ============================================================

-- Empleados de RX/RG (area 3) → polivalentes en Área A y Área B
INSERT INTO polivalencias (empleado_id, area_id) VALUES
('emp-a003-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000004'), -- m.garcia → Área A
('emp-a003-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000005'), -- m.garcia → Área B
('emp-b003-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000004'), -- r.torres → Área A
('emp-b003-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000006'), -- r.torres → Azufre
('emp-c003-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000005'), -- j.castillo → Área B
('emp-c003-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000006'), -- j.castillo → Azufre
('emp-c007-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000004'), -- s.flores → Área A
('emp-c007-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000005'), -- s.flores → Área B
('emp-d003-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000004'), -- f.aguilar → Área A
('emp-d003-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000006'), -- f.aguilar → Azufre
('emp-e003-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000004'), -- i.bravo → Área A
('emp-e003-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000005'), -- i.bravo → Área B
('emp-e007-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000005'), -- d.cortes → Área B
('emp-e007-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000006'), -- d.cortes → Azufre
('emp-er03-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000004'), -- r.vicente → Área A
('emp-er03-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000006'), -- r.vicente → Azufre

-- Empleados de Área A (area 4) → polivalentes en RX/RG, Área B o Azufre
('emp-a004-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000003'), -- a.lopez → RX/RG
('emp-a004-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000005'), -- a.lopez → Área B
('emp-a007-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000003'), -- a.jimenez → RX/RG
('emp-a007-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000006'), -- a.jimenez → Azufre
('emp-b004-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000003'), -- i.molina → RX/RG
('emp-b004-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000006'), -- i.molina → Azufre
('emp-c004-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000003'), -- p.herrera → RX/RG
('emp-c004-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000005'), -- p.herrera → Área B
('emp-d004-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000005'), -- n.campos → Área B
('emp-d004-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000006'), -- n.campos → Azufre
('emp-d007-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000003'), -- a.rubio → RX/RG
('emp-d007-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000006'), -- a.rubio → Azufre
('emp-e004-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000003'), -- p.dominguez → RX/RG
('emp-e004-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000005'), -- p.dominguez → Área B
('emp-er04-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000003'), -- n.gallego → RX/RG
('emp-er04-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000005'), -- n.gallego → Área B

-- Empleados de Área B (area 5) → polivalentes en RX/RG, Área A o Azufre
('emp-a005-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000003'), -- j.romero → RX/RG
('emp-a005-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000006'), -- j.romero → Azufre
('emp-b005-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000004'), -- f.navarro → Área A
('emp-b005-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000006'), -- f.navarro → Azufre
('emp-b007-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000003'), -- d.serrano → RX/RG
('emp-b007-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000004'), -- d.serrano → Área A
('emp-c005-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000003'), -- r.medina → RX/RG
('emp-c005-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000006'), -- r.medina → Azufre
('emp-d005-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000004'), -- h.vidal → Área A
('emp-d005-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000006'), -- h.vidal → Azufre
('emp-e005-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000003'), -- m.lozano → RX/RG
('emp-e005-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000004'), -- m.lozano → Área A
('emp-er05-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000004'), -- v.cano → Área A
('emp-er05-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000006'), -- v.cano → Azufre

-- Empleados de Azufre (area 6) → polivalentes en RX/RG, Área A o Área B
('emp-a006-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000004'), -- m.fernandez → Área A
('emp-a006-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000005'), -- m.fernandez → Área B
('emp-b006-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000003'), -- e.ramos → RX/RG
('emp-b006-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000004'), -- e.ramos → Área A
('emp-c006-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000003'), -- l.guerrero → RX/RG
('emp-c006-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000005'), -- l.guerrero → Área B
('emp-d006-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000004'), -- s.pascual → Área A
('emp-d006-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000005'), -- s.pascual → Área B
('emp-e006-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000003'), -- v.alonso → RX/RG
('emp-e006-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000004'), -- v.alonso → Área A
('emp-er06-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000004'), -- i.marin → Área A
('emp-er06-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000005'), -- i.marin → Área B
('emp-er07-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000003'), -- h.pena → RX/RG
('emp-er07-0000-0000-0000-000000000001', 'a1b2c3d4-0002-0001-0001-000000000006'); -- h.pena → Azufre

-- ============================================================
-- VACACIONES RONDAS 2026
-- ============================================================
INSERT INTO vacaciones_rondas (planta_id, año, numero_ronda, nombre, descripcion, dias, abierta) VALUES
('a1b2c3d4-0001-0001-0001-000000000001', 2026, 1, 'Primera Ronda', '6 días consecutivos - orden por antigüedad', 6, false),
('a1b2c3d4-0001-0001-0001-000000000001', 2026, 2, 'Segunda Ronda', '6 días consecutivos (3 compensatorio + 3 relevo) - orden inverso', 6, false),
('a1b2c3d4-0001-0001-0001-000000000001', 2026, 3, 'PRL', '4 días sueltos de PRL', 4, false);
