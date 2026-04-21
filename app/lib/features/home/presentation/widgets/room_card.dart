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

  const RoomCard({super.key, required this.room, this.onTap});

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
                        tone: room.isFull ? ChipTone.ink : ChipTone.pinkSolid,
                        height: 22,
                        icon: Icons.people_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _ageColors(int age) {
    if (age < 6) return const [Color(0xFFFFCABD), Color(0xFFFF8E7A)];
    if (age < 12) return const [Color(0xFFFF8EB5), Color(0xFFE84C88)];
    if (age < 24) return const [Color(0xFFD5C0F5), Color(0xFFB08AE8)];
    if (age < 36) return const [Color(0xFFB9EAD2), Color(0xFF7DCFA4)];
    return const [Color(0xFFFFE0CC), Color(0xFFFFAD9A)];
  }

  Widget _statusChip(String status) {
    final label = AppConstants.roomStatus[status] ?? status;
    if (status == 'RECRUITING') {
      return DesignChip(label: label, tone: ChipTone.pinkGhost, height: 22);
    }
    return DesignChip(label: label, tone: ChipTone.outline, height: 22);
  }
}
