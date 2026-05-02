import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/notification_item.dart';
import '../../core/providers/notifications_provider.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

String _timeAgo(DateTime dt) {
  final Duration diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${(diff.inDays / 7).floor()}w ago';
}

IconData _iconForType(String type) {
  switch (type) {
    case 'outfit_saved':
      return Icons.checkroom_outlined;
    case 'upload_complete':
      return Icons.cloud_done_outlined;
    case 'style_tip':
      return Icons.auto_awesome_outlined;
    default:
      return Icons.notifications_outlined;
  }
}

class NotificationsSheet extends ConsumerStatefulWidget {
  const NotificationsSheet({super.key});

  @override
  ConsumerState<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends ConsumerState<NotificationsSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsProvider.notifier).openSheet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final NotificationsState state = ref.watch(notificationsProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheetTop),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Row(
                children: <Widget>[
                  Text('Notifications', style: text.titleLarge),
                  const Spacer(),
                  if (state.unreadCount > 0)
                    TextButton(
                      onPressed: () => ref.read(notificationsProvider.notifier).markAllRead(),
                      child: const Text('Mark all as read'),
                    ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Flexible(
              child: state.loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                      child: CircularProgressIndicator(),
                    )
                  : state.items.isEmpty
                      ? _EmptyState(c: c, text: text)
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md,
                          ),
                          itemCount: state.items.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            color: c.border.withValues(alpha: 0.5),
                          ),
                          itemBuilder: (_, int i) {
                            final item = state.items[i];
                            return _NotificationTile(
                              item: item,
                              onRead: () => ref.read(notificationsProvider.notifier).markAsRead(item.id),
                            );
                          },
                        ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.lg,
              ),
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.goNamed(AppRoute.profile.name);
                },
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('Manage notification settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.c, required this.text});
  final AppColors c;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xxl,
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.notifications_none_rounded,
            size: 56,
            color: c.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text("You're all caught up!", style: text.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Upload completions, outfit saves, and\nstyle alerts will appear here.',
            style: text.bodyMedium?.copyWith(color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onRead});
  final NotificationItem item;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final bool unread = !item.isRead;

    return InkWell(
      onTap: onRead,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: unread ? 0.15 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconForType(item.type),
                size: 18,
                color: c.primary.withValues(alpha: unread ? 1.0 : 0.6),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.title,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.body,
                    style: text.bodySmall?.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(item.createdAt),
                    style: text.bodySmall?.copyWith(
                      color: c.textSecondary.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4, left: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: c.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
