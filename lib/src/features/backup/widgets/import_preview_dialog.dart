import 'package:flutter/material.dart';

/// How an imported backup is applied.
enum ImportMode { merge, replace }

/// Passphrase prompt used when opening a backup file.
Future<String?> promptBackupPassphrase(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Backup passphrase'),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: 'Passphrase for this file'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Open'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// Shows what the backup contains and asks how to apply it.
Future<ImportMode?> showImportPreviewDialog(
  BuildContext context, {
  required int entryCount,
  int photoCount = 0,
}) {
  final contents = StringBuffer()
    ..write('This backup contains $entryCount ')
    ..write(entryCount == 1 ? 'entry' : 'entries');
  if (photoCount > 0) {
    contents
      ..write(' and $photoCount ')
      ..write(photoCount == 1 ? 'photo' : 'photos');
  }
  return showDialog<ImportMode>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Restore backup'),
      content: Text(
        '$contents.\n\n'
        'Merge keeps your current entries and adds the backup '
        '(newer versions win). Replace overwrites your whole journal.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(ImportMode.replace),
          child: const Text('Replace'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(ImportMode.merge),
          child: const Text('Merge'),
        ),
      ],
    ),
  );
}
