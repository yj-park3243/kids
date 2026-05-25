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
    final ageColors = _ageColors(room.ageMonthMin);
    final accent = ageColors.last;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              // 위는 살짝 밝은 흰색, 아래는 약간 톤 다운된 오프화이트.
              // 미세한 그라데이션이 빛을 받는 둥근 표면처럼 보이게 한다.
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFFFFF), Color(0xFFF7F4F8)],
              ),
              border: Border.all(
                color: accent.withValues(alpha: 0.18),
                width: 1,
              ),
              // 입체감 — 위쪽 1px highlight + 중간 ambient + 깊은 drop.
              boxShadow: [
                // 상단 인너 하이라이트(가짜) — 살짝 위로 띄워주는 light cast.
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.9),
                  blurRadius: 0,
                  spreadRadius: -1,
                  offset: const Offset(0, -1),
                ),
                // 컬러 그림자 — 카드 색상 톤이 바닥에 살짝 번지게.
                BoxShadow(
                  color: accent.withValues(alpha: 0.18),
                  blurRadius: 22,
                  spreadRadius: -6,
                  offset: const Offset(0, 14),
                ),
                // 깊이감을 잡는 ambient shadow.
                BoxShadow(
                  color: const Color(0xFF1A1A2E).withValues(alpha: 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  // 좌측 컬러 액센트 띠 — 연령대 톤. 카드를 책처럼 보이게.
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            ageColors.first,
                            accent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 연령 블록 — 그림자 + 안쪽 highlight 로 floating chip 느낌.
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: ageColors,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              // 컬러 그림자 — 자기 색이 바닥에 번진다.
                              BoxShadow(
                                color: accent.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // 좌상단 사선 highlight — 광택.
                              Positioned(
                                top: 6,
                                left: 8,
                                right: 18,
                                child: Container(
                                  height: 18,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.35),
                                        Colors.white.withValues(alpha: 0),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${room.ageMonthMin}+',
                                    style: AppTextStyles.cardTitle.copyWith(
                                      color: Colors.white,
                                      fontSize: 18,
                                      shadows: [
                                        Shadow(
                                          color: accent.withValues(alpha: 0.45),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '개월',
                                    style: AppTextStyles.chip.copyWith(
                                      color: Colors.white.withValues(alpha: 0.95),
                                    ),
                                  ),
                                ],
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
                                    label:
                                        '${room.ageMonthMin}~${room.ageMonthMax}개월',
                                    solid: false,
                                  ),
                                  const SizedBox(width: 6),
                                  DesignChip(
                                    label: AppConstants
                                            .placeTypes[room.placeType] ??
                                        '기타',
                                    tone: ChipTone.lilac,
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
                                    AppDateUtils.formatDateTime(
                                        room.date, room.startTime),
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
                                    label:
                                        '${room.currentMembers}/${room.maxMembers}명',
                                    tone: room.isFull
                                        ? ChipTone.ink
                                        : ChipTone.primarySolid,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _ageColors(int age) {
    if (age < 6) return const [Color(0xFFFAD2DD), AppColors.primary];
    if (age < 12) return const [Color(0xFFF7A8BF), AppColors.primaryDark];
    if (age < 24) return const [Color(0xFFD5C7F2), AppColors.accentLavender];
    if (age < 36) return const [Color(0xFFC9B2EC), AppColors.secondaryDark];
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
    (bg: Color(0xFFFCE0E8), fg: Color(0xFFB23A60)), // pink
    (bg: Color(0xFFEDE3FB), fg: Color(0xFF5A3F99)), // lavender
    (bg: Color(0xFFFFE3DA), fg: Color(0xFFC0573E)), // coral
    (bg: Color(0xFFF8D2DD), fg: Color(0xFF9A2F52)), // deep pink
    (bg: Color(0xFFE6DAF9), fg: Color(0xFF6B3FA0)), // purple
    (bg: Color(0xFFFFD9CC), fg: Color(0xFFB5462E)), // deep coral
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
            color: AppColors.secondary,
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
