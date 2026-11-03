import 'package:flutter/material.dart';

import '../errors/app_failure.dart';

/// Asks the user to confirm a destructive action.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool isDestructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Shows the real reason of a failure, including the Discord error code.
void showFailure(BuildContext context, Object error) {
  final message = error is AppFailure ? error.message : 'The action failed.';
  final code = error is AppFailure ? error.discordCode : null;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          code == null ? message : '$message (Discord error $code)',
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
}

/// Shows a short confirmation of a successful action.
void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
