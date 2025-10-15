@echo off
echo Starting ExamEye Shield Backend...
cd backend
call venv\Scripts\activate
python server.py
pause