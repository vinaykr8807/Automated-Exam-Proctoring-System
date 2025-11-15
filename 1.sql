-- Add grade_letter column to exams table if it doesn't exist
ALTER TABLE public.exams
ADD COLUMN IF NOT EXISTS grade_letter VARCHAR(1) CHECK (grade_letter IN ('A', 'B', 'C', 'D', 'F'));

-- Add comment for documentation
COMMENT ON COLUMN public.exams.grade_letter IS 'Letter grade (A, B, C, D, F) based on percentage score';

-- Add subject_name column to exams table if it doesn't exist (for direct storage)
ALTER TABLE public.exams
ADD COLUMN IF NOT EXISTS subject_name TEXT;

COMMENT ON COLUMN public.exams.subject_name IS 'Subject name for the exam';

-- Add student_id column to students table if it doesn't exist (for unique student identifier)
ALTER TABLE public.students
ADD COLUMN IF NOT EXISTS student_id TEXT UNIQUE;

COMMENT ON COLUMN public.students.student_id IS 'Unique student identifier (e.g., roll number)';

