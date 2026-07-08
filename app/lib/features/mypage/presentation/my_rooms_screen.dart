import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/chat_message.dart';
import '../../../models/room.dart';
import '../../../widgets/design/accent_blobs.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading.dart';
import '../../chat/providers/chat_provider.dart';
import '../../home/presentation/widgets/room_card.dart';
import '../../room/providers/room_detail_provider.dart';

class MyRoomsScreen extends ConsumerStatefulWidget {
  const MyRoomsScreen({super.key});

  @override
  ConsumerState<MyRoomsScreen> createState() => _MyRoomsScreenState();
}

class _MyRoomsScreenState extends ConsumerState<MyRoomsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Room>? _upcomingRooms;
  List<Room>? _pastRooms;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadRooms();
      }
    });
    _loadRooms();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    final index = _tabController.index;
    try {
      final status = index == 0 ? 'UPCOMING' : 'PAST';
      final rooms = await ref
          .read(roomRepositoryProvider)
          .getMyRooms(type: 'ALL', status: status);
      if (!mounted) return;
      setState(() {
        if (index == 0) {
          _upcomingRooms = rooms;
        } else {
          _pastRooms = rooms;
        }
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '모임 목록을 불러올 수 없습니다');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AccentBlobsBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: AppColors.primary200, width: 0.8),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.ink500,
                    labelStyle: AppTextStyles.body2Bold,
                    unselectedLabelStyle: AppTextStyles.body2,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: '예정된 모임'),
                      Tab(text: '지난 모임'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRoomList(_upcomingRooms),
                    _buildRoomList(_pastRooms),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomList(List<Room>? rooms) {
    // 아직 한 번도 안 불러온 탭만 shimmer/에러 표시. 캐시가 있으면
    // 화면을 유지한 채 백그라운드로 갱신해 탭 전환 시 깜빡임을 막는다.
    if (rooms == null) {
      if (_error != null) {
        return ErrorState(message: _error!, onRetry: _loadRooms);
      }
      return const ShimmerList();
    }

    if (rooms.isEmpty) {
      return const EmptyState(
        icon: Icons.event_note_rounded,
        title: '모임이 없습니다',
      );
    }

    // 방별 안 읽은 메시지 수 — 하단 탭 배지 총합이 어느 방에서 온 건지
    // 채팅 아이콘 배지로 보여준다.
    final chatRooms = ref.watch(chatRoomsProvider).valueOrNull;
    final unreadByChatRoom = <String, int>{
      for (final c in chatRooms ?? const <ChatRoom>[]) c.id: c.unreadCount,
    };

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(chatRoomsProvider);
        await _loadRooms();
      },
      color: AppColors.primary,
      child: ListView.builder(
        // 모임 탭과 동일한 수평 여백 — 없으면 카드가 화면 폭 100%로 붙는다.
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final room = rooms[index];
          return RoomCard(
            room: room,
            // 카드 어디든 탭하면 방 상세. 채팅은 우측 보조 아이콘으로 유지.
            onTap: () => context.push('/rooms/${room.id}'),
            onOpenChat: room.chatRoomId != null
                ? () => context.push('/chat/${room.chatRoomId}')
                : null,
            unreadCount: unreadByChatRoom[room.chatRoomId] ?? 0,
          );
        },
      ),
    );
  }
}
