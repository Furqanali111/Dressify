import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/notification_item.dart';

class NotificationsState {
  const NotificationsState({
    this.items = const <NotificationItem>[],
    this.unreadCount = 0,
    this.loading = false,
  });

  final List<NotificationItem> items;
  final int unreadCount;
  final bool loading;

  NotificationsState copyWith({
    List<NotificationItem>? items,
    int? unreadCount,
    bool? loading,
  }) =>
      NotificationsState(
        items: items ?? this.items,
        unreadCount: unreadCount ?? this.unreadCount,
        loading: loading ?? this.loading,
      );
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier(this._ref) : super(const NotificationsState()) {
    _fetchCount();
  }

  final Ref _ref;

  Future<void> _fetchCount() async {
    try {
      final Dio dio = _ref.read(apiClientProvider);
      final Response<dynamic> res = await dio.get<dynamic>('/notifications/unread-count');
      final int count =
          ((res.data as Map<String, dynamic>)['count'] as int?) ?? 0;
      state = state.copyWith(unreadCount: count);
    } catch (_) {}
  }

  Future<void> openSheet() async {
    state = state.copyWith(loading: true);
    try {
      final Dio dio = _ref.read(apiClientProvider);
      final Response<dynamic> res = await dio.get<dynamic>('/notifications');
      final List<NotificationItem> items = (res.data as List<dynamic>)
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(items: items, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> markAsRead(String id) async {
    final List<NotificationItem> current = state.items;
    final int idx = current.indexWhere((it) => it.id == id);
    if (idx == -1 || current[idx].isRead) return;

    // Optimistic update
    final List<NotificationItem> next = List<NotificationItem>.from(current);
    next[idx] = next[idx].copyWith(isRead: true);
    state = state.copyWith(items: next, unreadCount: (state.unreadCount - 1).clamp(0, 999));

    try {
      final Dio dio = _ref.read(apiClientProvider);
      await dio.patch<dynamic>('/notifications/$id/read');
    } catch (_) {
      // Rollback on failure if needed, but usually not critical for read status
    }
  }

  Future<void> markAllRead() async {
    if (state.unreadCount == 0) return;
    try {
      final Dio dio = _ref.read(apiClientProvider);
      await dio.post<dynamic>('/notifications/read-all');
      final List<NotificationItem> next = state.items.map((it) => it.copyWith(isRead: true)).toList();
      state = state.copyWith(items: next, unreadCount: 0);
    } catch (_) {}
  }

  void reset() => state = const NotificationsState();
}

final StateNotifierProvider<NotificationsNotifier, NotificationsState>
    notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>(
  NotificationsNotifier.new,
);
