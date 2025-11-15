-- Ensure extension for gen_random_uuid() exists (run once if not present)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Students table (create only if it doesn't exist)
CREATE TABLE IF NOT EXISTS public.students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id TEXT UNIQUE,
  name TEXT,
  email TEXT UNIQUE,
  registered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ensure required columns exist (add if missing)
ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS student_id TEXT,
  ADD COLUMN IF NOT EXISTS name TEXT,
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS registered_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Ensure unique constraint on student_id (use index if constraint exists)
DO $$
BEGIN
  -- Add unique constraint only if not present
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    JOIN pg_namespace n ON t.relnamespace = n.oid
    WHERE c.contype = 'u'
      AND n.nspname = 'public'
      AND t.relname = 'students'
      AND EXISTS (
        SELECT 1 FROM unnest(c.conkey) AS cols(colnum)
        WHERE true
      )
      -- crude check: ensure a unique constraint exists on student_id specifically
      AND (
        SELECT string_agg(att.attname, ',')
        FROM unnest(c.conkey) WITH ORDINALITY AS ck(attnum, ord)
        JOIN pg_attribute att ON att.attnum = ck.attnum AND att.attrelid = t.oid
      ) = 'student_id'
  ) THEN
    BEGIN
      ALTER TABLE public.students ADD CONSTRAINT students_student_id_unique UNIQUE (student_id);
    EXCEPTION WHEN duplicate_object THEN
      -- no-op if created concurrently
    END;
  END IF;
END$$;

-- Sessions table (create only if missing)
CREATE TABLE IF NOT EXISTS public.sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id TEXT NOT NULL,
  student_name TEXT NOT NULL,
  start_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  end_time TIMESTAMP WITH TIME ZONE,
  status TEXT DEFAULT 'active',
  calibrated_pitch FLOAT DEFAULT 0.0,
  calibrated_yaw FLOAT DEFAULT 0.0,
  total_frames INTEGER DEFAULT 0,
  violation_count INTEGER DEFAULT 0
);

-- Violations table (create only if missing)
CREATE TABLE IF NOT EXISTS public.violations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL,
  student_id TEXT NOT NULL,
  student_name TEXT NOT NULL,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  violation_type TEXT NOT NULL,
  severity TEXT NOT NULL,
  message TEXT NOT NULL,
  snapshot_url TEXT,
  head_pose JSONB
);