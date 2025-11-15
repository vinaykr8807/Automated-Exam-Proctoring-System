import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Shield, Activity, Users, AlertTriangle, LogOut, Upload, RefreshCw, Download, FileText, Eye, Monitor } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { toast } from "sonner";
import { supabase } from "@/integrations/supabase/client";
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { pdfGenerator } from "@/utils/pdfGenerator";

const AdminDashboard = () => {
  const navigate = useNavigate();
  const [examSessions, setExamSessions] = useState<any[]>([]);
  const [violations, setViolations] = useState<any[]>([]);
  const [stats, setStats] = useState({
    totalSessions: 0,
    activeNow: 0,
    completed: 0,
    totalViolations: 0,
    avgViolationsPerStudent: 0,
    avgExamDuration: 0,
    totalStudents: 0,
  });
  const [chartData, setChartData] = useState<any[]>([]);
  const [studentsWithViolations, setStudentsWithViolations] = useState<any[]>([]);

  useEffect(() => {
    const isAuthenticated = sessionStorage.getItem('adminAuth');
    if (!isAuthenticated) {
      toast.error("Please login as admin");
      navigate('/admin/login');
      return;
    }

    loadDashboardData();

    // Real-time subscriptions
    const violationSubscription = supabase
      .channel('violations-channel')
      .on('postgres_changes', 
        { event: 'INSERT', schema: 'public', table: 'violations' },
        (payload) => {
          console.log('New violation:', payload);
          toast.error('New violation detected!');
          loadDashboardData();
        }
      )
      .subscribe();

    const examsSubscription = supabase
      .channel('exams-channel')
      .on('postgres_changes',
        { event: '*', schema: 'public', table: 'exams' },
        () => {
          loadDashboardData();
        }
      )
      .subscribe();

    // Auto-refresh every 10 seconds
    const interval = setInterval(loadDashboardData, 10000);

    return () => {
      clearInterval(interval);
      supabase.removeChannel(violationSubscription);
      supabase.removeChannel(examsSubscription);
    };
  }, [navigate]);

  const loadDashboardData = async () => {
    try {
      const { data: examsData, error: examsError } = await supabase
        .from('exams')
        .select(`
          *,
          students (
            name,
            email,
            student_id
          ),
          exam_templates (
            subject_name,
            subject_code
          )
        `)
        .order('started_at', { ascending: false });

      if (examsError) throw examsError;

      // Fetch all violations - don't require foreign key joins (allow NULLs)
      const { data: violationsData } = await supabase
        .from('violations')
        .select('*')
        .order('timestamp', { ascending: false });

      setViolations(violationsData || []);

      // Calculate stats
      const activeCount = (examsData || []).filter(e => e.status === 'in_progress').length;
      const completedCount = (examsData || []).filter(e => e.status === 'completed').length;
      const totalViolations = violationsData?.length || 0;
      const totalStudents = new Set((examsData || []).map(e => e.student_id)).size;
      
      const avgViolations = totalStudents > 0 ? (totalViolations / totalStudents).toFixed(1) : 0;
      
      const completedExams = (examsData || []).filter(e => e.status === 'completed' && e.started_at && e.completed_at);
      const avgDuration = completedExams.length > 0
        ? Math.round(completedExams.reduce((sum, e) => {
            const start = new Date(e.started_at).getTime();
            const end = new Date(e.completed_at).getTime();
            return sum + (end - start) / 1000 / 60;
          }, 0) / completedExams.length)
        : 0;

      setStats({
        totalSessions: examsData?.length || 0,
        activeNow: activeCount,
        completed: completedCount,
        totalViolations,
        avgViolationsPerStudent: Number(avgViolations),
        avgExamDuration: avgDuration,
        totalStudents,
      });

      setExamSessions(examsData || []);
      prepareChartData(violationsData || []);
      groupViolationsByStudent(examsData || [], violationsData || []);

    } catch (error) {
      console.error('Error loading dashboard data:', error);
    }
  };

  const prepareChartData = (violations: any[]) => {
    const hourlyData: { [key: string]: number } = {};
    
    violations.forEach(v => {
      const time = new Date(v.timestamp);
      const hourKey = time.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: true });
      hourlyData[hourKey] = (hourlyData[hourKey] || 0) + 1;
    });

    const data = Object.entries(hourlyData)
      .map(([time, violations]) => ({ time, violations }))
      .slice(-10);

    setChartData(data);
  };

  const groupViolationsByStudent = (exams: any[], violations: any[]) => {
    const studentMap: { [key: string]: any } = {};

    // Helper to normalize student name for matching
    const normalizeName = (name: string) => (name || '').toLowerCase().trim();
    
    // Helper to extract student info from violation
    const getStudentInfo = (violation: any) => {
      const studentId = violation.student_id || violation.details?.student_id || 'unknown';
      const studentName = violation.details?.student_name || violation.student_name || 'Unknown Student';
      const subjectCode = violation.details?.subject_code || '';
      return { studentId, studentName, subjectCode, normalizedName: normalizeName(studentName) };
    };

    // First pass: Group violations by student name (primary) and student_id (secondary)
    violations.forEach(violation => {
      const { studentId, studentName, subjectCode, normalizedName } = getStudentInfo(violation);
      
      // Skip if no valid student name
      if (normalizedName === '' || normalizedName === 'unknown student') {
        return;
      }
      
      // Create a key that combines normalized name and student_id for better matching
      const mapKey = `${normalizedName}_${studentId}`;
      
      if (!studentMap[mapKey]) {
        // Try to find exam data for this student by multiple criteria
        let exam = null;
        
        // 1. Try to find by student_id (UUID match)
        if (studentId && studentId !== 'unknown' && studentId.length > 10) {
          exam = exams.find(e => {
            const examStudentId = e.students?.id || e.student_id || '';
            return examStudentId === studentId || 
                   (e.students?.student_id && e.students.student_id === studentId);
          });
        }
        
        // 2. Try to find by student name
        if (!exam) {
          exam = exams.find(e => {
            const examStudentName = e.students?.name || '';
            return normalizeName(examStudentName) === normalizedName;
          });
        }
        
        // 3. Try to find by subject code from violation details
        if (!exam && subjectCode) {
          exam = exams.find(e => {
            const examSubjectCode = e.exam_templates?.subject_code || e.subject_code || '';
            const examStudentName = e.students?.name || '';
            return examSubjectCode === subjectCode && 
                   normalizeName(examStudentName) === normalizedName;
          });
        }
        
        // 4. Try to find by student_id text match (for non-UUID student_ids)
        if (!exam && studentId && studentId !== 'unknown') {
          exam = exams.find(e => {
            const examStudentId = e.students?.student_id || e.student_id || '';
            return examStudentId === studentId || 
                   examStudentId.toString() === studentId.toString();
          });
        }
        
        // 5. Last resort: find any exam with matching subject code
        if (!exam && subjectCode) {
          exam = exams.find(e => {
            const examSubjectCode = e.exam_templates?.subject_code || e.subject_code || '';
            return examSubjectCode === subjectCode;
          });
        }
        
        // Determine the best student ID to use
        let bestStudentId = studentId;
        let bestId = studentId;
        
        if (exam) {
          bestStudentId = exam.students?.student_id || exam.student_id || studentId;
          bestId = exam.students?.id || exam.id || studentId;
        } else {
          // Try to find student in students table by name
          // Note: We don't have direct access to students table here,
          // but we can use the student_id from violation if it's a valid UUID
          if (studentId && studentId.length > 20) {
            bestId = studentId; // Likely a UUID
          }
        }
        
        studentMap[mapKey] = {
          name: exam?.students?.name || studentName,
          studentId: bestStudentId,
          id: bestId, // Use student UUID or exam id
          examId: exam?.id, // Store exam id for View Report navigation
          violationCount: 0,
          violationTypes: [],
          violations: [],
          subjectName: exam?.exam_templates?.subject_name || exam?.subject_name || violation.details?.subject_name || 'N/A',
          subjectCode: exam?.exam_templates?.subject_code || exam?.subject_code || subjectCode || 'N/A',
        };
      }
      
      studentMap[mapKey].violationCount++;
      if (!studentMap[mapKey].violationTypes.includes(violation.violation_type)) {
        studentMap[mapKey].violationTypes.push(violation.violation_type);
      }
      studentMap[mapKey].violations.push(violation);
    });

    // Second pass: Merge students with same name but different IDs
    const mergedMap: { [key: string]: any } = {};
    Object.values(studentMap).forEach((student: any) => {
      const normalizedName = normalizeName(student.name);
      
      if (!mergedMap[normalizedName]) {
        mergedMap[normalizedName] = { ...student };
      } else {
        // Merge violations and types
        mergedMap[normalizedName].violations = [
          ...mergedMap[normalizedName].violations,
          ...student.violations
        ];
        mergedMap[normalizedName].violationCount += student.violationCount;
        student.violationTypes.forEach((type: string) => {
          if (!mergedMap[normalizedName].violationTypes.includes(type)) {
            mergedMap[normalizedName].violationTypes.push(type);
          }
        });
        
        // Prefer exam data if available (prioritize the one with examId)
        if (student.examId && !mergedMap[normalizedName].examId) {
          mergedMap[normalizedName].examId = student.examId;
          mergedMap[normalizedName].id = student.id;
          mergedMap[normalizedName].studentId = student.studentId;
          mergedMap[normalizedName].subjectName = student.subjectName;
          mergedMap[normalizedName].subjectCode = student.subjectCode;
        } else if (student.subjectCode && student.subjectCode !== 'N/A' && mergedMap[normalizedName].subjectCode === 'N/A') {
          // Update subject info if we have better data
          mergedMap[normalizedName].subjectName = student.subjectName;
          mergedMap[normalizedName].subjectCode = student.subjectCode;
        }
      }
    });

    // Sort violations by timestamp (most recent first)
    Object.values(mergedMap).forEach((student: any) => {
      student.violations.sort((a: any, b: any) => {
        const timeA = new Date(a.timestamp || 0).getTime();
        const timeB = new Date(b.timestamp || 0).getTime();
        return timeB - timeA;
      });
    });

    // Filter out entries with no violations (shouldn't happen, but safety check)
    const validStudents = Object.values(mergedMap).filter((student: any) => 
      student.violations && student.violations.length > 0
    );

    setStudentsWithViolations(validStudents);
  };

  const handleLogout = () => {
    sessionStorage.removeItem('adminAuth');
    toast.success("Logged out");
    navigate('/');
  };

  const handleExportCSV = async (student: any) => {
    try {
      const csvContent = await pdfGenerator.exportToCSV(student.violations);
      const blob = new Blob([csvContent], { type: 'text/csv' });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      
      // Use actual student name from violations if available
      const actualStudentName = student.violations?.[0]?.details?.student_name || 
                               student.violations?.[0]?.student_name || 
                               student.name || 
                               'Unknown_Student';
      const sanitizedName = actualStudentName.replace(/\s+/g, '_').replace(/[^a-zA-Z0-9_-]/g, '');
      
      a.download = `${sanitizedName}_violations.csv`;
      a.click();
      toast.success("CSV exported");
    } catch (error) {
      console.error('Error exporting CSV:', error);
      toast.error("Failed to export CSV");
    }
  };

  const handleGenerateReport = async (student: any) => {
    try {
      toast.info("Generating PDF report...");
      // Ensure we use the correct student name from violations if available
      const actualStudentName = student.violations?.[0]?.details?.student_name || 
                               student.violations?.[0]?.student_name || 
                               student.name || 
                               'Unknown Student';
      
      const pdfUrl = await pdfGenerator.generateStudentReport(
        actualStudentName,
        student.studentId,
        student.violations,
        student.subjectName,
        student.subjectCode
      );
      
      window.open(pdfUrl, '_blank');
      toast.success("Report generated and saved to Supabase");
    } catch (error) {
      console.error('Error generating report:', error);
      toast.error("Failed to generate report");
    }
  };

  const handleExportAllCSV = async () => {
    try {
      const csvContent = await pdfGenerator.exportToCSV(violations);
      const blob = new Blob([csvContent], { type: 'text/csv' });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `all_violations_${Date.now()}.csv`;
      a.click();
      toast.success("CSV exported");
    } catch (error) {
      toast.error("Failed to export");
    }
  };

  const formatDate = (dateString: string) => {
    if (!dateString) return 'N/A';
    const date = new Date(dateString);
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
  };

  const getViolationTypeIcon = (type: string) => {
    const icons: Record<string, string> = {
      'phone_detected': '📱',
      'book_detected': '📚',
      'multiple_faces': '👥',
      'multiple_person': '👥',
      'no_person': '❌',
      'object_detected': '📦',
      'looking_away': '👀',
      'eye_movement': '👁️',
      'excessive_noise': '🔊',
      'audio_violation': '🔊',
      'audio_noise': '🔊',
      'tab_switch': '🗂️',
      'copy_paste': '📋',
      'window_blur': '💤'
    };
    return icons[type] || '⚠️';
  };

  return (
    <div className="min-h-screen bg-background">
      <header className="border-b bg-card">
        <div className="container mx-auto px-4 py-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-xl bg-primary flex items-center justify-center">
              <Shield className="w-7 h-7 text-primary-foreground" />
            </div>
            <div>
              <h1 className="text-xl font-bold">Admin Dashboard</h1>
              <p className="text-sm text-muted-foreground">Real-time Exam Monitoring</p>
            </div>
          </div>
          <div className="flex gap-2">
            <Button variant="default" size="sm" onClick={() => navigate('/admin/analytics')}>
              <Activity className="w-4 h-4 mr-2" />
              Analytics
            </Button>
            <Button variant="outline" size="sm" onClick={() => navigate('/admin/monitor')}>
              <Monitor className="w-4 h-4 mr-2" />
              Live Monitor
            </Button>
            <Button variant="outline" size="sm" onClick={loadDashboardData}>
              <RefreshCw className="w-4 h-4 mr-2" />
              Refresh
            </Button>
            <Button variant="outline" size="sm" onClick={handleExportAllCSV}>
              <Download className="w-4 h-4 mr-2" />
              Export CSV
            </Button>
            <Button variant="outline" size="sm" onClick={() => navigate('/admin/upload-template')}>
              <Upload className="w-4 h-4 mr-2" />
              Upload Template
            </Button>
            <Button variant="outline" size="sm" onClick={handleLogout}>
              <LogOut className="w-4 h-4 mr-2" />
              Logout
            </Button>
          </div>
        </div>
      </header>

      <div className="container mx-auto px-4 py-8">
        {/* Stats Grid */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
          <Card>
            <CardContent className="p-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">Total Sessions</p>
                  <p className="text-3xl font-bold">{stats.totalSessions}</p>
                </div>
                <Activity className="w-8 h-8 text-primary" />
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="p-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">Active Now</p>
                  <p className="text-3xl font-bold text-green-600">{stats.activeNow}</p>
                </div>
                <Users className="w-8 h-8 text-green-600" />
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="p-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">Completed</p>
                  <p className="text-3xl font-bold">{stats.completed}</p>
                </div>
                <Shield className="w-8 h-8 text-primary" />
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="p-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-muted-foreground">Total Violations</p>
                  <p className="text-3xl font-bold text-red-600">{stats.totalViolations}</p>
                </div>
                <AlertTriangle className="w-8 h-8 text-red-600" />
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="p-6">
              <div>
                <p className="text-sm text-muted-foreground">Avg Violations/Student</p>
                <p className="text-3xl font-bold text-orange-600">{stats.avgViolationsPerStudent}</p>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="p-6">
              <div>
                <p className="text-sm text-muted-foreground">Avg Exam Duration</p>
                <p className="text-3xl font-bold">{stats.avgExamDuration} min</p>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardContent className="p-6">
              <div>
                <p className="text-sm text-muted-foreground">Total Students</p>
                <p className="text-3xl font-bold text-primary">{stats.totalStudents}</p>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Violations Over Time Chart */}
        <Card className="mb-8">
          <CardContent className="p-6">
            <h2 className="text-xl font-bold mb-6">Violations Over Time</h2>
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="time" />
                <YAxis />
                <Tooltip />
                <Line 
                  type="monotone" 
                  dataKey="violations" 
                  stroke="#ef4444" 
                  strokeWidth={2} 
                  dot={{ r: 4 }} 
                />
              </LineChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        {/* Recent Violation Evidence Gallery */}
        <Card className="mb-8">
          <CardContent className="p-6">
            <div className="flex items-center justify-between mb-6">
              <div className="flex items-center gap-2">
                <Eye className="w-5 h-5" />
                <h2 className="text-xl font-bold">Recent Violation Evidence Gallery</h2>
                <Badge variant="secondary">{violations.filter(v => v.image_url).length} Images</Badge>
              </div>
            </div>
            
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              {violations
                .filter(v => v.image_url)
                .slice(0, 8)
                .map((violation) => (
                  <div key={violation.id} className="relative group">
                    <div className="aspect-video rounded-lg overflow-hidden border-2 border-border hover:border-red-500 transition-colors">
                      <img 
                        src={violation.image_url} 
                        alt={violation.violation_type}
                        className="w-full h-full object-cover"
                        onError={(e) => {
                          e.currentTarget.src = '/placeholder.svg';
                        }}
                      />
                    </div>
                    <div className="absolute top-2 left-2">
                      <Badge variant="destructive" className="text-xs">
                        {getViolationTypeIcon(violation.violation_type)} {violation.violation_type.replace(/_/g, ' ')}
                      </Badge>
                    </div>
                    <div className="mt-2">
                      <p className="text-xs font-medium">
                        {violation.details?.student_name || 
                         violation.student_name || 
                         (violation.exam_id ? examSessions.find(e => e.id === violation.exam_id)?.students?.name : null) ||
                         'Unknown Student'}
                      </p>
                      <p className="text-xs text-muted-foreground">
                        {formatDate(violation.timestamp)}
                      </p>
                    </div>
                  </div>
                ))}
            </div>

            {violations.filter(v => v.image_url).length === 0 && (
              <div className="text-center py-12 text-muted-foreground">
                No violation evidence images found
              </div>
            )}
          </CardContent>
        </Card>

        <div className="grid lg:grid-cols-3 gap-6">
          {/* Students with Violations */}
          <div className="lg:col-span-2">
            <Card>
              <CardContent className="p-6">
                <div className="flex items-center gap-2 mb-6">
                  <Users className="w-5 h-5" />
                  <h2 className="text-xl font-bold">Students with Violations</h2>
                  <Badge variant="destructive">{studentsWithViolations.length} Students</Badge>
                </div>

                <div className="space-y-4">
                  {studentsWithViolations.map((student) => (
                    <div key={student.id} className="border rounded-lg p-4">
                      <div className="flex items-start justify-between mb-3">
                        <div>
                          <h3 className="font-bold">{student.name}</h3>
                          <p className="text-sm text-muted-foreground">{student.studentId}</p>
                          <p className="text-xs text-muted-foreground mt-1">
                            <span className="font-medium">Subject:</span> {student.subjectName} ({student.subjectCode})
                          </p>
                        </div>
                        <div className="flex items-center gap-2">
                          <AlertTriangle className="w-5 h-5 text-red-600" />
                          <span className="font-bold text-red-600">{student.violationCount} Violations</span>
                        </div>
                      </div>
                      
                      <div className="flex flex-wrap gap-2 mb-3">
                        {student.violationTypes.map((type: string) => (
                          <Badge key={type} variant="secondary" className="text-xs">
                            {getViolationTypeIcon(type)} {type.replace(/_/g, ' ')}
                          </Badge>
                        ))}
                      </div>

                      <div className="flex gap-2">
                        <Button 
                          size="sm" 
                          variant="default" 
                          onClick={() => {
                            // Helper function for name normalization
                            const normalizeName = (name: string) => (name || '').toLowerCase().trim();
                            
                            // Find exam by examId stored in student object, or by matching student_id/name
                            let examId = student.examId;
                            
                            if (!examId) {
                              // Try to find exam by student_id
                              examId = examSessions.find(e => 
                                e.student_id === student.studentId || 
                                e.students?.student_id === student.studentId ||
                                e.students?.id === student.id
                              )?.id;
                            }
                            
                            if (!examId) {
                              // Try to find by student name
                              examId = examSessions.find(e => 
                                normalizeName(e.students?.name || '') === normalizeName(student.name)
                              )?.id;
                            }
                            
                            if (!examId && student.subjectCode && student.subjectCode !== 'N/A') {
                              // Try to find by subject code and student name
                              examId = examSessions.find(e => {
                                const examSubjectCode = e.exam_templates?.subject_code || e.subject_code || '';
                                const examStudentName = e.students?.name || '';
                                return examSubjectCode === student.subjectCode && 
                                       normalizeName(examStudentName) === normalizeName(student.name);
                              })?.id;
                            }
                            
                            // Use student.id (UUID) if available, otherwise student.studentId
                            const studentIdForReport = student.id && student.id.length > 20 
                              ? student.id 
                              : (student.studentId !== 'unknown' ? student.studentId : student.id);
                            
                            navigate(`/admin/student-report?studentId=${studentIdForReport}&examId=${examId || ''}`);
                          }}
                        >
                          <Eye className="w-4 h-4 mr-1" />
                          View Report
                        </Button>
                        <Button 
                          size="sm" 
                          variant="outline" 
                          onClick={() => handleGenerateReport(student)}
                        >
                          <FileText className="w-4 h-4 mr-1" />
                          Generate PDF
                        </Button>
                        <Button 
                          size="sm" 
                          variant="outline" 
                          onClick={() => handleExportCSV(student)}
                        >
                          <Download className="w-4 h-4 mr-1" />
                          Export CSV
                        </Button>
                      </div>
                    </div>
                  ))}
                  {studentsWithViolations.length === 0 && (
                    <div className="text-center py-12 text-muted-foreground">
                      No violations detected yet
                    </div>
                  )}
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Recent Activity */}
          <div>
            <Card>
              <CardContent className="p-6">
                <h2 className="text-xl font-bold mb-6">Recent Activity</h2>
                <div className="space-y-3">
                  {violations.slice(0, 10).map((violation) => {
                    // Try multiple sources for student name
                    const studentName = violation.details?.student_name || 
                                      violation.student_name || 
                                      (violation.exam_id ? examSessions.find(e => e.id === violation.exam_id)?.students?.name : null) ||
                                      'Unknown Student';
                    
                    return (
                      <div key={violation.id} className="text-sm border-l-2 border-red-500 pl-3 py-1">
                        <p className="font-medium">{studentName}</p>
                        <p className="text-muted-foreground">
                          {getViolationTypeIcon(violation.violation_type)} {violation.violation_type.replace(/_/g, ' ')}
                        </p>
                        <p className="text-xs text-muted-foreground">{formatDate(violation.timestamp)}</p>
                      </div>
                    );
                  })}
                  {violations.length === 0 && (
                    <p className="text-center text-muted-foreground py-8">No recent activity</p>
                  )}
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </div>
  );
};

export default AdminDashboard;
