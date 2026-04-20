import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/room.dart';
import '../../../widgets/app_bar.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: action == 'ACCEPT' ? AppColors.success : AppColors.textSecondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      _loadRequests();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('처리에 실패했습니다'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: '참여 관리'),
      body: _buildBody(),
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
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _requests!.length,
        itemBuilder: (context, index) {
          final request = _requests![index];
          return _RequestCard(
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
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final user = request.user;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.surfaceVariant,
                backgroundImage: user.profileImageUrl != null
                    ? NetworkImage(user.profileImageUrl!)
                    : null,
                child: user.profileImageUrl == null
                    ? const Icon(Icons.person_rounded,
                        color: AppColors.textHint, size: 24)
                    : null,
              ),
              const SizedBox(width: 12),
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
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('거절'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('수락'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
