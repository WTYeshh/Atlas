import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../providers/attendance_provider.dart';
import '../providers/calendar_provider.dart';
import '../models/subject_model.dart';
import '../models/timetable_slot_model.dart';
import '../services/attendance_ocr_service.dart';

class AttendanceDashboardScreen extends ConsumerStatefulWidget {
  const AttendanceDashboardScreen({super.key});

  @override
  ConsumerState<AttendanceDashboardScreen> createState() => _AttendanceDashboardScreenState();
}

class _AttendanceDashboardScreenState extends ConsumerState<AttendanceDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  String _processingMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickAndParseImage(bool isTimetable) async {
    final XFile? image = await showModalBottomSheet<XFile?>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: Theme.of(context).primaryColor),
              title: const Text('Pick from Gallery'),
              onTap: () async {
                final file = await _picker.pickImage(source: ImageSource.gallery);
                if (context.mounted) Navigator.pop(context, file);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: Theme.of(context).primaryColor),
              title: const Text('Take a Photo'),
              onTap: () async {
                final file = await _picker.pickImage(source: ImageSource.camera);
                if (context.mounted) Navigator.pop(context, file);
              },
            ),
          ],
        ),
      ),
    );

    if (image == null) return;

    setState(() {
      _isProcessing = true;
      _processingMessage = isTimetable
          ? 'Scanning timetable image using ML Kit OCR...'
          : 'Scanning academic calendar image...';
    });

    try {
      final calendarRepo = ref.read(calendarRepositoryProvider);
      final ocrService = AttendanceOcrService(calendarRepo);

      setState(() {
        _processingMessage = 'Analyzing text & structuring schedules with Gemini AI...';
      });

      final result = await ocrService.parseAndImportImage(image.path);
      
      // Reload both calendar and attendance providers
      await ref.read(attendanceProvider.notifier).loadAll();
      await ref.read(calendarProvider.notifier).loadEvents();

      if (mounted) {
        final type = result['type'] ?? 'unknown';
        final count = result['count'] ?? 0;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              type == 'timetable'
                  ? 'Success! Imported $count weekly timetable slots & subjects.'
                  : 'Success! Imported $count calendar events & dates.',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Parsing Failed'),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        );
      }
    } finally {
      try {
        final file = File(image.path);
        if (await file.exists()) {
          await file.delete();
          print('Cleaned up image picker cache at: ${image.path}');
        }
      } catch (e) {
        print('Error cleaning up image picker cache: $e');
      }
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingMessage = '';
        });
      }
    }
  }

  void _showAddSubjectDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    double minPercent = 75.0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Add New Subject', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Subject Name (e.g., Computer Networks)',
                    hintText: 'Enter full subject name',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Subject Code (e.g., CS-301, optional)',
                    hintText: 'Enter code or abbreviation',
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Min Attendance: ${minPercent.toInt()}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Slider(
                        value: minPercent,
                        min: 50.0,
                        max: 100.0,
                        divisions: 10,
                        label: '${minPercent.toInt()}%',
                        onChanged: (val) {
                          setStateDialog(() {
                            minPercent = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final code = codeController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Subject name cannot be empty.')),
                  );
                  return;
                }
                Navigator.pop(context);
                await ref.read(attendanceProvider.notifier).addSubject(
                      name,
                      code.isEmpty ? null : code,
                      minPercent,
                    );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: Text('Add', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSlotDialog(List<SubjectModel> subjects) {
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one subject first.')),
      );
      return;
    }

    String selectedSubjectId = subjects.first.id;
    int selectedDay = 1; // Monday
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);
    final roomController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Add Timetable Slot', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedSubjectId,
                  decoration: const InputDecoration(labelText: 'Subject'),
                  items: subjects
                      .map((sub) => DropdownMenuItem(
                            value: sub.id,
                            child: Text(sub.code != null ? '[${sub.code}] ${sub.name}' : sub.name),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setStateDialog(() {
                        selectedSubjectId = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedDay,
                  decoration: const InputDecoration(labelText: 'Day of Week'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Monday')),
                    DropdownMenuItem(value: 2, child: Text('Tuesday')),
                    DropdownMenuItem(value: 3, child: Text('Wednesday')),
                    DropdownMenuItem(value: 4, child: Text('Thursday')),
                    DropdownMenuItem(value: 5, child: Text('Friday')),
                    DropdownMenuItem(value: 6, child: Text('Saturday')),
                    DropdownMenuItem(value: 7, child: Text('Sunday')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setStateDialog(() {
                        selectedDay = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Start Time:', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () async {
                        final time = await showTimePicker(context: context, initialTime: startTime);
                        if (time != null) {
                          setStateDialog(() {
                            startTime = time;
                          });
                        }
                      },
                      child: Text(startTime.format(context)),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('End Time:', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () async {
                        final time = await showTimePicker(context: context, initialTime: endTime);
                        if (time != null) {
                          setStateDialog(() {
                            endTime = time;
                          });
                        }
                      },
                      child: Text(endTime.format(context)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roomController,
                  decoration: const InputDecoration(
                    labelText: 'Classroom / Lecture Hall (optional)',
                    hintText: 'e.g. Room 402, Seminar Hall',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final startStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
                final endStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
                final room = roomController.text.trim();

                Navigator.pop(context);
                await ref.read(attendanceProvider.notifier).addTimetableSlot(
                      selectedSubjectId,
                      selectedDay,
                      startStr,
                      endStr,
                      room.isEmpty ? null : room,
                    );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: Text('Add Slot', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualLogSheet(SubjectModel subject) {
    DateTime selectedDate = DateTime.now();
    String status = 'present'; // default

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSheet) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Log Attendance: ${subject.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(DateFormat('dd-MM-yyyy').format(selectedDate)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 90)),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setStateSheet(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ChoiceChip(
                    label: const Text('Present'),
                    selectedColor: Colors.green.withOpacity(0.2),
                    selected: status == 'present',
                    onSelected: (val) {
                      if (val) setStateSheet(() => status = 'present');
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Absent'),
                    selectedColor: Colors.red.withOpacity(0.2),
                    selected: status == 'absent',
                    onSelected: (val) {
                      if (val) setStateSheet(() => status = 'absent');
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Cancelled'),
                    selectedColor: Colors.grey.withOpacity(0.2),
                    selected: status == 'cancelled',
                    onSelected: (val) {
                      if (val) setStateSheet(() => status = 'cancelled');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
                  await ref.read(attendanceProvider.notifier).markAttendance(
                        subjectId: subject.id,
                        date: dateStr,
                        status: status,
                      );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Save Log', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendanceState = ref.watch(attendanceProvider);
    final notifier = ref.read(attendanceProvider.notifier);
    
    final overallStats = notifier.getOverallStats();
    final double overallPercentage = overallStats['percentage'] ?? 0.0;
    final int overallHeld = overallStats['held'] ?? 0;
    final int overallAttended = overallStats['attended'] ?? 0;

    final pendingLogs = notifier.getPendingConfirmations();
    final subjectStats = notifier.getSubjectStats();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ATTENDANCE TRACKER', style: TextStyle(fontWeight: FontWeight.w900)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Weekly Schedule'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (val) async {
              if (val == 'timetable') {
                _pickAndParseImage(true);
              } else if (val == 'calendar') {
                _pickAndParseImage(false);
              } else if (val == 'add_subject') {
                _showAddSubjectDialog();
              } else if (val == 'clear_timetable') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Timetable?'),
                    content: const Text('This will delete all weekly class slots. Subject logs and subjects will be kept.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await notifier.clearTimetable();
                }
              }
            },
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'timetable',
                child: Row(
                  children: [
                    Icon(Icons.table_chart_outlined, size: 20, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    const Text('Import Timetable Image'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'calendar',
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 20, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    const Text('Import Calendar Image'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'add_subject',
                child: Row(
                  children: [
                    Icon(Icons.add, size: 20),
                    const SizedBox(width: 8),
                    const Text('Add Subject Manually'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_timetable',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined, size: 20, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    const Text('Clear Timetable Slots'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              // 1. Overview Tab
              attendanceState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => notifier.loadAll(),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Overall Progress Banner
                            _buildOverallStatsCard(overallPercentage, overallAttended, overallHeld),
                            const SizedBox(height: 20),

                            // Pending Attendance Log confirmation
                            if (pendingLogs.isNotEmpty) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Pending Confirmations (${pendingLogs.length})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const Icon(Icons.pending_actions, size: 20, color: Colors.orangeAccent),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 135,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: pendingLogs.length,
                                  itemBuilder: (context, index) {
                                    final item = pendingLogs[index];
                                    return _buildPendingCard(item);
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Subjects List Section
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Subjects & Attendance',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                  onPressed: _showAddSubjectDialog,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (attendanceState.subjects.isEmpty)
                              _buildEmptyStateCard('No subjects added yet. Tap the menu at the top right to import a timetable or add subjects.')
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: attendanceState.subjects.length,
                                itemBuilder: (context, index) {
                                  final subject = attendanceState.subjects[index];
                                  final stats = subjectStats[subject.id] ?? {'held': 0, 'attended': 0, 'percentage': 0.0};
                                  return _buildSubjectCard(subject, stats);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),

              // 2. Weekly Schedule Tab
              attendanceState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildWeeklyScheduleTab(attendanceState.subjects, attendanceState.slots),
            ],
          ),
          
          // Image uploading indicator overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        Text(
                          _processingMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverallStatsCard(double percentage, int attended, int held) {
    final isGood = percentage >= 75.0 || held == 0;
    final primaryColor = Theme.of(context).primaryColor;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isGood 
              ? [primaryColor.withOpacity(0.85), primaryColor.withOpacity(0.6)]
              : [Colors.redAccent.withOpacity(0.85), Colors.orangeAccent.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isGood ? primaryColor : Colors.redAccent).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Overall Standing',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isGood ? 'Good Standing' : 'Low Attendance Alert',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You have attended $attended out of $held held classes across all courses.',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 75,
                  width: 75,
                  child: CircularProgressIndicator(
                    value: held == 0 ? 0.0 : (percentage / 100.0),
                    strokeWidth: 8,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> item) {
    final SubjectModel subject = item['subject'];
    final TimetableSlotModel slot = item['slot'];
    final String date = item['date'];
    final String formattedDate = item['formattedDate'];

    return Card(
      margin: const EdgeInsets.only(right: 12, bottom: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subject.code ?? 'CLASS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Theme.of(context).primaryColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subject.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '$formattedDate (${slot.startTime})',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionChip(
                  color: Colors.green,
                  icon: Icons.check,
                  tooltip: 'Present',
                  onTap: () => ref.read(attendanceProvider.notifier).markAttendance(
                        subjectId: subject.id,
                        date: date,
                        status: 'present',
                      ),
                ),
                _buildActionChip(
                  color: Colors.red,
                  icon: Icons.close,
                  tooltip: 'Absent',
                  onTap: () => ref.read(attendanceProvider.notifier).markAttendance(
                        subjectId: subject.id,
                        date: date,
                        status: 'absent',
                      ),
                ),
                _buildActionChip(
                  color: Colors.grey,
                  icon: Icons.remove,
                  tooltip: 'Cancelled',
                  onTap: () => ref.read(attendanceProvider.notifier).markAttendance(
                        subjectId: subject.id,
                        date: date,
                        status: 'cancelled',
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip({required Color color, required IconData icon, required String tooltip, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Widget _buildSubjectCard(SubjectModel subject, Map<String, dynamic> stats) {
    final int held = stats['held'] ?? 0;
    final int attended = stats['attended'] ?? 0;
    final double percentage = stats['percentage'] ?? 0.0;
    final bool isLow = percentage < subject.minPercentage && held > 0;
    final Color barColor = isLow ? Colors.redAccent : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (subject.code != null)
                        Text(
                          subject.code!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      Text(
                        subject.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Held: $held | Attended: $attended',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: barColor,
                      ),
                    ),
                    Text(
                      'Min Required: ${subject.minPercentage.toInt()}%',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: held == 0 ? 0.0 : (attended / held),
                color: barColor,
                backgroundColor: Theme.of(context).dividerColor.withOpacity(0.1),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isLow)
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Attendance below ${subject.minPercentage.toInt()}%!',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                else
                  const SizedBox(),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _showManualLogSheet(subject),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Log Class', style: TextStyle(fontSize: 11)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Subject?'),
                            content: Text('Are you sure you want to delete "${subject.name}"? This will delete all of its scheduled slots and attendance logs.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref.read(attendanceProvider.notifier).deleteSubject(subject.id);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard(String text) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        color: Theme.of(context).dividerColor.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Column(
          children: [
            Icon(Icons.calendar_view_week, size: 48, color: Theme.of(context).primaryColor.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildWeeklyScheduleTab(List<SubjectModel> subjects, List<TimetableSlotModel> slots) {
    final Map<int, List<TimetableSlotModel>> slotsByDay = {};
    for (var slot in slots) {
      slotsByDay.putIfAbsent(slot.dayOfWeek, () => []).add(slot);
    }

    // Sort slots within each day by start time
    slotsByDay.forEach((day, daySlots) {
      daySlots.sort((a, b) => a.startTime.compareTo(b.startTime));
    });

    final daysOfWeek = [
      {'val': 1, 'name': 'Monday'},
      {'val': 2, 'name': 'Tuesday'},
      {'val': 3, 'name': 'Wednesday'},
      {'val': 4, 'name': 'Thursday'},
      {'val': 5, 'name': 'Friday'},
      {'val': 6, 'name': 'Saturday'},
      {'val': 7, 'name': 'Sunday'},
    ];

    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: daysOfWeek.length,
        itemBuilder: (context, index) {
          final dayData = daysOfWeek[index];
          final int dayVal = dayData['val'] as int;
          final String dayName = dayData['name'] as String;
          final daySlots = slotsByDay[dayVal] ?? [];

          return ExpansionTile(
            title: Text(
              dayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${daySlots.length} Classes scheduled',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            leading: Icon(
              Icons.today,
              color: daySlots.isNotEmpty ? Theme.of(context).primaryColor : Colors.grey,
            ),
            children: daySlots.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                      child: Text('No classes scheduled for this day.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    )
                  ]
                : daySlots.map((slot) {
                    final subject = subjects.firstWhere((sub) => sub.id == slot.subjectId, orElse: () => SubjectModel(id: '', name: 'Deleted Subject'));
                    return ListTile(
                      dense: true,
                      title: Text(
                        subject.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${slot.startTime} - ${slot.endTime}${slot.classroom != null ? " • ${slot.classroom}" : ""}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Timetable Slot?'),
                              content: const Text('Are you sure you want to delete this weekly class slot?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ref.read(attendanceProvider.notifier).deleteTimetableSlot(slot.id);
                          }
                        },
                      ),
                    );
                  }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSlotDialog(subjects),
        icon: const Icon(Icons.add),
        label: const Text('Add Slot'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }
}
