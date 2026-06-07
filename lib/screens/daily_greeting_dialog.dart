import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_provider.dart';
import '../providers/tasks_provider.dart';
import '../models/event_model.dart';
import '../models/task_model.dart';
import '../core/secure_storage.dart';

enum GreetingMode { morning, night }

class DailyGreetingDialog extends ConsumerStatefulWidget {
  final bool autoTriggered;
  final GreetingMode? forceMode;
  final bool mockAllCompleted;

  const DailyGreetingDialog({
    super.key,
    this.autoTriggered = false,
    this.forceMode,
    this.mockAllCompleted = false,
  });

  static Future<void> show(
    BuildContext context, {
    bool autoTriggered = false,
    GreetingMode? forceMode,
    bool mockAllCompleted = false,
  }) async {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DailyGreetingDialog',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, anim1, anim2) {
        return DailyGreetingDialog(
          autoTriggered: autoTriggered,
          forceMode: forceMode,
          mockAllCompleted: mockAllCompleted,
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curve,
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  ConsumerState<DailyGreetingDialog> createState() => _DailyGreetingDialogState();
}

class _DailyGreetingDialogState extends ConsumerState<DailyGreetingDialog> {
  String _greetingText = "";
  String _dailyQuote = "";
  bool _celebrated = false;
  bool _showCelebration = false;

  final List<String> _personalizedQuotes = [
    "Hey YESH, let's seize the day! ✨",
    "Ready to conquer your goals, YESH? 🚀",
    "Rise and shine, YESH! You've got this. 💪",
    "Make today count, YESH! 🌟",
    "Another day, another opportunity, YESH! ☀️",
    "Hey YESH, one step at a time! 🏃‍♂️",
    "Yo YESH! Focus on the progress, not perfection. 📈",
    "Keep pushing forward, YESH! 🏆",
    "Hey YESH, start where you are, use what you have. 🎯",
    "Believing in you, YESH! Let's do this. 🙌",
    "Hey YESH, make today amazingly productive! ⚡",
    "Let's check off those tasks, YESH! 📋",
  ];

  final List<String> _hecticGreetings = [
    "It's a hectic day but fear not.. we will make sure it's done today! 💪",
    "Oof, today is loaded! Stay focused, take breaks, and we will crush it today. 🚀",
    "A busy schedule today! Take a deep breath, one step at a time, you've got this! ✨",
  ];

  final List<String> _moderateGreetings = [
    "A few tasks and events today. A steady pace will get us through it easily! 😊",
    "Just a few items on the list. You'll breeze through them in no time! 🌟",
    "A normal day ahead. Let's stay productive and keep the momentum going! 👍",
  ];

  final List<String> _relaxedGreetings = [
    "Ofe.. finally a day without much work.. hope you take rest in this free day.. not much of a work to do! ☕",
    "No events or pending tasks today! Time to recharge, relax, and enjoy the free day. 🏖️",
    "Ah, a peaceful day! Enjoy the break and take some well-deserved rest. 🍃",
  ];

  final List<String> _nightQuotesAllCompleted = [
    "YESH, you crushed all your goals today! 🏆",
    "Absolute legend, YESH! 100% completed! 🌟",
    "Perfect score today, YESH! Proud of you. 💪",
    "You did it, YESH! Time for a well-deserved rest. 😴",
  ];

  final List<String> _nightQuotesPending = [
    "Great effort today, YESH! Tomorrow is a new start. 🌟",
    "Rest up, YESH. Tomorrow we conquer the rest! 🔋",
    "You made solid progress today, YESH! 👍",
    "Sleep well, YESH. The remaining tasks can wait. 🛏️",
  ];

  final List<String> _nightGreetingsAllCompleted = [
    "Incredible job, YESH! Every single task checked off. Enjoy the cracker burst! 🎉",
    "A perfect checklist today, YESH! Sleep tight, you've earned this peace. 🌌",
    "You completely cleared your plate, YESH! Rest up and recharge. ⚡",
  ];

  final List<String> _nightGreetingsPending = [
    "A few items are still pending. Use the reschedule option to push them to tomorrow! ➡️",
    "Almost done, YESH! Reschedule the left-over tasks and get some rest. 🌙",
    "Let's move the pending tasks to tomorrow so you can sleep stress-free. 🛏️",
  ];

  GreetingMode get _currentMode {
    if (widget.forceMode != null) return widget.forceMode!;
    final hour = DateTime.now().hour;
    // Morning is before 5 PM (17:00), Night is 5 PM onwards.
    return hour < 17 ? GreetingMode.morning : GreetingMode.night;
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoTriggered) {
      _saveGreetingShownToday();
    }
  }

  Future<void> _saveGreetingShownToday() async {
    final todayStr = DateFormat('dd-MM-yy').format(DateTime.now());
    if (_currentMode == GreetingMode.morning) {
      await SecureStorage().saveLastMorningGreetingDate(todayStr);
    } else {
      await SecureStorage().saveLastNightGreetingDate(todayStr);
    }
  }

  void _updateModeTexts(
    GreetingMode mode,
    List<EventModel> todayEvents,
    List<TaskModel> todayTasks,
    double taskProgress,
  ) {
    final now = DateTime.now();
    final daySeed = now.year * 1000 + now.month * 100 + now.day;
    final random = Random(daySeed);

    if (mode == GreetingMode.morning) {
      if (_dailyQuote.isEmpty || !_personalizedQuotes.contains(_dailyQuote)) {
        _dailyQuote = _personalizedQuotes[random.nextInt(_personalizedQuotes.length)];
      }
    } else {
      if (taskProgress >= 0.999) {
        if (_dailyQuote.isEmpty || !_nightQuotesAllCompleted.contains(_dailyQuote)) {
          _dailyQuote = _nightQuotesAllCompleted[random.nextInt(_nightQuotesAllCompleted.length)];
        }
      } else {
        if (_dailyQuote.isEmpty || !_nightQuotesPending.contains(_dailyQuote)) {
          _dailyQuote = _nightQuotesPending[random.nextInt(_nightQuotesPending.length)];
        }
      }
    }

    if (mode == GreetingMode.morning) {
      if (_greetingText.isEmpty) {
        final totalCount = todayEvents.length + todayTasks.length;
        bool isHectic = false;
        final checkKeywords = ["lab", "test", "exam", "assignment", "quiz", "viva", "project", "deadline", "presentation", "submission"];
        for (final event in todayEvents) {
          final titleLower = event.title.toLowerCase();
          final descLower = (event.description ?? "").toLowerCase();
          if (checkKeywords.any((kw) => titleLower.contains(kw) || descLower.contains(kw))) {
            isHectic = true;
            break;
          }
        }
        for (final task in todayTasks) {
          final titleLower = task.title.toLowerCase();
          if (checkKeywords.any((kw) => titleLower.contains(kw))) {
            isHectic = true;
            break;
          }
        }
        if (totalCount >= 3) isHectic = true;

        final r = Random();
        if (isHectic) {
          _greetingText = _hecticGreetings[r.nextInt(_hecticGreetings.length)];
        } else if (totalCount == 0) {
          _greetingText = _relaxedGreetings[r.nextInt(_relaxedGreetings.length)];
        } else {
          _greetingText = _moderateGreetings[r.nextInt(_moderateGreetings.length)];
        }
      }
    } else {
      final r = Random();
      if (taskProgress >= 0.999) {
        _greetingText = _nightGreetingsAllCompleted[r.nextInt(_nightGreetingsAllCompleted.length)];
      } else {
        _greetingText = _nightGreetingsPending[r.nextInt(_nightGreetingsPending.length)];
      }
    }
  }

  Future<void> _rescheduleTask(TaskModel task) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowStr = DateFormat('yyyy-MM-dd').format(tomorrow); // internal DB format
    final tomorrowUserStr = DateFormat('dd-MM-yy').format(tomorrow); // user-facing format
    
    final updatedTask = task.copyWith(
      dueDate: tomorrowStr,
      updatedAt: DateTime.now().toIso8601String(),
    );

    await ref.read(tasksProvider.notifier).updateTask(updatedTask);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rescheduled task to $tomorrowUserStr'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = _currentMode;
    final events = ref.watch(calendarProvider);
    final tasks = ref.watch(tasksProvider);

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    final todayEvents = events.where((e) => e.date == todayStr).toList();
    final todayTasks = tasks.where((t) => t.dueDate == todayStr).toList();
    
    todayTasks.sort((a, b) {
      if (a.status == b.status) return 0;
      return a.status == 'pending' ? -1 : 1;
    });

    final totalTasksCount = widget.mockAllCompleted ? 1 : todayTasks.length;
    final completedTasksCount = widget.mockAllCompleted
        ? 1
        : todayTasks.where((t) => t.status == 'completed').length;
    
    final double taskProgress = totalTasksCount > 0 ? (completedTasksCount / totalTasksCount) : 1.0;

    _updateModeTexts(mode, todayEvents, todayTasks, taskProgress);

    // Trigger celebration if 100% completed in Night Mode
    if ((mode == GreetingMode.night || widget.mockAllCompleted) &&
        taskProgress >= 0.999 &&
        totalTasksCount > 0 &&
        !_celebrated) {
      _celebrated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _showCelebration = true;
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              child: Container(
                width: 325,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    )
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Close Button Row
                      Align(
                        alignment: Alignment.topRight,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 1.5),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),

                      // Personalized Unique Quote Header
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            _dailyQuote,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.instrumentSerif(
                              fontSize: 26,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Agenda Tasks/Events
                      if (todayEvents.isEmpty && todayTasks.isEmpty && !widget.mockAllCompleted)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black, width: 1.2),
                          ),
                          child: Center(
                            child: Text(
                              'Nothing scheduled today!',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        )
                      else ...[
                        if (!widget.mockAllCompleted) ...[
                          // List today's classes/events (only in morning mode, or general list)
                          ...todayEvents.map((event) => _buildAgendaItem(
                            context,
                            title: event.title,
                            subtitle: '${event.time}${event.category != null ? " • ${event.category}" : ""}',
                            isTask: false,
                            checked: false,
                          )),
                          // List today's tasks
                          ...todayTasks.map((task) {
                            final isCompleted = task.status == 'completed';
                            final showReschedule = mode == GreetingMode.night && !isCompleted;

                            return _buildAgendaItem(
                              context,
                              title: task.title,
                              subtitle: task.subject != null ? 'Assignment • ${task.subject}' : 'Task',
                              isTask: true,
                              checked: isCompleted,
                              onChanged: (val) {
                                ref.read(tasksProvider.notifier).toggleTaskStatus(task.id);
                              },
                              onReschedule: showReschedule ? () => _rescheduleTask(task) : null,
                            );
                          }),
                        ] else ...[
                          // Mock completed task for preview
                          _buildAgendaItem(
                            context,
                            title: 'Complete all assignments',
                            subtitle: 'Assignment • Academics',
                            isTask: true,
                            checked: true,
                          ),
                        ]
                      ],

                      const SizedBox(height: 16),

                      // Greeting Message (Full Width)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text(
                          _greetingText,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Sleek Hand-drawn Style Linear Progress Bar
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Today's Progress",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                ),
                              ),
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.0, end: taskProgress),
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                                builder: (context, value, child) {
                                  return Text(
                                    '${(value * 100).toInt()}%',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: taskProgress),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                            builder: (context, value, child) {
                              return Container(
                                width: double.infinity,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: Colors.black, width: 1.5),
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: value.clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(3.5),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // OK Button
                      Center(
                        child: SizedBox(
                          width: 110,
                          height: 38,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: const BorderSide(color: Colors.black, width: 1.5),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              'OK',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_showCelebration)
            const Positioned.fill(
              child: CrackerBlastWidget(),
            ),
        ],
      ),
    );
  }

  Widget _buildAgendaItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isTask,
    required bool checked,
    ValueChanged<bool?>? onChanged,
    VoidCallback? onReschedule,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 1.2),
      ),
      child: Row(
        children: [
          if (isTask)
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: checked,
                activeColor: Colors.black,
                checkColor: Colors.white,
                side: const BorderSide(color: Colors.black, width: 1.5),
                onChanged: onChanged,
              ),
            )
          else
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 7),
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black,
                    decoration: checked ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (onReschedule != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onReschedule,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 1.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_forward_rounded, size: 11, color: Colors.black),
                    const SizedBox(width: 4),
                    Text(
                      'Tomorrow',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CrackerBlastWidget extends StatefulWidget {
  const CrackerBlastWidget({super.key});

  @override
  State<CrackerBlastWidget> createState() => _CrackerBlastWidgetState();
}

class _CrackerBlastWidgetState extends State<CrackerBlastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addListener(_updatePhysics);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _spawnExplosions();
        _controller.forward();
      }
    });
  }

  void _spawnExplosions() {
    final size = MediaQuery.of(context).size;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Trigger multiple bursts over time for cracker appreciation
    _spawnBurst(centerX - 60, centerY - 80);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _spawnBurst(centerX + 60, centerY - 140);
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _spawnBurst(centerX, centerY - 40);
    });
  }

  void _spawnBurst(double x, double y) {
    for (int i = 0; i < 45; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = _random.nextDouble() * 220 + 80;
      final vx = cos(angle) * speed;
      final vy = sin(angle) * speed - 60; // slight upward bias
      final size = _random.nextDouble() * 9 + 4;
      final colors = [
        Colors.black,
        Colors.grey.shade700,
        Colors.grey.shade400,
        Colors.white,
      ];
      final color = colors[_random.nextInt(colors.length)];
      final shape = ParticleShape.values[_random.nextInt(ParticleShape.values.length)];

      _particles.add(
        Particle(
          x: x,
          y: y,
          vx: vx,
          vy: vy,
          size: size,
          color: color,
          shape: shape,
          opacity: 1.0,
          rotation: _random.nextDouble() * 2 * pi,
          rotationSpeed: _random.nextDouble() * 8 - 4,
          decay: _random.nextDouble() * 0.4 + 0.35, // lives 2 - 2.8 seconds
        ),
      );
    }
    if (mounted) setState(() {});
  }

  void _updatePhysics() {
    if (!mounted) return;
    const dt = 0.016; // 60fps tick interval approximation
    setState(() {
      for (final p in _particles) {
        p.update(dt);
      }
      _particles.removeWhere((p) => p.life >= 1.0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: ParticlePainter(_particles),
        child: const SizedBox.expand(),
      ),
    );
  }
}

