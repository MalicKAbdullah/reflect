import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect/src/core/di.dart';
import 'package:reflect/src/features/auth/providers/auth_providers.dart';

/// Decrypted bytes for one photo attachment, or null while locked / when
/// the file is unavailable. Watches the session, so any cached value is
/// dropped (and recomputed to null) the moment the app locks.
final photoBytesProvider =
    FutureProvider.autoDispose.family<Uint8List?, String>((ref, id) async {
  final status = ref.watch(sessionProvider);
  if (status != AuthStatus.unlocked) return null;
  final session = ref.read(sessionProvider.notifier);
  return ref
      .read(attachmentServiceProvider)
      .loadPhoto(id: id, key: session.dataKey);
});
