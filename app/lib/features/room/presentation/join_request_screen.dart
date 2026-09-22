import '../../../widgets/top_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/room.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/avatar.dart';
import '../../../widgets/design/notebook.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading.dart';
import '../providers/room_detail_provider.dart';

class JoinRequestScreen extends ConsumerStatefulWidget {
  final String roomId;

  const JoinRequestScreen({super.key, required this.roomId});

  @override
  ConsumerState<JoinRequestScreen> createState() => _JoinRequestScreenState();
}

class _JoinRequestScreenState extends ConsumerState<JoinRequestScreen> {
  List<JoinRequest>? _requests;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final requests =
          await ref.read(roomRepositoryProvider).getJoinRequests(widget.roomId);
      setState(() {
        _requests = requests.where((r) => r.status == 'PENDING').toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '신청 목록을 불러올 수 없습니다';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRequest(String requestId, String action) async {
    try {
      await ref.read(roomRepositoryProvider).handleJoinRequest(
            widget.roomId,
            requestId,
            action,
          );

      final message = action == 'ACCEPT' ? '수락되었습니다' : '거절되었습니다';
      if (mounted) {
        showTopToast(context, message, backgroundColor: action == 'ACCEPT' ? AppColors.success : AppColors.textSecondary);
      }
      _loadRequests();
    } catch (e) {
      if (mounted) {
        showTopToast(context, '처리에 실패했습니다', backgroundColor: AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: const CustomAppBar(title: '참여 관리'),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoadingIndicator();
    }

    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: _loadRequests,
      );
    }

    if (_requests == null || _requests!.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline_rounded,
        title: '대기 중인 신청이 없습니다',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      color: AppColors.ink,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _requests!.length,
        itemBuilder: (context, index) {
          final request = _requests![index];
          return _RequestCard(
            key: Key('join-request-${request.user.id}'),
            request: request,
            onAccept: () => _handleRequest(request.id, 'ACCEPT'),
            onReject: () => _handleRequest(request.id, 'REJECT'),
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final JoinRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestCard({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final user = request.user;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            children: [
              InitialAvatar(
                label: user.nickname,
                size: 40,
                tone: InitialAvatar.toneFor(user.id),
                imageUrl: user.profileImageUrl,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.nickname, style: AppTextStyles.body1Bold),
                    if (user.children != null && user.children!.isNotEmpty)
                      Text(
                        user.children!
                            .map((c) =>
                                '${c.nickname} (${AppDateUtils.formatAgeMonths(c.ageMonths ?? 0)})')
                            .join(', '),
                        style: AppTextStyles.caption,
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onReject,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text('거절', style: AppTextStyles.body2),
                ),
              ),
              GestureDetector(
                key: Key('btn-accept-${request.user.id}'),
                onTap: onAccept,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    '수락',
                    style:
                        AppTextStyles.body2Bold.copyWith(color: AppColors.ink),
                  ),
                ),
              ),
            ],
          ),
        ),
        const DashedDivider(),
      ],
    );
  }
}
