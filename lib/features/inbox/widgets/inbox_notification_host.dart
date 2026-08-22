import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_guards.dart';
import '../../../core/theme/mawa_design.dart';
import '../../approvals/navigation/approval_item_navigator.dart';
import '../../approvals/screens/approval_detail_screen.dart';
import '../../approvals/services/approval_service.dart';
import '../models/inbox.dart';
import '../services/inbox_service.dart';

/// Global Outlook-style inbox toast host.
///
/// Inbox notifications remain durable on the backend. The host only controls
/// whether an unread notification has already been surfaced during this app
/// session. Auto-dismiss does not mark the notification read, so the inbox
/// badge remains the fallback when a user misses the toast.
class InboxNotificationHost extends StatefulWidget {
  final Widget child;

  const InboxNotificationHost({super.key, required this.child});

  @override
  State<InboxNotificationHost> createState() => _InboxNotificationHostState();
}

class _InboxNotificationHostState extends State<InboxNotificationHost> {
  static const _pollInterval = Duration(seconds: 15);
  static const _displayDuration = Duration(seconds: 8);

  final InboxService _inboxService = InboxService();
  final ApprovalService _approvalService = ApprovalService();
  final Set<String> _surfaced = <String>{};
  final List<InboxNotification> _queue = <InboxNotification>[];

  Timer? _pollTimer;
  Timer? _dismissTimer;
  InboxNotification? _active;
  bool _polling = false;
  bool _initialised = false;
  String? _sessionUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _poll());
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _dismissTimer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polling || !mounted) return;
    if (!await RouteGuards.isAuthenticated()) {
      _resetSession();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('userId');
    if (_sessionUserId != null && currentUserId != _sessionUserId) {
      _resetSession();
    }
    _sessionUserId = currentUserId;

    _polling = true;
    try {
      final notifications = await _inboxService.getUnreadNotifications(limit: 20);
      final eligible = notifications
          .where((notification) =>
              notification.notificationType == 'APPROVAL_ACTIONED' ||
              notification.notificationType == 'APPROVAL_REQUIRED')
          .where((notification) => !_surfaced.contains(notification.id))
          .toList();

      if (!_initialised) {
        // Avoid flooding a user with an old unread backlog at login. Surface
        // the newest unread item and leave the rest available in Inbox.
        _initialised = true;
        for (final notification in notifications) {
          _surfaced.add(notification.id);
        }
        if (eligible.isNotEmpty) {
          _queue.add(eligible.first);
        }
      } else {
        for (final notification in eligible.reversed) {
          _surfaced.add(notification.id);
          _queue.add(notification);
        }
      }
      _showNext();
    } catch (_) {
      // Notifications are supplemental. Normal inbox/badge behavior remains
      // available if a poll fails.
    } finally {
      _polling = false;
    }
  }


  void _resetSession() {
    _dismissTimer?.cancel();
    _queue.clear();
    _surfaced.clear();
    _initialised = false;
    _sessionUserId = null;
    if (mounted && _active != null) {
      setState(() => _active = null);
    } else {
      _active = null;
    }
  }

  void _showNext() {
    if (!mounted || _active != null || _queue.isEmpty) return;
    setState(() => _active = _queue.removeAt(0));
    _dismissTimer?.cancel();
    _dismissTimer = Timer(_displayDuration, () => _dismiss(markRead: false));
  }

  Future<void> _dismiss({required bool markRead}) async {
    final notification = _active;
    if (notification == null) return;
    _dismissTimer?.cancel();
    if (mounted && _active?.id == notification.id) {
      setState(() => _active = null);
      Future<void>.delayed(const Duration(milliseconds: 180), _showNext);
    }
    if (markRead) {
      try {
        await _inboxService.markRead(notification.id);
      } catch (_) {}
    }
  }

  Future<void> _openActive() async {
    final notification = _active;
    if (notification == null) return;

    await _dismiss(markRead: true);
    final approvalId = notification.approvalRequestId;
    if (approvalId == null || approvalId.isEmpty) {
      AppRouter.router.push(AppRoutes.inbox);
      return;
    }

    try {
      final approval = await _approvalService.getApprovalById(approvalId);
      final context = AppRouter.navigatorKey.currentContext;
      if (context == null) {
        AppRouter.router.push(AppRoutes.inbox);
        return;
      }

      if (notification.notificationType == 'APPROVAL_ACTIONED') {
        final opened = await ApprovalItemNavigator.openOriginal(context, approval);
        if (opened) return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ApprovalDetailScreen(approval: approval)),
      );
    } catch (_) {
      AppRouter.router.push(AppRoutes.inbox);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notification = _active;
    return Stack(
      children: [
        widget.child,
        if (notification != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            right: MediaQuery.sizeOf(context).width < 620 ? 12 : 20,
            left: MediaQuery.sizeOf(context).width < 620 ? 12 : null,
            child: _NotificationToast(
              key: ValueKey(notification.id),
              notification: notification,
              onOpen: _openActive,
              onClose: () => _dismiss(markRead: true),
            ),
          ),
      ],
    );
  }
}

class _NotificationToast extends StatelessWidget {
  final InboxNotification notification;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  const _NotificationToast({
    super.key,
    required this.notification,
    required this.onOpen,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isRequired = notification.notificationType == 'APPROVAL_REQUIRED';
    final accent = isRequired ? MawaDesign.red : MawaDesign.info;
    final actionLabel = isRequired ? 'Review approval' : 'Open item';

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 240),
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) => Transform.translate(
        offset: Offset(28 * (1 - value), 0),
        child: Opacity(opacity: value, child: child),
      ),
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 410),
          child: Container(
            decoration: BoxDecoration(
              color: MawaDesign.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MawaDesign.border),
              boxShadow: MawaDesign.floatingShadow,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isRequired ? Icons.approval_rounded : Icons.mark_email_read_outlined,
                                size: 18,
                                color: accent,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'MAWA Inbox',
                                  style: TextStyle(
                                    color: MawaDesign.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close',
                                visualDensity: VisualDensity.compact,
                                onPressed: onClose,
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                            ],
                          ),
                          Text(
                            notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: MawaDesign.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.message,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: MawaDesign.textMuted,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                          if (notification.referenceNo?.isNotEmpty == true) ...[
                            const SizedBox(height: 7),
                            Text(
                              notification.referenceNo!,
                              style: TextStyle(
                                color: accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                          const SizedBox(height: 9),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: onOpen,
                              icon: const Icon(Icons.open_in_new_rounded, size: 16),
                              label: Text(actionLabel),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
