import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../models/room.dart';
import '../../../../widgets/design/age_badge.dart';
import '../../../../widgets/design/design_chip.dart';
import '../../../../widgets/design/glass_card.dart';

class RoomCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // 거리 — 참여 중인 방은 표시하지 않는다.
    final myPos = ref.watch(currentPositionProvider).valueOrNull;
    String? distanceText;
    if (room.latitude != null &&
        room.longitude != null &&
        !room.joined &&
        myPos != null) {
      distanceText = formatDistance(distanceKm(
        myPos.latitude,
        myPos.longitude,
        room.latitude!,
        room.longitude!,
      ));
    }
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
                      if (room.regionDong.trim().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.location_on_rounded,
                            size: 12, color: AppColors.ink500),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            room.regionDong,
                            style: AppTextStyles.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (distanceText != null) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.near_me_rounded,
                            size: 11, color: AppColors.primary),
                        const SizedBox(width: 2),
                        Text(
                          distanceText,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const Spacer(),
                      DesignChip(
                        label: '${room.currentMembers}/${room.maxMembers}명',
                        tone: room.isFull ? ChipTone.ink : ChipTone.primarySolid,
                        height: 22,
                        icon: Icons.people_rounded,
                      ),
                    ],
                  ),
                  if (room.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: room.tags
                          .take(4)
                          .map((tag) => _TagChip(label: tag))
                          .toList(),
                    ),
                  ],
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

/// 태그(#태그) 칩 — 태그별로 색이 다양하게 순환된다.
class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  // 태그 문자열 → 안정적인 (배경, 글자) 색 쌍.
  static const List<({Color bg, Color fg})> _palette = [
    (bg: Color(0xFFFFF1D6), fg: Color(0xFF9A6B12)), // yellow
    (bg: Color(0xFFDDF0FF), fg: Color(0xFF1F6FB2)), // sky
    (bg: Color(0xFFEDE3FB), fg: Color(0xFF5A3F99)), // lavender
    (bg: Color(0xFFFFE3DA), fg: Color(0xFFC0573E)), // coral
    (bg: Color(0xFFE6F4D4), fg: Color(0xFF55812A)), // lime
    (bg: Color(0xFFD7F1EA), fg: Color(0xFF1F6B4A)), // mint
  ];

  ({Color bg, Color fg}) _colorFor(String key) {
    if (key.isEmpty) return _palette.first;
    final hash = key.codeUnits.fold<int>(0, (a, b) => (a + b) & 0xffff);
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final c = _colorFor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '#$label',
        style: AppTextStyles.chip.copyWith(
          color: c.fg,
          fontSize: 11,
        ),
      ),
    );
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
