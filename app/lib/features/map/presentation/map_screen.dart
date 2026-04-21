import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/room.dart';
import '../../room/providers/room_detail_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapPin? _selectedPin;
  List<MapCluster> _clusters = [];
  List<MapPin> _pins = [];
  bool _isLoading = false;
  String _mode = 'CLUSTER';

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  Future<void> _loadMapData() async {
    setState(() => _isLoading = true);
    try {
      final data = await ref.read(roomRepositoryProvider).getMapRooms(
            swLat: 37.4,
            swLng: 126.8,
            neLat: 37.7,
            neLng: 127.2,
            zoomLevel: 12,
          );

      final mode = data['mode'] ?? 'CLUSTER';
      if (mode == 'CLUSTER') {
        _clusters = (data['clusters'] as List<dynamic>?)
                ?.map((e) => MapCluster.fromJson(e))
                .toList() ??
            [];
        _mode = 'CLUSTER';
      } else {
        _pins = (data['pins'] as List<dynamic>?)
                ?.map((e) => MapPin.fromJson(e))
                .toList() ??
            [];
        _mode = 'PIN';
      }
    } catch (e) {
      // Handle error silently - map will show empty
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Map placeholder (Naver Map would go here)
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 1.2,
                colors: [
                  Color(0xFFDDF5E6),
                  Color(0xFFE0EEFF),
                  Color(0xFFFFDCE8),
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_rounded,
                      size: 80, color: AppColors.textHint.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    '네이버 지도',
                    style: AppTextStyles.heading2.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Firebase 및 Naver Map 설정 후 활성화됩니다',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Show clusters or pins as list
                  if (_mode == 'CLUSTER' && _clusters.isNotEmpty) ...[
                    Text('클러스터 모드', style: AppTextStyles.captionBold),
                    const SizedBox(height: 8),
                    ..._clusters.take(5).map((c) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '${c.regionDong}: ${c.count}개 모임',
                            style: AppTextStyles.body2,
                          ),
                        )),
                  ],
                  if (_mode == 'PIN' && _pins.isNotEmpty) ...[
                    Text('핀 모드', style: AppTextStyles.captionBold),
                    const SizedBox(height: 8),
                    ..._pins.take(5).map((p) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            p.title,
                            style: AppTextStyles.body2,
                          ),
                        )),
                  ],
                ],
              ),
            ),
          ),

          // Top filter bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded,
                      color: AppColors.textHint, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '지도에서 모임 찾기',
                    style: AppTextStyles.body2
                        .copyWith(color: AppColors.textHint),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '필터',
                      style: AppTextStyles.captionBold
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading indicator
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),

          // Bottom card (when pin selected)
          if (_selectedPin != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: () =>
                    context.push('/rooms/${_selectedPin!.id}'),
                child: _PinCard(pin: _selectedPin!),
              ),
            ),
        ],
      ),
    );
  }
}

class _PinCard extends StatelessWidget {
  final MapPin pin;

  const _PinCard({required this.pin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(pin.title, style: AppTextStyles.body1Bold),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                AppDateUtils.formatDateTime(pin.date, pin.startTime),
                style: AppTextStyles.caption,
              ),
              const Spacer(),
              Text(
                '${pin.ageMonthMin}~${pin.ageMonthMax}개월',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.secondary),
              ),
              const SizedBox(width: 12),
              Text(
                '${pin.currentMembers}/${pin.maxMembers}명',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
