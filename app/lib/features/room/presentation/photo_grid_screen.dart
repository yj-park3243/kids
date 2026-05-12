import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/room_photo.dart';
import '../../../models/user.dart';
import '../../../widgets/app_bar.dart';
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
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: '사진첩',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo_rounded),
            onPressed: () async {
              final added = await context
                  .push<bool>('/rooms/${widget.roomId}/photos/upload');
              if (added == true) _load();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (uniqueChildren.isNotEmpty)
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screen, vertical: AppSpacing.sm),
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
                  ? const Center(child: CircularProgressIndicator())
                  : _photos.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: Text(
                              '아직 올린 사진이 없어요.\n오른쪽 위 + 버튼으로 첫 사진을 올려보세요.',
                              style: AppTextStyles.body2.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.6,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: AppSpacing.xs,
                              mainAxisSpacing: AppSpacing.xs,
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
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(p.url, fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                              color: AppColors.surfaceVariant,
                                              child: const Icon(Icons.broken_image_rounded,
                                                  color: AppColors.textHint),
                                            )),
                                    if (p.commentCount > 0)
                                      Positioned(
                                        right: 4,
                                        bottom: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.55),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.chat_bubble_rounded,
                                                  color: Colors.white, size: 10),
                                              const SizedBox(width: 2),
                                              Text(
                                                '${p.commentCount}',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
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
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.body2Bold.copyWith(
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
