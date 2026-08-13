import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/mawa_design.dart';
import '../../approvals/models/approval.dart';
import '../../approvals/screens/approval_detail_screen.dart';
import '../../approvals/services/approval_service.dart';
import '../models/inbox.dart';
import '../services/inbox_service.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with SingleTickerProviderStateMixin {
  final InboxService _service = InboxService();
  final ApprovalService _approvalService = ApprovalService();
  late final TabController _tabController;
  UserInbox? _inbox;
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final inbox = await _service.getInbox();
      if (!mounted) return;
      setState(() {
        _inbox = inbox;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _service.markAllRead();
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
    }
  }

  Future<void> _openApproval(Approval approval, {InboxNotification? notification}) async {
    if (notification != null && notification.isUnread) {
      try {
        await _service.markRead(notification.id);
      } catch (_) {}
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ApprovalDetailScreen(approval: approval)),
    );
    await _load();
  }

  Future<void> _openNotification(InboxNotification notification) async {
    if (notification.isUnread) {
      try {
        await _service.markRead(notification.id);
      } catch (_) {}
    }
    final approvalId = notification.approvalRequestId;
    if (approvalId == null || approvalId.isEmpty) {
      await _load();
      return;
    }
    try {
      final approval = await _approvalService.getApprovalById(approvalId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ApprovalDetailScreen(approval: approval)),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MawaDesign.page,
      appBar: AppBar(
        title: const Text('Inbox', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if ((_inbox?.unreadCount ?? 0) > 0)
            TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Mark all read'),
            ),
          IconButton(
            tooltip: 'Refresh inbox',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
        bottom: _inbox == null
            ? null
            : TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: 'For approval (${_inbox!.pendingApprovalCount})'),
                  Tab(text: 'Notifications (${_inbox!.unreadCount} unread)'),
                ],
              ),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: MawaDesign.textMuted),
              const SizedBox(height: 14),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    final inbox = _inbox!;
    return Column(
      children: [
        _summary(inbox),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search inbox',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _approvalList(inbox.pendingApprovals),
              _notificationList(inbox.notifications),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summary(UserInbox inbox) {
    return Container(
      width: double.infinity,
      color: MawaDesign.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _summaryCard(
            icon: Icons.approval_rounded,
            label: 'Waiting for you',
            value: '${inbox.pendingApprovalCount}',
            colour: MawaDesign.red,
          ),
          _summaryCard(
            icon: Icons.notifications_active_rounded,
            label: 'Unread updates',
            value: '${inbox.unreadCount}',
            colour: MawaDesign.info,
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color colour,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: colour.withOpacity(.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colour.withOpacity(.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colour),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              Text(label, style: const TextStyle(color: MawaDesign.textMuted, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _approvalList(List<Approval> approvals) {
    final query = _searchQuery.trim().toLowerCase();
    final visible = query.isEmpty
        ? approvals
        : approvals.where((approval) => [
            approval.title,
            approval.description,
            approval.referenceNo,
            approval.approvalType,
            approval.requesterId,
          ].join(' ').toLowerCase().contains(query)).toList();
    if (visible.isEmpty) {
      return _empty(
        Icons.task_alt_rounded,
        'You are all caught up',
        'New requests assigned to you will appear here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(18),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final approval = visible[index];
          return Material(
            color: MawaDesign.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openApproval(approval),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MawaDesign.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: MawaDesign.redSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.approval_rounded, color: MawaDesign.red),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  approval.title,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                              ),
                              _pill('Step ${approval.currentStepNo}', MawaDesign.info),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Text(
                            approval.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: MawaDesign.textMuted, height: 1.35),
                          ),
                          const SizedBox(height: 11),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _meta(Icons.tag_rounded, approval.referenceNo),
                              _meta(Icons.category_outlined, _label(approval.approvalType)),
                              _meta(Icons.schedule_rounded, _formatDate(_parseDate(approval.createdAt))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded, color: MawaDesign.textSubtle),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _notificationList(List<InboxNotification> notifications) {
    final query = _searchQuery.trim().toLowerCase();
    final visible = query.isEmpty
        ? notifications
        : notifications.where((notification) => [
            notification.title,
            notification.message,
            notification.notificationType,
            notification.approvalType ?? '',
            notification.approvalStatus ?? '',
            notification.referenceNo ?? '',
            notification.actionByDisplayName ?? '',
          ].join(' ').toLowerCase().contains(query)).toList();
    if (visible.isEmpty) {
      return _empty(
        Icons.notifications_none_rounded,
        'No notifications yet',
        'Approval decisions and new assigned items will appear here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(18),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final notification = visible[index];
          final colour = notification.isApprovalRequired ? MawaDesign.red : MawaDesign.info;
          return Material(
            color: notification.isUnread ? colour.withOpacity(.045) : MawaDesign.surface,
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () => _openNotification(notification),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: notification.isUnread ? colour.withOpacity(.30) : MawaDesign.border,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          backgroundColor: colour.withOpacity(.10),
                          foregroundColor: colour,
                          child: Icon(notification.isApprovalRequired
                              ? Icons.assignment_turned_in_outlined
                              : Icons.notifications_active_outlined),
                        ),
                        if (notification.isUnread)
                          Positioned(
                            right: -1,
                            top: -1,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: colour,
                                shape: BoxShape.circle,
                                border: Border.all(color: MawaDesign.surface, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: TextStyle(
                                    fontWeight: notification.isUnread ? FontWeight.w800 : FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                _formatDate(notification.createdAt),
                                style: const TextStyle(fontSize: 11, color: MawaDesign.textSubtle),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            notification.message,
                            style: const TextStyle(color: MawaDesign.textMuted, height: 1.4),
                          ),
                          if (notification.referenceNo?.isNotEmpty == true) ...[
                            const SizedBox(height: 9),
                            _meta(Icons.tag_rounded, notification.referenceNo!),
                          ],
                        ],
                      ),
                    ),
                    if (notification.approvalRequestId?.isNotEmpty == true)
                      const Padding(
                        padding: EdgeInsets.only(left: 8, top: 8),
                        child: Icon(Icons.chevron_right_rounded, color: MawaDesign.textSubtle),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _empty(IconData icon, String title, String description) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          Icon(icon, size: 58, color: MawaDesign.textSubtle),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(description, textAlign: TextAlign.center, style: const TextStyle(color: MawaDesign.textMuted)),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: MawaDesign.textSubtle),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12, color: MawaDesign.textMuted, fontWeight: FontWeight.w600)),
        ],
      );

  Widget _pill(String text, Color colour) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: colour.withOpacity(.09),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: TextStyle(fontSize: 11, color: colour, fontWeight: FontWeight.w800)),
      );

  DateTime? _parseDate(String raw) => DateTime.tryParse(raw.replaceFirst(' ', 'T'));

  String _formatDate(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final now = DateTime.now();
    if (now.difference(local).inHours < 24 && now.day == local.day) {
      return DateFormat('HH:mm').format(local);
    }
    return DateFormat('d MMM, HH:mm').format(local);
  }

  String _label(String value) => value
      .split('_')
      .map((part) => part.isEmpty ? part : '${part[0]}${part.substring(1).toLowerCase()}')
      .join(' ');
}
