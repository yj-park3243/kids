import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/room_photo.dart';
import '../../../models/user.dart';
import '../data/photo_repository.dart';
import '../providers/room_detail_provider.dart';

/// 좌우 스와이프 가능한 사진 상세. 호출자가 photoIds 리스트와 초기 index 를 전달.
class PhotoDetailScreen extends ConsumerStatefulWidget {
  const PhotoDetailScreen({
    super.key,
    required this.roomId,
    required this.photoIds,
    required this.initialIndex,
  });

  final String roomId;
  final List<String> photoIds;
  final int initialIndex;

  @override
  ConsumerState<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends ConsumerState<PhotoDetailScreen> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomDetailProvider(widget.roomId));
    final room = roomState.room;
    final allChildren = <Child>[];
    if (room != null) {
      for (final m in room.members ?? const []) {
        if (m.children != null) allChildren.addAll(m.children!);
      }
    }
    final seen = <String>{};
    final uniqueChildren = allChildren.where((c) => seen.add(c.id)).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('사진'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photoIds.length,
        itemBuilder: (_, i) => _PhotoPage(
          key: ValueKey(widget.photoIds[i]),
          photoId: widget.photoIds[i],
          roomChildren: uniqueChildren,
        ),
      ),
    );
  }
}

class _PhotoPage extends ConsumerStatefulWidget {
  const _PhotoPage({super.key, required this.photoId, required this.roomChildren});

  final String photoId;
  final List<Child> roomChildren;

  @override
  ConsumerState<_PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends ConsumerState<_PhotoPage> {
  RoomPhoto? _photo;
  List<PhotoComment> _comments = [];
  bool _loading = true;
  final _commentController = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(photoRepositoryProvider);
      final results = await Future.wait([
        repo.getOne(widget.photoId),
        repo.listComments(widget.photoId),
      ]);
      if (!mounted) return;
      setState(() {
        _photo = results[0] as RoomPhoto;
        _comments = results[1] as List<PhotoComment>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleTag(String childId) async {
    final p = _photo;
    if (p == null) return;
    final next = List<String>.from(p.childIds);
    if (next.contains(childId)) {
      next.remove(childId);
    } else {
      next.add(childId);
    }
    setState(() => _photo = p.copyWith(childIds: next));
    try {
      await ref.read(photoRepositoryProvider).updateTags(p.id, next);
    } catch (_) {
      // 실패 시 복구
      if (mounted) setState(() => _photo = p);
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final c = await ref
          .read(photoRepositoryProvider)
          .addComment(widget.photoId, text);
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, c];
        _commentController.clear();
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _photo == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final p = _photo!;
    return ListView(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context, rootNavigator: true).push(
            PageRouteBuilder(
              opaque: false,
              barrierColor: Colors.black,
              pageBuilder: (_, __, ___) =>
                  _PhotoFullscreen(url: p.url, heroTag: 'photo-${p.id}'),
            ),
          ),
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              color: Colors.black,
              child: Hero(
                tag: 'photo-${p.id}',
                child: Image.network(p.url, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen, AppSpacing.lg, AppSpacing.screen, AppSpacing.xs),
          child: Text(
            '${p.uploaderNickname} · ${DateFormat('M월 d일 HH:mm').format(p.createdAt.toLocal())}',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ),
        _ChildTagsEditor(
          children: widget.roomChildren,
          selected: p.childIds,
          onToggle: _toggleTag,
        ),
        AppSpacing.gapLgV,
        const Divider(height: 1, indent: AppSpacing.screen, endIndent: AppSpacing.screen),
        AppSpacing.gapLgV,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
          child: Text('댓글 ${_comments.length}', style: AppTextStyles.sectionHead),
        ),
        AppSpacing.gapSm,
        if (_comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screen, vertical: AppSpacing.md),
            child: Text(
              '아직 댓글이 없어요',
              style: AppTextStyles.body2.copyWith(color: AppColors.textHint),
            ),
          )
        else
          ..._comments.map((c) => Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screen, vertical: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.userNickname, style: AppTextStyles.body2Bold),
                          AppSpacing.gapXxs,
                          Text(
                            c.content,
                            style: AppTextStyles.body2.copyWith(height: 1.5),
                          ),
                          AppSpacing.gapXxs,
                          Text(
                            DateFormat('M월 d일 HH:mm').format(c.createdAt.toLocal()),
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textHint),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        const SizedBox(height: 100),
      ],
    )
        .let((listView) => Stack(children: [
              Positioned.fill(child: listView),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Container(
                    color: AppColors.surface,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: const InputDecoration(
                              hintText: '댓글을 입력하세요',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onSubmitted: (_) => _addComment(),
                          ),
                        ),
                        IconButton(
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send_rounded, color: AppColors.primary),
                          onPressed: _sending ? null : _addComment,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ]));
  }
}

/// 펼침/접힘 영속. 선택된 칩이 앞쪽으로 정렬.
class _ChildTagsEditor extends StatefulWidget {
  const _ChildTagsEditor({
    required this.children,
    required this.selected,
    required this.onToggle,
  });

  final List<Child> children;
  final List<String> selected;
  final void Function(String childId) onToggle;

  @override
  State<_ChildTagsEditor> createState() => _ChildTagsEditorState();
}

class _ChildTagsEditorState extends State<_ChildTagsEditor> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'photo_tags_expanded';
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await _storage.read(key: _key);
    if (!mounted) return;
    setState(() => _expanded = v == 'true');
  }

  Future<void> _toggleExpand() async {
    setState(() => _expanded = !_expanded);
    await _storage.write(key: _key, value: _expanded ? 'true' : 'false');
  }

  @override
  Widget build(BuildContext context) {
    final selectedSet = widget.selected.toSet();
    final sorted = [
      ...widget.children.where((c) => selectedSet.contains(c.id)),
      ...widget.children.where((c) => !selectedSet.contains(c.id)),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _toggleExpand,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Text('아이 태그 (${widget.selected.length})',
                    style: AppTextStyles.sectionHead),
                const Spacer(),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            AppSpacing.gapMdV,
            if (sorted.isEmpty)
              Text(
                '방 멤버의 아이 정보가 없어요',
                style: AppTextStyles.body2.copyWith(color: AppColors.textHint),
              )
            else
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: sorted.map((c) {
                  final picked = selectedSet.contains(c.id);
                  return GestureDetector(
                    onTap: () => widget.onToggle(c.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: picked
                            ? AppColors.primary
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        c.nickname,
                        style: AppTextStyles.body2Bold.copyWith(
                          color: picked ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ],
      ),
    );
  }
}

extension _LetExt<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

/// 사진 전체화면 — 핀치/더블탭 줌, 어디 탭하든 닫힘.
class _PhotoFullscreen extends StatelessWidget {
  const _PhotoFullscreen({required this.url, required this.heroTag});
  final String url;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Hero(
              tag: heroTag,
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
