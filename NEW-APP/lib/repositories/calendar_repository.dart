import 'dart:convert';
import 'database_repository.dart';
import 'settings_repository.dart';
import '../models/event_model.dart';

class CalendarRepository {
  final DatabaseRepository _dbRepo;
  final SettingsRepository _settingsRepo = SettingsRepository();

  CalendarRepository(this._dbRepo);

  // Load events (from SQLite only)
  Future<List<EventModel>> getEvents() async {
    return await _dbRepo.getEvents();
  }

  // Create event online and offline
  Future<void> createEvent(EventModel event) async {
    // 1. Save locally first
    await _dbRepo.insertEvent(event);

    // 2. Queue for sync
    await _settingsRepo.addToSyncQueue(
      entityType: 'event',
      entityId: event.id,
      action: 'create',
      payload: jsonEncode(event.toMap()),
    );
  }

  // Update Event
  Future<void> updateEvent(EventModel event) async {
    // 1. Save locally first
    await _dbRepo.updateEvent(event);

    // 2. Queue for sync
    if (event.googleEventId != null) {
      await _settingsRepo.addToSyncQueue(
        entityType: 'event',
        entityId: event.id,
        action: 'update',
        payload: jsonEncode(event.toMap()),
      );
    } else {
      // If it doesn't have a googleEventId, it's not yet synced.
      // Update the payload of its pending 'create' action in the queue.
      final queue = await _settingsRepo.getSyncQueue();
      bool found = false;
      for (var item in queue) {
        if (item['entity_type'] == 'event' &&
            item['entity_id'] == event.id &&
            item['action'] == 'create') {
          await _settingsRepo.removeFromSyncQueue(item['id'] as int);
          await _settingsRepo.addToSyncQueue(
            entityType: 'event',
            entityId: event.id,
            action: 'create',
            payload: jsonEncode(event.toMap()),
          );
          found = true;
          break;
        }
      }
      if (!found) {
        await _settingsRepo.addToSyncQueue(
          entityType: 'event',
          entityId: event.id,
          action: 'create',
          payload: jsonEncode(event.toMap()),
        );
      }
    }
  }

  // Delete Event
  Future<void> deleteEvent(String localId, String? googleEventId) async {
    // 1. Delete locally first
    await _dbRepo.deleteEvent(localId);

    // 2. Queue for sync
    if (googleEventId != null) {
      await _settingsRepo.addToSyncQueue(
        entityType: 'event',
        entityId: googleEventId,
        action: 'delete',
      );
    } else {
      // Remove pending create/update actions for this event from the queue
      final queue = await _settingsRepo.getSyncQueue();
      for (var item in queue) {
        if (item['entity_type'] == 'event' && item['entity_id'] == localId) {
          await _settingsRepo.removeFromSyncQueue(item['id'] as int);
        }
      }
    }
  }
}
