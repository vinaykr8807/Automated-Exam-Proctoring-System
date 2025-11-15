-- =====================================================
-- ADD EYE MOVEMENT AND SHOULDER MOVEMENT VIOLATION TYPES
-- =====================================================

-- Step 1: First, let's see what violation types exist (for debugging)
-- You can run this query separately to check:
-- SELECT DISTINCT violation_type FROM public.violations;

-- Step 2: Drop the old constraint FIRST (before adding new one)
ALTER TABLE public.violations
DROP CONSTRAINT IF EXISTS violations_violation_type_check;

-- Step 3: Update any violation types that don't match standard names
-- This handles any unexpected violation types in your database
UPDATE public.violations 
SET violation_type = 'object_detected' 
WHERE violation_type NOT IN (
  'gaze_away', 'looking_away', 'multiple_faces', 'multiple_person',
  'no_face', 'no_person', 'phone_detected', 'phone', 'object_detected', 
  'object', 'book_detected', 'tab_switch', 'copy_paste', 'audio_violation',
  'audio_noise', 'excessive_noise', 'eye_movement', 'shoulder_movement', 'window_blur'
);

-- Step 4: Add the new constraint with ALL possible violation types
ALTER TABLE public.violations
ADD CONSTRAINT violations_violation_type_check 
CHECK (violation_type IN (
  -- Standard violation types (used by backend)
  'looking_away',        -- Student looking away from screen
  'no_person',           -- No person detected in frame
  'phone_detected',      -- Mobile phone detected
  'book_detected',       -- Book detected
  'multiple_faces',      -- Multiple people detected
  'object_detected',     -- Prohibited object detected
  'tab_switch',         -- Browser tab switched
  'copy_paste',         -- Copy/paste detected
  'audio_violation',    -- Audio/sound violation
  -- Alternative naming (for backward compatibility)
  'gaze_away',
  'no_face',
  'multiple_person',
  'phone',
  'object',
  'audio_noise',
  'excessive_noise',
  -- New violation types
  'eye_movement',       -- Eye movement detected for extended period
  'shoulder_movement',  -- Continuous shoulder movement detected
  -- Additional types
  'window_blur'
));

-- Add comment for documentation
COMMENT ON COLUMN public.violations.violation_type IS 'Type of violation: gaze_away, multiple_faces, no_face, phone_detected, object_detected, tab_switch, copy_paste, audio_violation, eye_movement, shoulder_movement';

-- =====================================================
-- ENSURE STUDENT_ID COLUMN EXISTS IN STUDENTS TABLE
-- =====================================================

-- Add student_id column to students table if it doesn't exist
ALTER TABLE public.students
ADD COLUMN IF NOT EXISTS student_id TEXT;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_students_student_id ON public.students(student_id);

COMMENT ON COLUMN public.students.student_id IS 'Unique student identifier (e.g., roll number or email prefix)';

