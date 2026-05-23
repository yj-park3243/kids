import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/room.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/accent_blobs.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading.dart';
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
  final _searchController = TextEditingController();

  List<Room>? _upcomingRooms;
  List<Room>? _pastRooms;
  String? _error;

  // 검색조건 패널 상태.
  bool _searchExpanded = false;
  String _query = '';
  String _typeFilter = 'ALL'; // ALL | HOSTING | JOINED
  String? _placeFilter; // null = 장소 전체

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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    final index = _tabController.index;
    try {
      final status = index == 0 ? 'UPCOMING' : 'PAST';
      final rooms = await ref
          .read(roomRepositoryProvider)
          .getMyRooms(type: _typeFilter, status: status);
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

  void _toggleSearch() {
    setState(() => _searchExpanded = !_searchExpanded);
  }

  // 방 종류(type)는 백엔드 재조회가 필요하므로 두 탭 캐시를 모두
  // 비우고 현재 탭부터 다시 불러온다.
  void _setTypeFilter(String type) {
    if (_typeFilter == type) return;
    setState(() {
      _typeFilter = type;
      _upcomingRooms = null;
      _pastRooms = null;
    });
    _loadRooms();
  }

  /// 제목·장소 조건을 클라이언트 측에서 적용. null이면 아직 미로딩.
  List<Room>? _applyFilters(List<Room>? rooms) {
    if (rooms == null) return null;
    final q = _query.trim().toLowerCase();
    return rooms.where((r) {
      if (q.isNotEmpty && !r.title.toLowerCase().contains(q)) return false;
      if (_placeFilter != null && r.placeType != _placeFilter) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        showBack: false,
        actions: [
          IconButton(
            icon: Icon(
              _searchExpanded ? Icons.close_rounded : Icons.search_rounded,
              color: AppColors.ink900,
            ),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: AccentBlobsBackground(
        child: SafeArea(
          child: Column(
            children: [
              if (_searchExpanded) _buildSearchPanel(),
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.primary200, width: 0.8),
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
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRoomList(_applyFilters(_upcomingRooms)),
                    _buildRoomList(_applyFilters(_pastRooms)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 돋보기로 펼치는 검색조건 패널 — 탭바 위에 표시된다.
  Widget _buildSearchPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary200, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 방 제목 검색
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: '방 제목 검색',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: AppColors.primary, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 방 종류
          Text(
            '방 종류',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.ink500,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                label: '전체',
                color: AppColors.primary,
                selected: _typeFilter == 'ALL',
                onTap: () => _setTypeFilter('ALL'),
              ),
              _chip(
                label: '내가 만든 방',
                color: AppColors.primary,
                selected: _typeFilter == 'HOSTING',
                onTap: () => _setTypeFilter('HOSTING'),
              ),
              _chip(
                label: '참여한 방',
                color: AppColors.primary,
                selected: _typeFilter == 'JOINED',
                onTap: () => _setTypeFilter('JOINED'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 장소
          Text(
            '장소',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.ink500,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                label: '장소 전체',
                color: AppColors.placeAll,
                selected: _placeFilter == null,
                onTap: () => setState(() => _placeFilter = null),
              ),
              ...AppConstants.placeTypes.entries.map(
                (e) => _chip(
                  label: e.value,
                  color: AppColors.placeColorFor(e.key),
                  selected: _placeFilter == e.key,
                  onTap: () => setState(() => _placeFilter = e.key),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : color.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.chip.copyWith(
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.w700,
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

    return RefreshIndicator(
      onRefresh: _loadRooms,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final room = rooms[index];
          return RoomCard(
            room: room,
            onOpenDetail: () => context.push('/rooms/${room.id}'),
            onOpenChat: room.chatRoomId != null
                ? () => context.push('/chat/${room.chatRoomId}')
                : null,
          );
        },
      ),
    );
  }
}