enum ParticleShape { circle, square, triangle, star }

class Particle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  ParticleShape shape;
  double opacity;
  double rotation;
  double rotationSpeed;
  double life = 0.0;
  double decay;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.shape,
    required this.opacity,
    required this.rotation,
    required this.rotationSpeed,
    required this.decay,
  });

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 320 * dt; // Gravity pulling particles down
    vx *= 0.95; // Air resistance
    vy *= 0.95;
    rotation += rotationSpeed * dt;
    life += decay * dt;
    if (life > 1.0) life = 1.0;
    opacity = (1.0 - life).clamp(0.0, 1.0);
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black
      ..strokeWidth = 1.0;

    for (final p in particles) {
      if (p.opacity <= 0.0) continue;

      paint.color = p.color.withOpacity(p.opacity);
      strokePaint.color = Colors.black.withOpacity(p.opacity);

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      final half = p.size / 2;

      switch (p.shape) {
        case ParticleShape.circle:
          canvas.drawCircle(Offset.zero, half, paint);
          canvas.drawCircle(Offset.zero, half, strokePaint);
          break;
        case ParticleShape.square:
          final rect = Rect.fromLTRB(-half, -half, half, half);
          canvas.drawRect(rect, paint);
          canvas.drawRect(rect, strokePaint);
          break;
        case ParticleShape.triangle:
          final path = Path()
            ..moveTo(0, -half)
            ..lineTo(half, half)
            ..lineTo(-half, half)
            ..close();
          canvas.drawPath(path, paint);
          canvas.drawPath(path, strokePaint);
          break;
        case ParticleShape.star:
          final path = Path()
            ..moveTo(0, -half)
            ..quadraticBezierTo(0, 0, half, 0)
            ..quadraticBezierTo(0, 0, 0, half)
            ..quadraticBezierTo(0, 0, -half, 0)
            ..quadraticBezierTo(0, 0, 0, -half)
            ..close();
          canvas.drawPath(path, paint);
          canvas.drawPath(path, strokePaint);
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
