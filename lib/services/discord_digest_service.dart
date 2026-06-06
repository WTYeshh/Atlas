import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../core/config.dart';
import '../repositories/settings_repository.dart';
import '../providers/calendar_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/repository_providers.dart';
import '../models/event_model.dart';

final discordDigestServiceProvider = Provider<DiscordDigestService>((ref) {
  return DiscordDigestService(ref);
});

class DiscordDigestService {
  final Ref _ref;
  final SettingsRepository _settingsRepo = SettingsRepository();

  DiscordDigestService(this._ref);

  /// Compares dates and triggers digests if enabled and not already sent today/this week.
  Future<void> checkAndTriggerDigests() async {
    if (kIsWeb) return;

    try {
      final enabled = await _settingsRepo.getDiscordSyncEnabled();
      if (!enabled) return;

      final dailyEnabled = await _settingsRepo.getSetting('discord_daily_digest_enabled') == 'true';
      final weeklyEnabled = await _settingsRepo.getSetting('discord_weekly_digest_enabled') == 'true';

      if (!dailyEnabled && !weeklyEnabled) return;

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      
      // 1. Check Daily Digest
      if (dailyEnabled) {
        final lastDaily = await _settingsRepo.getSetting('last_daily_digest_date');
        if (lastDaily != todayStr) {
          print('DiscordDigestService: Triggering Daily Digest...');
          final success = await sendDailyDigest();
          if (success) {
            await _settingsRepo.saveSetting('last_daily_digest_date', todayStr);
          }
        }
      }

      // 2. Check Weekly Digest (On Sunday evening or Monday morning)
      if (weeklyEnabled) {
        // We use Year-Week format e.g. "2026-W23" to identify a unique week
        final String weekKey = '${now.year}-W${_getWeekOfYear(now)}';
        final lastWeekly = await _settingsRepo.getSetting('last_weekly_digest_week');
        
        if (lastWeekly != weekKey) {
          print('DiscordDigestService: Triggering Weekly Digest...');
          final success = await sendWeeklyDigest();
          if (success) {
            await _settingsRepo.saveSetting('last_weekly_digest_week', weekKey);
          }
        }
      }
    } catch (e) {
      print('DiscordDigestService: Error during checkAndTriggerDigests: $e');
    }
  }

