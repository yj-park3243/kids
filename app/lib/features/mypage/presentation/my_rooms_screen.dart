import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/room.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/pink_blobs.dart';
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
  List<Room>? _upcomingRooms;
  List<Room>? _pastRooms;
  bool _isLoading = true;
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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final status = _tabController.index == 0 ? 'UPCOMING' : 'PAST';
      final rooms = await ref
          .read(roomRepositoryProvider)
          .getMyRooms(status: status);

      setState(() {
        if (_tabController.index == 0) {
          _upcomingRooms = rooms;
        } else {
          _pastRooms = rooms;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '모임 목록을 불러올 수 없습니다';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: '내 모임'),
      extendBodyBehindAppBar: true,
      body: PinkBlobsBackground(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.pink200, width: 0.8),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: AppColors.pinkGradient,
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
    if (_isLoading) return const ShimmerList();

    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _loadRooms);
    }

    if (rooms == null || rooms.isEmpty) {
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
            onTap: () => context.push('/rooms/${room.id}'),
          );
        },
      ),
    );
  }
}
