import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/growth_guide.dart';
import '../data/growth_guide_repository.dart';

final growthGuideRepositoryProvider = Provider<GrowthGuideRepository>((ref) {
  return GrowthGuideRepository();
});

// 전체 목록 — 한 번 불러와 캐시.
final growthGuideListProvider =
    FutureProvider<List<GrowthGuide>>((ref) async {
  final repo = ref.watch(growthGuideRepositoryProvider);
  return repo.getGuides();
});

// 월령 단건 — ageMonth 별로 캐시.
final growthGuideDetailProvider =
    FutureProvider.family<GrowthGuide, int>((ref, ageMonth) async {
  final repo = ref.watch(growthGuideRepositoryProvider);
  return repo.getGuide(ageMonth);
});