  /// Sends the Daily Briefing Embed to Discord.
  Future<bool> sendDailyDigest({bool force = false}) async {
    const botToken = AppConfig.discordBotToken;
    const channelId = AppConfig.discordChannelId;

    if (botToken == 'YOUR_DISCORD_BOT_TOKEN' || botToken.trim().isEmpty ||
        channelId == 'YOUR_DISCORD_CHANNEL_ID' || channelId.trim().isEmpty) {
      print('DiscordDigestService: Discord not configured.');
      return false;
    }

    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final displayDate = DateFormat('EEEE, dd-MM-yyyy').format(now);

      // Fetch today's schedule events
      final calendarRepo = _ref.read(calendarRepositoryProvider);
      final allEvents = await calendarRepo.getEvents();
      final todayEvents = allEvents.where((e) => e.date == todayStr).toList();

      // Fetch pending tasks
      final dbRepo = _ref.read(databaseRepositoryProvider);
      final allTasks = await dbRepo.getTasks();
      final pendingTasks = allTasks.where((t) => t.status == 'pending').toList();

      // Fetch attendance standing
      final attendanceNotifier = _ref.read(attendanceProvider.notifier);
      final attendanceState = _ref.read(attendanceProvider);
      final subjects = attendanceState.subjects;
      final subjectStats = attendanceNotifier.getSubjectStats();

      // Formulate schedule string
      String scheduleText = '';
      if (todayEvents.isEmpty) {
        scheduleText = 'No classes or events scheduled for today. 🎉';
      } else {
        scheduleText = todayEvents.map((e) {
          final catPrefix = e.category != null ? '[${e.category}] ' : '';
          return '⏰ **${e.time}** - $catPrefix${e.title}';
        }).join('\n');
      }

      // Formulate tasks string
      String tasksText = '';
      if (pendingTasks.isEmpty) {
        tasksText = 'All caught up! No pending assignments. 👍';
      } else {
        tasksText = pendingTasks.take(5).map((t) {
          final priorityEmoji = t.priority == 'high' ? '🔴' : t.priority == 'medium' ? '🟡' : '🟢';
          final subPrefix = t.subject != null ? '[${t.subject}] ' : '';
          return '$priorityEmoji $subPrefix${t.title} *(Due: ${_formatDisplayDate(t.dueDate)})*';
        }).join('\n');
        if (pendingTasks.length > 5) {
          tasksText += '\n*...and ${pendingTasks.length - 5} more pending tasks*';
        }
      }

      // Formulate attendance string (only show low standing warnings or overview)
      String attendanceText = '';
      final List<String> warnings = [];
      for (var sub in subjects) {
        final stats = subjectStats[sub.id];
        if (stats != null) {
          final double percentage = stats['percentage'] ?? 0.0;
          final int held = stats['held'] ?? 0;
          if (percentage < sub.minPercentage && held > 0) {
            final projections = attendanceNotifier.getSubjectProjections(sub.id, allEvents);
            final statusMessage = projections['statusMessage'] ?? 'Attendance is low.';
            warnings.add('⚠️ **${sub.name}**: ${percentage.toStringAsFixed(1)}% (Min ${sub.minPercentage.toInt()}%)\n└ *$statusMessage*');
          }
        }
      }

      if (warnings.isEmpty) {
        final overallStats = attendanceNotifier.getOverallStats();
        final double overallPercent = overallStats['percentage'] ?? 0.0;
        attendanceText = '✅ All attendance standings are in good standing.\n**Overall Attendance:** ${overallPercent.toStringAsFixed(1)}%';
      } else {
        attendanceText = warnings.join('\n');
      }

      final payload = {
        'embeds': [
          {
            'title': '📅 ATLAS Daily Briefing',
            'description': 'Here is your personalized academic agenda for **$displayDate**.',
            'color': 3447003, // Steel blue hex in integer
            'fields': [
              {
                'name': '📚 Today\'s Schedule',
                'value': scheduleText,
                'inline': false
              },
              {
                'name': '📝 Pending Assignments & Tasks',
                'value': tasksText,
                'inline': false
              },
              {
                'name': '📊 Attendance Standings',
                'value': attendanceText,
                'inline': false
              }
            ],
            'footer': {
              'text': 'Sent from Atlas Mobile Hub'
            },
            'timestamp': DateTime.now().toUtc().toIso8601String()
          }
        ]
      };

      final response = await http.post(
        Uri.parse('https://discord.com/api/v10/channels/$channelId/messages'),
        headers: {
          'Authorization': 'Bot $botToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('DiscordDigestService: Sent daily digest successfully.');
        return true;
      } else {
        print('DiscordDigestService: Failed to send daily digest: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('DiscordDigestService: Error sending daily digest: $e');
      return false;
    }
  }

  /// Sends the Weekly Outlook Embed to Discord.
  Future<bool> sendWeeklyDigest({bool force = false}) async {
    const botToken = AppConfig.discordBotToken;
    const channelId = AppConfig.discordChannelId;

    if (botToken == 'YOUR_DISCORD_BOT_TOKEN' || botToken.trim().isEmpty ||
        channelId == 'YOUR_DISCORD_CHANNEL_ID' || channelId.trim().isEmpty) {
      print('DiscordDigestService: Discord not configured.');
      return false;
    }

    try {
      final now = DateTime.now();
      final calendarRepo = _ref.read(calendarRepositoryProvider);
      final allEvents = await calendarRepo.getEvents();
      final next7Days = now.add(const Duration(days: 7));

      // Filter events in the next 7 days
      final weeklyEvents = allEvents.where((e) {
        final eDate = DateTime.tryParse(e.date);
        if (eDate == null) return false;
        return eDate.isAfter(now.subtract(const Duration(days: 1))) && eDate.isBefore(next7Days);
      }).toList();

      // Fetch pending tasks
      final dbRepo = _ref.read(databaseRepositoryProvider);
      final allTasks = await dbRepo.getTasks();
      final pendingTasks = allTasks.where((t) => t.status == 'pending').toList();

      // Group events by day
      final Map<String, List<EventModel>> groupedEvents = {};
      for (var event in weeklyEvents) {
        groupedEvents.putIfAbsent(event.date, () => []).add(event);
      }

      final sortedDates = groupedEvents.keys.toList()..sort();

      String agendaText = '';
      if (weeklyEvents.isEmpty) {
        agendaText = 'No events scheduled for the coming week. Enjoy your free time! 😎';
      } else {
        for (var dateStr in sortedDates.take(5)) {
          final date = DateTime.tryParse(dateStr);
          final displayDate = date != null ? DateFormat('EEEE, dd-MM').format(date) : dateStr;
          final dayEvents = groupedEvents[dateStr] ?? [];
          
          agendaText += '🔹 **$displayDate**\n';
          for (var e in dayEvents) {
            agendaText += '  • `${e.time}` - ${e.title}\n';
          }
          agendaText += '\n';
        }
        if (sortedDates.length > 5) {
          agendaText += '*...and more classes/exams scheduled later in the week*';
        }
      }

      // Tasks due in the coming week
      final weekTasks = pendingTasks.where((t) {
        final tDate = DateTime.tryParse(t.dueDate);
        if (tDate == null) return false;
        return tDate.isBefore(next7Days);
      }).toList();

      String tasksText = '';
      if (weekTasks.isEmpty) {
        tasksText = 'No tasks due this week. Nice! 🏖️';
      } else {
        tasksText = weekTasks.map((t) {
          final priorityEmoji = t.priority == 'high' ? '🔴' : t.priority == 'medium' ? '🟡' : '🟢';
          return '$priorityEmoji **${t.title}** (Due: ${_formatDisplayDate(t.dueDate)})';
        }).join('\n');
      }

      // Add a quote or motivating message
      const quote = '“It always seems impossible until it’s done.” — Nelson Mandela';

      final payload = {
        'embeds': [
          {
            'title': '🗓️ ATLAS Weekly Outlook',
            'description': 'Here is your agenda and milestones for the upcoming week.',
            'color': 10181046, // Purple color
            'fields': [
              {
                'name': '📅 Weekly Class & Exam Schedule',
                'value': agendaText,
                'inline': false
              },
              {
                'name': '🚨 Deadlines This Week',
                'value': tasksText,
                'inline': false
              },
              {
                'name': '💡 Motivation of the Week',
                'value': quote,
                'inline': false
              }
            ],
            'footer': {
              'text': 'Sent from Atlas Mobile Hub'
            },
            'timestamp': DateTime.now().toUtc().toIso8601String()
          }
        ]
      };

      final response = await http.post(
        Uri.parse('https://discord.com/api/v10/channels/$channelId/messages'),
        headers: {
          'Authorization': 'Bot $botToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('DiscordDigestService: Sent weekly digest successfully.');
        return true;
      } else {
        print('DiscordDigestService: Failed to send weekly digest: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('DiscordDigestService: Error sending weekly digest: $e');
      return false;
    }
  }

  // --- Helper Methods ---

  String _formatDisplayDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return '${parts[2]}-${parts[1]}';
      }
    } catch (_) {}
    return dateStr;
  }

  int _getWeekOfYear(DateTime time) {
    final dayOfYear = int.parse(DateFormat('D').format(time));
    return ((dayOfYear - time.weekday + 10) / 7).floor();
  }
}
