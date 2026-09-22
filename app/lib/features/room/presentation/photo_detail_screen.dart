import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_error.dart';
import '../../../models/room_photo.dart';
import '../../../models/user.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/design/avatar.dart';
import '../../../widgets/design/design_chip.dart';
import '../../../widgets/design/notebook.dart';
import '../../../widgets/top_toast.dart';
import '../../auth/providers/auth_provider.dart';
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
      backgroundColor: AppColors.paper,
      appBar: const CustomAppBar(title: '사진'),
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
  bool _loadError = false;
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
    setState(() {
      _loading = true;
      _loadError = false;
    });
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
      // 로드 실패 시 _photo가 null로 남아 무한 스피너에 갇히던 것을
      // 에러 상태로 분기해 재시도할 수 있게 한다.
      setState(() {
        _loading = false;
        _loadError = true;
      });
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
    } catch (e) {
      // 실패 시 복구
      if (!mounted) return;
      setState(() => _photo = p);
      showTopToast(context, apiErrorMessage(e, fallback: '태그를 저장하지 못했어요'),
          backgroundColor: AppColors.error);
    }
  }

  Future<void> _deletePhoto(RoomPhoto p) async {
    var ok = false;
    await AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: '사진 삭제',
      desc: '이 사진을 삭제할까요?\n댓글과 태그도 함께 사라져요.',
      btnCancelText: '취소',
      btnOkText: '삭제',
      btnOkColor: AppColors.error,
      btnCancelOnPress: () {},
      btnOkOnPress: () => ok = true,
    ).show();
    if (!ok || !mounted) return;
    try {
      await ref.read(photoRepositoryProvider).delete(p.id);
      if (!mounted) return;
      showTopToast(context, '사진을 삭제했어요', backgroundColor: AppColors.success);
      // 목록 화면이 복귀 시 다시 불러온다.
      context.pop();
    } catch (e) {
      if (!mounted) return;
      showTopToast(context, apiErrorMessage(e, fallback: '사진을 삭제하지 못했어요'),
          backgroundColor: AppColors.error);
    }
  }

  Future<void> _addComment() async {
    FocusScope.of(context).unfocus();
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
    } catch (e) {
      if (!mounted) return;
      showTopToast(context, apiErrorMessage(e, fallback: '댓글을 남기지 못했어요'),
          backgroundColor: AppColors.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.ink));
    }
    if (_photo == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined,
                size: 56, color: AppColors.ink3),
            const SizedBox(height: 12),
            Text(
              _loadError ? '사진을 불러오지 못했어요' : '사진을 찾을 수 없어요',
              style: AppTextStyles.body1.copyWith(color: AppColors.ink2),
            ),
            const SizedBox(height: 16),
            if (_loadError)
              TextButton(
                onPressed: _load,
                style: TextButton.styleFrom(foregroundColor: AppColors.ink),
                child: const Text('다시 시도'),
              ),
          ],
        ),
      );
    }
    final p = _photo!;
    final mine = p.uploaderId != null &&
        p.uploaderId == ref.watch(authProvider).user?.id;

    return Stack(
      children: [
        Positioned.fill(
          child: ListView(
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
                    color: AppColors.ink,
                    child: Hero(
                      tag: 'photo-${p.id}',
                      child: Image.network(p.url, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
              // 업로더 행 — 아바타 + 이름 + 시간, 본인이면 삭제.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Row(
                  children: [
                    InitialAvatar(
                      label: p.uploaderNickname,
                      size: 32,
                      tone: InitialAvatar.toneFor(
                          p.uploaderId ?? p.uploaderNickname),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(p.uploaderNickname,
                              style: AppTextStyles.body2Bold),
                          Text(
                            DateFormat('M월 d일 HH:mm')
                                .format(p.createdAt.toLocal()),
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    // 업로더 본인만 삭제 가능 (서버도 같은 규칙).
                    if (mine)
                      GestureDetector(
                        onTap: () => _deletePhoto(p),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.delete_outline_rounded,
                              size: 20, color: AppColors.ink3),
                        ),
                      ),
                  ],
                ),
              ),
              _ChildTagsEditor(
                children: widget.roomChildren,
                selected: p.childIds,
                onToggle: _toggleTag,
              ),
              const DashedDivider(
                  margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8)),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Text('댓글 ${_comments.length}',
                    style: AppTextStyles.sectionHead),
              ),
              AppSpacing.gapSm,
              if (_comments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: AppSpacing.md),
                  child: Text(
                    '아직 댓글이 없어요',
                    style: AppTextStyles.body2.copyWith(color: AppColors.ink3),
                  ),
                )
              else
                for (var i = 0; i < _comments.length; i++) ...[
                  if (i > 0)
                    const DashedDivider(
                        margin: EdgeInsets.symmetric(horizontal: 20)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_comments[i].userNickname,
                            style: AppTextStyles.body2Bold),
                        AppSpacing.gapXxs,
                        Text(
                          _comments[i].content,
                          style: AppTextStyles.body2
                              .copyWith(color: AppColors.ink, height: 1.5),
                        ),
                        AppSpacing.gapXxs,
                        Text(
                          DateFormat('M월 d일 HH:mm')
                              .format(_comments[i].createdAt.toLocal()),
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              const SizedBox(height: 100),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            padding: EdgeInsets.fromLTRB(
                12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.fill,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: TextField(
                      controller: _commentController,
                      style: AppTextStyles.body1,
                      cursorColor: AppColors.ink,
                      // 서버 제한(500자)과 동일 — 넘기면 400 이 나고 아무 반응이 없었다.
                      maxLength: 500,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                          currentLength > 400
                              ? Text('$currentLength/$maxLength',
                                  style: AppTextStyles.caption)
                              : null,
                      decoration: InputDecoration(
                        hintText: '댓글을 입력하세요',
                        hintStyle: AppTextStyles.body1
                            .copyWith(color: AppColors.ink3),
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onSubmitted: (_) => _addComment(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _addComment,
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _sending ? AppColors.fill : AppColors.ink,
                      shape: BoxShape.circle,
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.ink3),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 17),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 펼침/접힘 영속. 진입 시 태그된 아이를 앞으로 정렬(이후 선택해도 순서 고정).
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
  // 진입 시점 기준 정렬(태그된 아이 우선). 선택 토글해도 재정렬하지 않는다.
  late final List<Child> _ordered;

  @override
  void initState() {
    super.initState();
    _load();
    final selectedSet = widget.selected.toSet();
    _ordered = [
      ...widget.children.where((c) => selectedSet.contains(c.id)),
      ...widget.children.where((c) => !selectedSet.contains(c.id)),
    ];
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
    final sorted = _ordered;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, AppSpacing.md, 20, AppSpacing.md),
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
                  color: AppColors.ink3,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            AppSpacing.gapMdV,
            if (sorted.isEmpty)
              Text(
                '방 멤버의 아이 정보가 없어요',
                style: AppTextStyles.body2.copyWith(color: AppColors.ink3),
              )
            else
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: sorted.map((c) {
                  final picked = selectedSet.contains(c.id);
                  return Pill(
                    label: c.nickname,
                    tone: picked ? PillTone.sky : PillTone.line,
                    height: 32,
                    onTap: () => widget.onToggle(c.id),
                  );
                }).toList(),
              ),
          ],
        ],
      ),
    );
  }
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
