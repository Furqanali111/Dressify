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

      if (state.unreadCount > 0) {
        await dio.post<dynamic>('/notifications/read-all');
      }

      state = state.copyWith(items: items, unreadCount: 0, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  void reset() => state = const NotificationsState();
}

final StateNotifierProvider<NotificationsNotifier, NotificationsState>
    notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>(
  NotificationsNotifier.new,
);
