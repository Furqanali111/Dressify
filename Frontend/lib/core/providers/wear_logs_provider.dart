import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/wear_log.dart';

class WearLogsState {
  const WearLogsState({
    this.items = const <WearLog>[],
    this.loading = false,
    this.nextCursor,
  });

  final List<WearLog> items;
  final bool loading;
  final String? nextCursor;

  WearLogsState copyWith({
    List<WearLog>? items,
    bool? loading,
    String? nextCursor,
  }) =>
      WearLogsState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        nextCursor: nextCursor ?? this.nextCursor,
      );
}

class WearLogsNotifier extends StateNotifier<WearLogsState> {
  WearLogsNotifier(this._ref) : super(const WearLogsState()) {
    fetch();
  }

  final Ref _ref;

  Future<void> fetch() async {
    state = state.copyWith(loading: true);
    try {
      final Dio dio = _ref.read(apiClientProvider);
      final Response<dynamic> res = await dio.get<dynamic>('/wear-logs');
      final dynamic data = res.data;
      
      final List<dynamic> raw = (data as Map<String, dynamic>)['items'] as List<dynamic>;
      final String? cursor = data['next_cursor'] as String?;
      
      final List<WearLog> items = raw
          .map((e) => WearLog.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(items: items, nextCursor: cursor, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> fetchMore() async {
    if (state.nextCursor == null || state.loading) return;
    try {
      final Dio dio = _ref.read(apiClientProvider);
      final Response<dynamic> res = await dio.get<dynamic>(
        '/wear-logs',
        queryParameters: <String, dynamic>{'cursor': state.nextCursor},
      );
      final dynamic data = res.data;
      
      final List<dynamic> raw = (data as Map<String, dynamic>)['items'] as List<dynamic>;
      final String? cursor = data['next_cursor'] as String?;
      
      final List<WearLog> newItems = raw
          .map((e) => WearLog.fromJson(e as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        items: [...state.items, ...newItems],
        nextCursor: cursor,
      );
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }
}

final StateNotifierProvider<WearLogsNotifier, WearLogsState> wearLogsProvider =
    StateNotifierProvider<WearLogsNotifier, WearLogsState>(
  WearLogsNotifier.new,
);
