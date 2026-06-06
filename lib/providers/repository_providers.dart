import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/database_repository.dart';
import '../repositories/drive_repository.dart';
import '../repositories/auth_repository.dart';
import '../providers/auth_provider.dart';

/// Central DatabaseRepository provider used across the app.
final databaseRepositoryProvider = Provider<DatabaseRepository>((ref) {
  return DatabaseRepository();
});

/// Central DriveRepository provider used across the app.
final driveRepositoryProvider = Provider<DriveRepository>((ref) {
  final dbRepo = ref.watch(databaseRepositoryProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  return DriveRepository(dbRepo, authRepo);
});
