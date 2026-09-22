import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/chat_message.dart';
import '../../../models/room.dart';
import '../../../widgets/design/design_chip.dart';
import '../../../widgets/design/notebook.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading.dart';
import '../../auth/providers/auth_provider.dart';
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

  // 세그먼트가 칠할 인덱스. 컨트롤러는 스와이프 중 매 프레임 알림을 보내므로
  // 값이 실제로 바뀔 때만 다시 그린다.
  int _segmentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadRooms();
      }
      if (mounted && _segmentIndex != _tabController.index) {
        setState(() => _segmentIndex = _tabController.index);
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
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            // 화면 제목 — 높이 42 는 '모임 찾기' 탭 헤더와 같은 값.
            // 탭을 오갈 때 아래 목록이 위아래로 튀지 않게 한다.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: SizedBox(
                height: 32,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('내 모임', style: AppTextStyles.screenTitle),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _Segment(
                labels: [
                  _segmentLabel('예정', _upcomingRooms),
                  _segmentLabel('지난', _pastRooms),
                ],
                index: _segmentIndex,
                onChanged: (i) => _tabController.animateTo(i),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRoomList(_upcomingRooms, past: false),
                  _buildRoomList(_pastRooms, past: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _segmentLabel(String base, List<Room>? rooms) =>
      rooms == null ? base : '$base ${rooms.length}';

  Widget _buildRoomList(List<Room>? rooms, {required bool past}) {
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
    // 행 오른쪽 berry 배지로 보여준다.
    final chatRooms = ref.watch(chatRoomsProvider).valueOrNull;
    final unreadByChatRoom = <String, int>{
      for (final c in chatRooms ?? const <ChatRoom>[]) c.id: c.unreadCount,
    };
    final myId = ref.watch(authProvider).user?.id;
    final items = _buildListItems(rooms);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(chatRoomsProvider);
        await _loadRooms();
      },
      color: AppColors.ink,
      child: ListView.builder(
        // '모임 찾기' 목록과 같은 좌우 여백.
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          if (item.groupLabel != null) return GroupLabel(item.groupLabel!);
          final room = rooms[item.roomIndex!];
          final unread = unreadByChatRoom[room.chatRoomId] ?? 0;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.showDivider) const DashedDivider(),
              RoomCard(
                room: room,
                // 행 어디든 탭하면 방 상세. 채팅은 안읽음 배지로 들어간다.
                onTap: () => context.push('/rooms/${room.id}'),
                onOpenChat: room.chatRoomId != null
                    ? () => context.push('/chat/${room.chatRoomId}')
                    : null,
                unreadCount: unread,
                pills: _myRoomPills(room, myId),
                // 여기 있는 방은 전부 내가 참여 중이다 — '모집중' 상태를
                // 되풀이하지 않고, 지난 모임만 끝났음을 적는다.
                trailing: past
                    ? Padding(
                        padding: EdgeInsets.only(top: unread > 0 ? 6 : 0),
                        child: Pill(
                          label: room.status == 'CANCELLED' ? '취소' : '종료',
                          tone: PillTone.muted,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 내 모임 행의 pill — 내가 만든 모임(형광펜) + 인원.
  List<Widget> _myRoomPills(Room room, String? myId) {
    return [
      if (myId != null && room.host.id == myId)
        const Pill(label: '내가 만든 모임', tone: PillTone.hi),
      Pill(
        label: '${room.currentMembers}/${room.maxMembers}명',
        tone: PillTone.muted,
      ),
    ];
  }

  /// 날짜 그룹 라벨 + 행 구조. '모임 찾기' 목록과 같은 규칙.
  List<_MyRoomItem> _buildListItems(List<Room> rooms) {
    final items = <_MyRoomItem>[];
    String? currentGroup;
    for (var i = 0; i < rooms.length; i++) {
      final date = DateTime.tryParse(rooms[i].date);
      final group = date != null ? roomGroupLabel(date) : null;
      if (group != null && group != currentGroup) {
        items.add(_MyRoomItem.group(group));
        currentGroup = group;
      }
      final prev = items.isNotEmpty ? items.last : null;
      items.add(_MyRoomItem.room(i, showDivider: prev?.roomIndex != null));
    }
    return items;
  }
}

class _MyRoomItem {
  final String? groupLabel;
  final int? roomIndex;
  final bool showDivider;

  const _MyRoomItem.group(String label)
      : groupLabel = label,
        roomIndex = null,
        showDivider = false;

  const _MyRoomItem.room(int index, {required this.showDivider})
      : groupLabel = null,
        roomIndex = index;
}

/// [예정 3 | 지난 12] — fill 트랙 위에 흰 면으로 선택 표시.
class _Segment extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  const _Segment({
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: AppRadius.rSm,
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm - 4),
                    border: i == index
                        ? Border.all(color: AppColors.line)
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: i == index
                        ? AppTextStyles.body2Bold
                        : AppTextStyles.body2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
