-- =====================================================
-- CHECK EXISTING VIOLATION TYPES IN DATABASE
-- Run this FIRST to see what violation types you have
-- =====================================================

-- Check what violation types exist in your database
SELECT DISTINCT violation_type, COUNT(*) as count 
FROM public.violations 
GROUP BY violation_type 
ORDER BY count DESC;

-- If you see any violation types that are NOT in the list below, 
-- you'll need to update them before running the migration:
-- 
-- Allowed types:
-- - looking_away, gaze_away
-- - no_person, no_face
-- - phone_detected, phone
-- - multiple_faces, multiple_person
-- - object_detected, object, book_detected
-- - tab_switch
-- - copy_paste
-- - audio_violation, audio_noise, excessive_noise
-- - eye_movement (new)
-- - shoulder_movement (new)
-- - window_blur

