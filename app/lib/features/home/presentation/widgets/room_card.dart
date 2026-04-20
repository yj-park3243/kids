import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../models/room.dart';

class RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback? onTap;

  const RoomCard({super.key, required this.room, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
            // Top row: Place type badge + status
            Row(
              children: [
                _PlaceTypeBadge(placeType: room.placeType),
                const Spacer(),
                _StatusBadge(status: room.status),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              room.title,
              style: AppTextStyles.body1Bold,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Date & Location
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  AppDateUtils.formatDateTime(room.date, room.startTime),
                  style: AppTextStyles.caption,
                ),
                const SizedBox(width: 12),
                Icon(Icons.location_on_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(room.regionDong, style: AppTextStyles.caption),
              ],
            ),
            const SizedBox(height: 8),

            // Age & Members & Cost
            Row(
              children: [
                Icon(Icons.child_care_rounded,
                    size: 14, color: AppColors.secondary),
                const SizedBox(width: 4),
                Text(
                  '${room.ageMonthMin}~${room.ageMonthMax}개월',
                  style: AppTextStyles.caption.copyWith(color: AppColors.secondary),
                ),
                const SizedBox(width: 12),
                Icon(Icons.people_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${room.currentMembers}/${room.maxMembers}명',
                  style: AppTextStyles.caption.copyWith(
                    color: room.isFull ? AppColors.error : AppColors.textSecondary,
                    fontWeight: room.isFull ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  AppDateUtils.formatCostDisplay(room.cost),
                  style: AppTextStyles.caption.copyWith(
                    color: room.isFree ? AppColors.success : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            // Tags
            if (room.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: room.tags
                    .take(3)
                    .map((tag) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#$tag',
                            style: AppTextStyles.tag,
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlaceTypeBadge extends StatelessWidget {
  final String placeType;

  const _PlaceTypeBadge({required this.placeType});

  @override
  Widget build(BuildContext context) {
    final label = AppConstants.placeTypes[placeType] ?? '기타';
    final iconCode = AppConstants.placeTypeIcons[placeType] ?? 0xe55f;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(IconData(iconCode, fontFamily: 'MaterialIcons'),
              size: 14, color: AppColors.secondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = AppConstants.roomStatus[status] ?? status;
    final color = status == 'RECRUITING'
        ? AppColors.recruiting
        : status == 'CANCELLED'
            ? AppColors.cancelled
            : AppColors.closed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
