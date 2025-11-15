import cv2
import mediapipe as mp
import numpy as np
from ultralytics import YOLO
import base64
from typing import Dict, Optional, Tuple
import time
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

class ProctoringService:
    """
    AI-powered proctoring service using MediaPipe and YOLOv8n
    Detects: looking away, multiple people, prohibited objects (phone, book)
    """
    
    def __init__(self):
        # Initialize MediaPipe with optimized settings for real-time performance
        self.mp_face_mesh = mp.solutions.face_mesh.FaceMesh(
            refine_landmarks=True,
            min_detection_confidence=0.3,  # Lowered for better detection
            min_tracking_confidence=0.3   # Lowered for better tracking
        )
        self.mp_face_detection = mp.solutions.face_detection.FaceDetection(
            min_detection_confidence=0.3  # Lowered for better detection
        )
        
        # Initialize YOLO model with optimized settings for real-time performance
        try:
            self.yolo_model = YOLO('models/yolov8n.pt')
            self.yolo_model.conf = 0.3  # Lowered confidence threshold for better detection
            self.yolo_model.iou = 0.5   # IoU threshold for NMS
            print("✅ YOLO model loaded successfully")
        except Exception as e:
            print(f"❌ YOLO model loading failed: {e}")
            self.yolo_model = None
        
        # 3D Model points for head pose estimation
        self.model_points = np.array([
            (0.0, 0.0, 0.0),
            (0.0, -330.0, -65.0),
            (-225.0, 170.0, -135.0),
            (225.0, 170.0, -135.0),
            (-150.0, -150.0, -125.0),
            (150.0, -150.0, -125.0)
        ], dtype=np.float64)
        
        # Thresholds (STRICT - Only flag significant head turns)
        self.MAX_YAW_OFFSET = 45   # Degrees - head turning left/right (more lenient - only flag significant turns)
        self.MAX_PITCH_OFFSET = 35  # Degrees - head tilting up/down (more lenient - only flag significant tilts)
        
        # Detection confidence thresholds (optimized for real-time)
        self.OBJECT_CONFIDENCE_THRESHOLD = 0.3  # Lowered for better detection
        self.FACE_CONFIDENCE_THRESHOLD = 0.3    # Lowered for better detection
        
        # Snapshot throttle per session: only allow snapshot every 2 seconds
        self.SNAPSHOT_INTERVAL_SEC = 2.0
        self.last_snapshot_time_by_session: Dict[str, float] = {}
        
        # Head pose tracking for sustained looking away
        self.head_pose_tracking: Dict[str, Dict] = {}
        self.HEAD_AWAY_DURATION_THRESHOLD_SEC = 10.0  # 10 seconds of continuously looking away
        
    def estimate_head_pose(self, landmarks, width: int, height: int) -> Optional[Tuple[float, float, float]]:
        """
        Estimate head pose (pitch, yaw, roll) from facial landmarks
        """
        try:
            image_points = np.array([
                (landmarks[1].x * width, landmarks[1].y * height),
                (landmarks[152].x * width, landmarks[152].y * height),
                (landmarks[33].x * width, landmarks[33].y * height),
                (landmarks[263].x * width, landmarks[263].y * height),
                (landmarks[61].x * width, landmarks[61].y * height),
                (landmarks[291].x * width, landmarks[291].y * height)
            ], dtype=np.float64)

            focal_length = width
            camera_matrix = np.array([
                [focal_length, 0, width / 2],
                [0, focal_length, height / 2],
                [0, 0, 1]
            ], dtype=np.float64)

            success, rotation_vector, _ = cv2.solvePnP(
                self.model_points, 
                image_points, 
                camera_matrix, 
                np.zeros((4, 1))
            )
            
            if not success:
                return None

            rmat, _ = cv2.Rodrigues(rotation_vector)
            angles, _, _, _, _, _ = cv2.RQDecomp3x3(rmat)
            return angles  # pitch, yaw, roll
        except Exception as e:
            print(f"Head pose estimation error: {e}")
            return None

    def is_looking_away(self, pitch: float, yaw: float, calibrated_pitch: float, calibrated_yaw: float) -> Tuple[bool, float, Optional[str]]:
        """
        Check if user is looking away from camera based on calibrated values.
        This version strictly checks for left/right head turns (yaw).
        Returns (is_looking_away, confidence_score, direction)
        """
        yaw_offset = yaw - calibrated_yaw
        
        # Determine direction of head movement (left or right)
        direction = 'right' if yaw_offset > 0 else 'left'
        
        # Calculate absolute offsets
        abs_yaw_offset = abs(yaw_offset)
        
        # Calculate confidence score based on how far the head is turned
        # Normalize offset to 0-1 range
        normalized_yaw = min(abs_yaw_offset / self.MAX_YAW_OFFSET, 1.0)
        confidence_score = normalized_yaw # Confidence is directly proportional to yaw turn
        
        # Stricter threshold for left/right head turns to reduce sensitivity
        HEAD_TURN_THRESHOLD_YAW = 35.0  # degrees
        
        significant_yaw_deviation = abs_yaw_offset > HEAD_TURN_THRESHOLD_YAW
        
        # Flag if head is turned away
        is_looking_away = significant_yaw_deviation
        
        # If not looking away, direction should be None
        if not is_looking_away:
            direction = None

        return is_looking_away, confidence_score, direction
    
    def track_head_pose(self, session_id: str, is_looking_away: bool, direction: str, current_time: float) -> Optional[Dict]:
        """
        Track head pose over time. Returns a single violation if the user looks away continuously for a set duration.
        """
        if is_looking_away and direction:
            if session_id not in self.head_pose_tracking:
                # Start tracking when user starts looking away
                self.head_pose_tracking[session_id] = {
                    'start_time': current_time,
                    'direction': direction,
                    'violation_reported': False  # Flag to ensure violation is reported only once
                }
                return None

            tracking_data = self.head_pose_tracking[session_id]
            
            # If direction changes, reset start time and reported flag
            if tracking_data['direction'] != direction:
                tracking_data['start_time'] = current_time
                tracking_data['direction'] = direction
                tracking_data['violation_reported'] = False # Reset flag on direction change

            duration = current_time - tracking_data['start_time']

            # Trigger violation only if duration is met AND it hasn't been reported for this event yet
            if duration >= self.HEAD_AWAY_DURATION_THRESHOLD_SEC and not tracking_data.get('violation_reported'):
                tracking_data['violation_reported'] = True  # Mark as reported
                return {
                    'type': 'looking_away',
                    'severity': 'high',
                    'message': f'Head turned {direction} away from screen for {duration:.1f} seconds.',
                    'duration': duration,
                    'direction': direction
                }
        else:
            # User is not looking away, so reset tracking
            if session_id in self.head_pose_tracking:
                del self.head_pose_tracking[session_id]
        
        return None

    def detect_multiple_faces(self, detections) -> bool:
        """
        Check if multiple faces are detected
        """
        return len(detections) > 1 if detections else False

    def detect_prohibited_objects(self, frame: np.ndarray) -> Dict[str, any]:
        """
        Detect prohibited objects (cell phone, book) using YOLOv8
        Returns dict with detection info and annotated frame
        """
        detections = {
            'phone_detected': False,
            'book_detected': False,
            'objects': []
        }
        
        # Check if YOLO model is available
        if self.yolo_model is None:
            print("⚠️ YOLO model not available, skipping object detection")
            detections['annotated_frame'] = frame
            return detections
        
        try:
            # Run YOLO detection with confidence threshold
            yolo_results = self.yolo_model(
                frame, 
                stream=True, 
                verbose=False,
                conf=self.OBJECT_CONFIDENCE_THRESHOLD
            )
            
            for result in yolo_results:
                if result.boxes is None or len(result.boxes) == 0:
                    continue
                    
                for box in result.boxes:
                    cls = result.names[int(box.cls[0])]
                    confidence = float(box.conf[0])
                    
                    # Only process if confidence meets threshold
                    if confidence < self.OBJECT_CONFIDENCE_THRESHOLD:
                        continue
                    
                    x1, y1, x2, y2 = map(int, box.xyxy[0])
                    
                    # Detect cell phone (including variations)
                    if cls in ["cell phone", "phone", "mobile"]:
                        detections['objects'].append({
                            'type': 'cell phone',
                            'confidence': confidence,
                            'bbox': [x1, y1, x2, y2]
                        })
                        detections['phone_detected'] = True
                        
                        # Draw bounding box
                        cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 0, 255), 3)
                        cv2.putText(frame, f"PHONE {confidence:.2f}", (x1, y1 - 10),
                                  cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
                    
                    # Detect book
                    elif cls == "book":
                        detections['objects'].append({
                            'type': 'book',
                            'confidence': confidence,
                            'bbox': [x1, y1, x2, y2]
                        })
                        detections['book_detected'] = True
                        
                        # Draw bounding box
                        cv2.rectangle(frame, (x1, y1), (x2, y2), (255, 0, 0), 3)
                        cv2.putText(frame, f"BOOK {confidence:.2f}", (x1, y1 - 10),
                                  cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 0, 0), 2)
        except Exception as e:
            print(f"Object detection error: {e}")
        
        detections['annotated_frame'] = frame
        return detections

    def calibrate_head_pose(self, frame: np.ndarray) -> Dict:
        """
        Calibrate head pose from a frame
        Returns calibration values
        """
        try:
            height, width, _ = frame.shape
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            
            face_mesh_results = self.mp_face_mesh.process(rgb_frame)
            if face_mesh_results.multi_face_landmarks:
                landmarks = face_mesh_results.multi_face_landmarks[0].landmark
                angles = self.estimate_head_pose(landmarks, width, height)
                
                if angles:
                    pitch, yaw, roll = angles
                    return {
                        'success': True,
                        'pitch': float(pitch),
                        'yaw': float(yaw),
                        'roll': float(roll)
                    }
            
            return {'success': False, 'message': 'No face detected for calibration'}
        except Exception as e:
            return {'success': False, 'message': f'Calibration error: {str(e)}'}
    
    def check_environment(self, frame: np.ndarray) -> Dict:
        """
        Check environment lighting and face detection
        """
        try:
            height, width, _ = frame.shape
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            
            # Check lighting (convert to grayscale and check brightness)
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            brightness = np.mean(gray)
            lighting_ok = 40 < brightness < 220  # Acceptable range
            
            # Check face detection
            face_detection_results = self.mp_face_detection.process(rgb_frame)
            face_detected = face_detection_results.detections is not None and len(face_detection_results.detections) > 0
            
            # Check if face is centered
            face_centered = False
            if face_detected:
                detection = face_detection_results.detections[0]
                bbox = detection.location_data.relative_bounding_box
                center_x = bbox.xmin + bbox.width / 2
                center_y = bbox.ymin + bbox.height / 2
                face_centered = (0.3 < center_x < 0.7) and (0.2 < center_y < 0.7)
            
            message = []
            if not lighting_ok:
                if brightness < 40:
                    message.append("Lighting too dark")
                else:
                    message.append("Lighting too bright")
            if not face_detected:
                message.append("No face detected")
            elif not face_centered:
                message.append("Face not centered")
            
            if not message:
                message.append("Environment check passed")
            
            return {
                'lighting_ok': lighting_ok,
                'face_detected': face_detected,
                'face_centered': face_centered,
                'message': ', '.join(message),
                'brightness': float(brightness)
            }
        except Exception as e:
            return {
                'lighting_ok': False,
                'face_detected': False,
                'face_centered': False,
                'message': f'Environment check error: {str(e)}'
            }

    def process_frame(self, frame: np.ndarray, session_id: str, calibrated_pitch: float, calibrated_yaw: float) -> Dict:
        """
        Process a single frame for all violations
        Returns comprehensive violation report
        """
        try:
            if frame is None:
                return {'error': 'Invalid frame data'}
            
            height, width, _ = frame.shape
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            
            # Initialize result
            result = {
                'timestamp': datetime.utcnow().isoformat(),
                'violations': [],
                'head_pose': None,
                'face_count': 0,
                'looking_away': False,
                'multiple_faces': False,
                'no_person': False,
                'phone_detected': False,
                'book_detected': False,
                'snapshot_base64': None
            }
            
            # Detect multiple faces first
            face_detection_results = self.mp_face_detection.process(rgb_frame)
            if face_detection_results.detections:
                result['face_count'] = len(face_detection_results.detections)
                
                if self.detect_multiple_faces(face_detection_results.detections):
                    result['multiple_faces'] = True
                    face_count = len(face_detection_results.detections)
                    result['violations'].append({
                        'type': 'multiple_person',  # Use multiple_person for consistency
                        'severity': 'high',
                        'message': f'{face_count} people detected in frame'
                    })
                    cv2.putText(frame, "MULTIPLE PEOPLE DETECTED!", (50, 100),
                              cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
            else:
                # No person detected - but check if frame is too dark/black (webcam off)
                # Calculate frame brightness to avoid false positives when webcam is black
                gray_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                mean_brightness = np.mean(gray_frame)
                BRIGHTNESS_THRESHOLD = 20  # If frame is too dark, don't flag as violation
                
                # Only flag as no_person if frame has reasonable brightness (webcam is on but no person)
                if mean_brightness >= BRIGHTNESS_THRESHOLD:
                    result['no_person'] = True
                    result['violations'].append({
                        'type': 'no_person',
                        'severity': 'medium',
                        'message': f'No person detected in frame (brightness: {mean_brightness:.1f})'
                    })
                    cv2.putText(frame, "NO PERSON DETECTED!", (50, 50),
                              cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
                else:
                    # Frame is too dark - likely webcam is off/black, don't flag as violation
                    logger.info(f"⚠️  Frame too dark (brightness: {mean_brightness:.1f}), skipping no_person violation")
            
            # Process face mesh for head pose (only if single person detected)
            if result['face_count'] == 1:
                face_mesh_results = self.mp_face_mesh.process(rgb_frame)
                if face_mesh_results.multi_face_landmarks:
                    landmarks = face_mesh_results.multi_face_landmarks[0].landmark
                    angles = self.estimate_head_pose(landmarks, width, height)
                    
                    if angles:
                        pitch, yaw, roll = angles
                        result['head_pose'] = {
                            'pitch': float(pitch),
                            'yaw': float(yaw),
                            'roll': float(roll)
                        }
                        
                        # Check if looking away
                        is_looking_away, confidence_score, direction = self.is_looking_away(pitch, yaw, calibrated_pitch, calibrated_yaw)
                        
                        # Track head pose for sustained violation
                        current_time = time.time()
                        head_pose_violation = self.track_head_pose(session_id, is_looking_away, direction, current_time)

                        if head_pose_violation:
                            result['violations'].append(head_pose_violation)
                            result['looking_away'] = True
                            cv2.putText(frame, f"HEAD TURNED AWAY! ({head_pose_violation['duration']:.1f}s)", (50, 150), 
                                      cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
            
            # Detect prohibited objects
            object_detection = self.detect_prohibited_objects(frame)
            result['phone_detected'] = object_detection['phone_detected']
            result['book_detected'] = object_detection['book_detected']
            
            if object_detection['phone_detected']:
                result['violations'].append({
                    'type': 'phone_detected',
                    'severity': 'high',
                    'message': 'Mobile phone detected'
                })
            
            if object_detection['book_detected']:
                result['violations'].append({
                    'type': 'book_detected',
                    'severity': 'medium',
                    'message': 'Book detected'
                })
            
            # If violations exist, capture snapshot (throttled per session)
            if result['violations']:
                now_ts = time.time()
                last_ts = self.last_snapshot_time_by_session.get(session_id, 0.0)
                if (now_ts - last_ts) >= self.SNAPSHOT_INTERVAL_SEC:
                    annotated_frame = object_detection['annotated_frame']
                    _, buffer = cv2.imencode('.jpg', annotated_frame)
                    result['snapshot_base64'] = base64.b64encode(buffer).decode('utf-8')
                    self.last_snapshot_time_by_session[session_id] = now_ts
            
            return result
            
        except Exception as e:
            return {'error': f'Frame processing error: {str(e)}'}

    def calibrate_from_frame(self, frame_base64: str) -> Optional[Tuple[float, float]]:
        """
        Extract calibration values (pitch, yaw) from a frame
        """
        try:
            # Decode base64 frame
            frame_data = base64.b64decode(frame_base64.split(',')[1] if ',' in frame_base64 else frame_base64)
            nparr = np.frombuffer(frame_data, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if frame is None:
                return None
            
            height, width, _ = frame.shape
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            
            face_mesh_results = self.mp_face_mesh.process(rgb_frame)
            if face_mesh_results.multi_face_landmarks:
                landmarks = face_mesh_results.multi_face_landmarks[0].landmark
                angles = self.estimate_head_pose(landmarks, width, height)
                
                if angles:
                    pitch, yaw, _ = angles
                    return (float(pitch), float(yaw))
            
            return None
        except Exception as e:
            print(f"Calibration error: {e}")
            return None

# Global instance
proctoring_service = ProctoringService()
