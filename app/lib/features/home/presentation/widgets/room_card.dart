import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../models/room.dart';
import '../../../../widgets/design/age_badge.dart';
import '../../../../widgets/design/design_chip.dart';
import '../../../../widgets/design/glass_card.dart';

class RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback? onTap;
  final VoidCallback? onOpenDetail;
  final VoidCallback? onOpenChat;

  const RoomCard({
    super.key,
    required this.room,
    this.onTap,
    this.onOpenDetail,
    this.onOpenChat,
  });

  bool get _hasActions => onOpenDetail != null || onOpenChat != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: GlassCard(
        onTap: onTap,
        radius: 22,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Age month color block
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _ageColors(room.ageMonthMin),
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${room.ageMonthMin}+',
                    style: AppTextStyles.cardTitle.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '개월',
                    style: AppTextStyles.chip.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      AgeBadge(
                        label: '${room.ageMonthMin}~${room.ageMonthMax}개월',
                        solid: false,
                      ),
                      const SizedBox(width: 6),
                      DesignChip(
                        label: AppConstants.placeTypes[room.placeType] ?? '기타',
                        tone: ChipTone.mint,
                        height: 22,
                      ),
                      const Spacer(),
                      _statusChip(room.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    room.title,
                    style: AppTextStyles.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 12, color: AppColors.ink500),
                      const SizedBox(width: 3),
                      Text(
                        AppDateUtils.formatDateTime(room.date, room.startTime),
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.location_on_rounded,
                          size: 12, color: AppColors.ink500),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          room.regionDong,
                          style: AppTextStyles.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DesignChip(
                        label: '${room.currentMembers}/${room.maxMembers}명',
                        tone: room.isFull ? ChipTone.ink : ChipTone.primarySolid,
                        height: 22,
                        icon: Icons.people_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_hasActions) ...[
              const SizedBox(width: 8),
              _CardActions(
                onOpenDetail: onOpenDetail,
                onOpenChat: onOpenChat,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Color> _ageColors(int age) {
    if (age < 6) return const [Color(0xFFFFE2A6), AppColors.accentYellow];
    if (age < 12) return const [Color(0xFF9DD9D0), AppColors.primary];
    if (age < 24) return const [Color(0xFFD5C7F2), AppColors.accentLavender];
    if (age < 36) return const [Color(0xFFD8EFB8), AppColors.accentLime];
    return const [Color(0xFFFFC0AC), AppColors.accentCoral];
  }

  Widget _statusChip(String status) {
    final label = AppConstants.roomStatus[status] ?? status;
    if (status == 'RECRUITING') {
      return DesignChip(label: label, tone: ChipTone.primaryGhost, height: 22);
    }
    return DesignChip(label: label, tone: ChipTone.outline, height: 22);
  }
}

class _CardActions extends StatelessWidget {
  final VoidCallback? onOpenDetail;
  final VoidCallback? onOpenChat;

  const _CardActions({this.onOpenDetail, this.onOpenChat});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (onOpenDetail != null)
          _ActionIcon(
            icon: Icons.home_rounded,
            tooltip: '방 상세',
            color: AppColors.primary,
            onTap: onOpenDetail!,
          ),
        if (onOpenDetail != null && onOpenChat != null)
          const SizedBox(height: 8),
        if (onOpenChat != null)
          _ActionIcon(
            icon: Icons.chat_bubble_rounded,
            tooltip: '채팅',
            color: AppColors.accentSky,
            onTap: onOpenChat!,
          ),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}
