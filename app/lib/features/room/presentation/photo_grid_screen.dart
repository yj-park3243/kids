import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/room_photo.dart';
import '../../../models/user.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/design_chip.dart';
import '../data/photo_repository.dart';
import '../providers/room_detail_provider.dart';

/// 방 사진첩 — 3열 그리드 + 아이 태그 필터.
class PhotoGridScreen extends ConsumerStatefulWidget {
  const PhotoGridScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<PhotoGridScreen> createState() => _PhotoGridScreenState();
}

class _PhotoGridScreenState extends ConsumerState<PhotoGridScreen> {
  String? _filterChildId;
  bool _loading = true;
  List<RoomPhoto> _photos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ref
          .read(photoRepositoryProvider)
          .list(widget.roomId, childId: _filterChildId);
      if (!mounted) return;
      setState(() {
        _photos = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openUpload() async {
    final added =
        await context.push<bool>('/rooms/${widget.roomId}/photos/upload');
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    // 방의 멤버 children 모음 (호스트 + 멤버). 룸 상세 provider 에서 가져옴.
    final roomState = ref.watch(roomDetailProvider(widget.roomId));
    final room = roomState.room;
    final children = <Child>[];
    if (room != null) {
      for (final m in room.members ?? const []) {
        if (m.children != null) children.addAll(m.children!);
      }
    }
    // dedupe by id (호스트와 멤버 중복 가능성)
    final seen = <String>{};
    final uniqueChildren = children.where((c) => seen.add(c.id)).toList();

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: CustomAppBar(
        title: '사진첩',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: GestureDetector(
                onTap: _openUpload,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.hi,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '＋ 올리기',
                    style: AppTextStyles.buttonSmall
                        .copyWith(fontSize: 13, color: AppColors.ink),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (uniqueChildren.isNotEmpty)
              SizedBox(
                // FilterChipButton 34 + 위아래 여백 12*2 = 58.
                height: 58,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: AppSpacing.sm),
                  children: [
                    _FilterChip(
                      label: '전체',
                      selected: _filterChildId == null,
                      onTap: () {
                        setState(() => _filterChildId = null);
                        _load();
                      },
                    ),
                    ...uniqueChildren.map((c) => _FilterChip(
                          label: c.nickname,
                          selected: _filterChildId == c.id,
                          onTap: () {
                            setState(() => _filterChildId = c.id);
                            _load();
                          },
                        )),
                  ],
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.ink))
                  : _photos.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: Text(
                              '아직 올린 사진이 없어요.\n오른쪽 위 ‘＋ 올리기’로 첫 사진을 올려보세요.',
                              style: AppTextStyles.body2.copyWith(height: 1.6),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.ink,
                          onRefresh: _load,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(2),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 2,
                              mainAxisSpacing: 2,
                            ),
                            itemCount: _photos.length,
                            itemBuilder: (_, i) {
                              final p = _photos[i];
                              return GestureDetector(
                                onTap: () async {
                                  await context.push(
                                    '/rooms/${widget.roomId}/photos/${p.id}',
                                    extra: {
                                      'photoIds': _photos.map((e) => e.id).toList(),
                                      'initialIndex': i,
                                    },
                                  );
                                  _load();
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(p.url, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                                color: AppColors.fill,
                                                child: const Icon(
                                                    Icons.broken_image_rounded,
                                                    color: AppColors.ink3),
                                              )),
                                      if (p.commentCount > 0)
                                        Positioned(
                                          right: 4,
                                          bottom: 4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.ink
                                                  .withValues(alpha: 0.6),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                    Icons.chat_bubble_rounded,
                                                    color: Colors.white,
                                                    size: 10),
                                                const SizedBox(width: 3),
                                                Text(
                                                  '${p.commentCount}',
                                                  style: AppTextStyles.badge
                                                      .copyWith(fontSize: 10),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChipButton(
        label: label,
        selected: selected,
        onTap: onTap,
      ),
    );
  }
}
