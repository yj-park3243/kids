import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/app_bar.dart';
import '../data/photo_repository.dart';

/// 앱 안에서 디바이스 사진 라이브러리를 직접 그리드로 보여주고 다중 선택.
/// (iOS 시스템 picker 대신 photo_manager 사용)
class PhotoUploadScreen extends ConsumerStatefulWidget {
  const PhotoUploadScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends ConsumerState<PhotoUploadScreen> {
  bool _permissionDenied = false;
  bool _loading = true;
  AssetPathEntity? _album;
  final List<AssetEntity> _assets = [];
  final List<AssetEntity> _selected = []; // 선택 순서대로 번호 매김

  static const int _pageSize = 80;
  int _nextPage = 0;
  bool _hasMore = true;
  bool _loadingMore = false;

  // 업로드 진행 상태
  bool _uploading = false;
  int _uploadDone = 0;
  int _uploadTotal = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.isAuth && !perm.hasAccess) {
      if (!mounted) return;
      setState(() {
        _permissionDenied = true;
        _loading = false;
      });
      return;
    }

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true, // "최근 항목" 같은 전체 앨범
    );
    if (paths.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    _album = paths.first;
    await _loadNext();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadNext() async {
    if (_loadingMore || !_hasMore || _album == null) return;
    _loadingMore = true;
    final page = await _album!.getAssetListPaged(page: _nextPage, size: _pageSize);
    _assets.addAll(page);
    _nextPage++;
    if (page.length < _pageSize) _hasMore = false;
    _loadingMore = false;
    if (mounted) setState(() {});
  }

  void _toggle(AssetEntity a) {
    setState(() {
      if (_selected.contains(a)) {
        _selected.remove(a);
      } else {
        _selected.add(a);
      }
    });
  }

  Future<void> _upload() async {
    if (_selected.isEmpty || _uploading) return;
    setState(() {
      _uploading = true;
      _uploadDone = 0;
      _uploadTotal = _selected.length;
    });

    final repo = ref.read(photoRepositoryProvider);
    var ok = 0;
    for (final a in _selected) {
      try {
        final file = await a.file;
        if (file != null) {
          await repo.upload(widget.roomId, file.path);
          ok++;
        }
      } catch (_) {
        // 한 장 실패해도 나머지 계속
      }
      if (!mounted) return;
      setState(() => _uploadDone++);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$ok 장 업로드 완료${ok != _selected.length ? ' (${_selected.length - ok}장 실패)' : ''}'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: '사진 선택',
        actions: [
          TextButton(
            onPressed: _selected.isEmpty || _uploading ? null : _upload,
            child: Text(
              _uploading ? '$_uploadDone/$_uploadTotal' : '전송 ${_selected.isEmpty ? '' : '(${_selected.length})'}',
              style: AppTextStyles.body2Bold.copyWith(
                color: _selected.isEmpty
                    ? AppColors.textHint
                    : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_permissionDenied) {
      return _PermissionBlocker(
        onOpenSettings: () => PhotoManager.openSetting(),
      );
    }
    if (_assets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            '사진이 없어요',
            style: AppTextStyles.body2
                .copyWith(color: AppColors.textSecondary, height: 1.6),
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          _loadNext();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: AppSpacing.xxs,
          mainAxisSpacing: AppSpacing.xxs,
        ),
        itemCount: _assets.length,
        itemBuilder: (_, i) {
          final a = _assets[i];
          final pickedIndex = _selected.indexOf(a);
          final picked = pickedIndex >= 0;
          return GestureDetector(
            onTap: () => _toggle(a),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _AssetThumb(asset: a),
                if (picked)
                  Container(
                    color: AppColors.primary.withValues(alpha: 0.18),
                  ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: picked ? AppColors.primary : Colors.black26,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: picked
                        ? Text(
                            '${pickedIndex + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AssetThumb extends StatefulWidget {
  const _AssetThumb({required this.asset});

  final AssetEntity asset;

  @override
  State<_AssetThumb> createState() => _AssetThumbState();
}

class _AssetThumbState extends State<_AssetThumb> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize.square(300),
    );
    if (!mounted) return;
    setState(() => _bytes = b);
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) {
      return Container(color: AppColors.surfaceVariant);
    }
    return Image.memory(_bytes!, fit: BoxFit.cover);
  }
}

class _PermissionBlocker extends StatelessWidget {
  const _PermissionBlocker({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined,
                size: 56, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              '사진첩 접근 권한이 필요해요',
              style: AppTextStyles.body1Bold,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '설정에서 사진 접근을 허용해주세요.',
              style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onOpenSettings,
              child: const Text('설정 열기'),
            ),
          ],
        ),
      ),
    );
  }
}
