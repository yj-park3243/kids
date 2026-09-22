import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_error.dart';
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
        error: apiErrorMessage(e, fallback: '방 정보를 불러올 수 없습니다'),
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

  /// 나가기 성공 후 재조회까지 됐는지 돌려준다 — 재조회가 실패하면 화면이
  /// 참여자 상태로 남아 사용자가 '나가기가 안 됐다'고 오해한다.
  Future<bool> leaveRoom() async {
    await _repository.leaveRoom(roomId);
    await loadRoom();
    return state.error == null;
  }

  /// 방장이 참여자를 내보낸다. 성공 후 방을 다시 불러온다.
  Future<void> kickMember(String userId) async {
    await _repository.kickMember(roomId, userId);
    await loadRoom();
  }
}

final roomDetailProvider = StateNotifierProvider.family<RoomDetailNotifier,
    RoomDetailState, String>((ref, roomId) {
  final repository = ref.watch(roomRepositoryProvider);
  return RoomDetailNotifier(repository, roomId);
});

/// 방의 대기 중(PENDING) 참여 신청 — 방장이 방 상세에서 인라인으로 관리.
final joinRequestsProvider =
    FutureProvider.family<List<JoinRequest>, String>((ref, roomId) async {
  final all = await ref.watch(roomRepositoryProvider).getJoinRequests(roomId);
  return all.where((r) => r.status == 'PENDING').toList();
});
