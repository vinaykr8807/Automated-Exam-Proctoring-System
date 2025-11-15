-- Fix hardcoded student names issue
-- This script will help identify and fix any hardcoded "divyank" entries

-- 1. Check for hardcoded names in students table
SELECT id, name, email, student_id 
FROM public.students 
WHERE name ILIKE '%divyank%';

-- 2. Check for hardcoded names in violations table
SELECT id, student_id, details->>'student_name' as violation_student_name, details
FROM public.violations 
WHERE details->>'student_name' ILIKE '%divyank%'
LIMIT 10;

-- 3. Check for hardcoded names in exams table
SELECT e.id, e.student_id, s.name as student_name
FROM public.exams e
LEFT JOIN public.students s ON e.student_id = s.id
WHERE s.name ILIKE '%divyank%';

-- 4. Update violations to use correct student names from students table
-- This will fix violations that have wrong student names
UPDATE public.violations 
SET details = jsonb_set(
    details, 
    '{student_name}', 
    to_jsonb(s.name)
)
FROM public.students s
WHERE violations.student_id = s.id
AND s.name IS NOT NULL
AND s.name != ''
AND (
    violations.details->>'student_name' IS NULL 
    OR violations.details->>'student_name' = 'Unknown Student'
    OR violations.details->>'student_name' ILIKE '%divyank%'
);

-- 5. Check results after update
SELECT DISTINCT details->>'student_name' as student_names
FROM public.violations 
WHERE details->>'student_name' IS NOT NULL
ORDER BY student_names;