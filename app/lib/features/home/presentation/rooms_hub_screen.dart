import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../chat/providers/chat_provider.dart';
import '../../mypage/presentation/my_rooms_screen.dart';
import 'home_screen.dart';

/// '모임' 탭 허브 — [둘러보기](전체 모임 탐색)와 [내 모임](참여 모임 + 방별
/// 안읽음 카운트)을 한 탭 안에서 세그먼트로 전환한다. 별도 '채팅' 탭을 없애고
/// 내 모임/채팅 접근을 이 탭으로 합쳤다. 전체 안읽음 총합은 '내 모임' 세그먼트와
/// 하단 '모임' 탭 배지에 표시된다.
class RoomsHubScreen extends ConsumerStatefulWidget {
  const RoomsHubScreen({super.key});

  @override
  ConsumerState<RoomsHubScreen> createState() => _RoomsHubScreenState();
}

class _RoomsHubScreenState extends ConsumerState<RoomsHubScreen> {
  int _seg = 0; // 0: 둘러보기, 1: 내 모임

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(totalUnreadProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: _segmented(unread),
            ),
          ),
          Expanded(
            // 자식 화면들이 각자 SafeArea 를 갖고 있어 상단 인셋이 이중 적용되지
            // 않도록 여기서 top padding 을 제거한다.
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: IndexedStack(
                index: _seg,
                children: const [HomeScreen(), MyRoomsScreen()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmented(int unread) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary200, width: 0.8),
      ),
      child: Row(
        children: [
          _segTab('둘러보기', 0, 0),
          _segTab('내 모임', 1, unread),
        ],
      ),
    );
  }

  Widget _segTab(String label, int index, int badge) {
    final selected = _seg == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _seg = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? AppColors.primaryGradient : null,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style:
                    (selected ? AppTextStyles.body2Bold : AppTextStyles.body2)
                        .copyWith(
                            color: selected ? Colors.white : AppColors.ink500),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : AppColors.unreadBadge,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: AppTextStyles.chip.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.primary : Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
