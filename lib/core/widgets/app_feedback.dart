import 'package:flutter/material.dart';

import '../errors/app_error.dart';

class AppFeedback {
  const AppFeedback._();

  static void showError(
    BuildContext context,
    Object? error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  friendlyErrorMessage(error, fallback: fallback),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(
            label: 'DISMISS',
            textColor: Colors.white,
            onPressed: () => messenger.hideCurrentSnackBar(),
          ),
        ),
      );
  }
}
