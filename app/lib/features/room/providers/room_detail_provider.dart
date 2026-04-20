import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/room.dart';
import '../data/room_repository.dart';

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return RoomRepository();
});

class RoomDetailState {
  final Room? room;
  final bool isLoading;
  final String? error;
  final bool isJoining;

  const RoomDetailState({
    this.room,
    this.isLoading = false,
    this.error,
    this.isJoining = false,
  });

  RoomDetailState copyWith({
    Room? room,
    bool? isLoading,
    String? error,
    bool? isJoining,
  }) {
    return RoomDetailState(
      room: room ?? this.room,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isJoining: isJoining ?? this.isJoining,
    );
  }
}

class RoomDetailNotifier extends StateNotifier<RoomDetailState> {
  final RoomRepository _repository;
  final String roomId;

  RoomDetailNotifier(this._repository, this.roomId)
      : super(const RoomDetailState());

  Future<void> loadRoom() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final room = await _repository.getRoomDetail(roomId);
      state = state.copyWith(room: room, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '방 정보를 불러올 수 없습니다',
      );
    }
  }

  Future<Map<String, dynamic>?> joinRoom() async {
    state = state.copyWith(isJoining: true);
    try {
      final result = await _repository.joinRoom(roomId);
      await loadRoom(); // Refresh
      state = state.copyWith(isJoining: false);
      return result;
    } catch (e) {
      state = state.copyWith(isJoining: false);
      rethrow;
    }
  }

  Future<void> leaveRoom() async {
    try {
      await _repository.leaveRoom(roomId);
      await loadRoom();
    } catch (e) {
      rethrow;
    }
  }
}

final roomDetailProvider = StateNotifierProvider.family<RoomDetailNotifier,
    RoomDetailState, String>((ref, roomId) {
  final repository = ref.watch(roomRepositoryProvider);
  return RoomDetailNotifier(repository, roomId);
});
