import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_shadows.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/room.dart';
import '../../../widgets/design/avatar.dart';
import '../../../widgets/design/design_chip.dart';
import '../../../widgets/design/notebook.dart';
import '../../../widgets/design/primary_button.dart';
import '../../room/providers/room_detail_provider.dart';

/// 지도 핀 시트 — 세 단계로 끌어 올린다.
///
/// - **미리보기(peek)** 핀을 탭하면 스프링으로 올라온다. 제목 · 한 줄 메타 · pill 2개 · CTA.
/// - **펼침(half)** 위로 끌면 방 소개 · 참여자 · 약속이 이어진다(상세를 그 자리에서 불러온다).
/// - **끝까지(full)** 더 끌어 올리면 방 상세 화면으로 넘어간다. 아래로 끌어 내리면 닫힌다.
///
/// 닫힘·전환은 [onClose] / [onOpenDetail] 콜백으로 부모(state)가 처리한다 —
/// platform view 위의 showModalBottomSheet 가 가끔 라우트를 못 띄우는 문제 때문에
/// 시트는 build 안에서 그린다.
class PinSheet extends ConsumerStatefulWidget {
  final MapPin pin;
  final String? distanceText;
  final VoidCallback onClose;
  final VoidCallback onOpenDetail;
  /// 시트 높이 비율이 바뀔 때 — 부모가 FAB 위치·카메라를 맞춘다.
  final ValueChanged<double>? onExtentChanged;

  const PinSheet({
    super.key,
    required this.pin,
    required this.distanceText,
    required this.onClose,
    required this.onOpenDetail,
    this.onExtentChanged,
  });

  /// 미리보기 높이(화면 비율). 하단 탭바(≈90) + 내용(≈250).
  static const double peek = 0.40;
  static const double half = 0.72;
  static const double full = 0.95;

  @override
  ConsumerState<PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends ConsumerState<PinSheet>
    with SingleTickerProviderStateMixin {
  final _sheet = DraggableScrollableController();
  late final AnimationController _enter;
  bool _detailRequested = false;
  bool _openingDetail = false;
  double _extent = PinSheet.peek;

  @override
  void initState() {
    super.initState();
    // 진입 — 아래에서 올라오는 스프링. DraggableScrollableSheet 자체는 진입 애니메이션이
    // 없어 SlideTransition 으로 감싼다.
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _sheet.addListener(_onSheetMoved);
  }

  @override
  void didUpdateWidget(covariant PinSheet old) {
    super.didUpdateWidget(old);
    if (old.pin.id != widget.pin.id) {
      // 다른 핀을 골랐다 — 미리보기 높이로 되돌리고 상세 로드 상태 초기화.
      _detailRequested = false;
      _openingDetail = false;
      if (_sheet.isAttached) {
        _sheet.animateTo(
          PinSheet.peek,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _sheet.removeListener(_onSheetMoved);
    _sheet.dispose();
    _enter.dispose();
    super.dispose();
  }

  void _onSheetMoved() {
    if (!_sheet.isAttached) return;
    final size = _sheet.size;
    if ((size - _extent).abs() > 0.005) {
      setState(() => _extent = size);
      widget.onExtentChanged?.call(size);
    }
    // 반쯤 넘게 올리면 상세를 미리 불러둔다 — 펼쳤을 때 바로 보이게.
    if (!_detailRequested && size > PinSheet.peek + 0.06) {
      _detailRequested = true;
      ref.read(roomDetailProvider(widget.pin.id).notifier).loadRoom();
    }
    // 끝까지 올리면 상세 화면으로. 한 번만.
    if (!_openingDetail && size >= PinSheet.full - 0.02) {
      _openingDetail = true;
      widget.onOpenDetail();
      // 돌아왔을 때 시트는 펼침 높이에 머문다.
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted || !_sheet.isAttached) return;
        _sheet.animateTo(
          PinSheet.half,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
        _openingDetail = false;
      });
    }
  }

  void _expand() {
    if (!_sheet.isAttached) return;
    final target = _sheet.size < PinSheet.half - 0.05 ? PinSheet.half : PinSheet.peek;
    _sheet.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pin = widget.pin;
    final detail = ref.watch(roomDetailProvider(pin.id));

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutBack)),
      child: NotificationListener<DraggableScrollableNotification>(
        onNotification: (n) {
          // 미리보기보다 아래로 끌어 내리면 닫는다.
          if (n.extent <= n.minExtent + 0.005 && n.extent < PinSheet.peek - 0.08) {
            widget.onClose();
          }
          return false;
        },
        child: DraggableScrollableSheet(
          controller: _sheet,
          initialChildSize: PinSheet.peek,
          minChildSize: 0.18,
          maxChildSize: PinSheet.full,
          snap: true,
          snapSizes: const [PinSheet.peek, PinSheet.half],
          snapAnimationDuration: const Duration(milliseconds: 260),
          builder: (context, scroll) {
            return Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xl),
                  ),
                  border: const Border(top: BorderSide(color: AppColors.line)),
                  boxShadow: AppShadows.overlay,
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView(
                  controller: scroll,
                  padding: EdgeInsets.zero,
                  children: [
                    _Handle(onTap: _expand),
                    _PeekContent(
                      pin: pin,
                      distanceText: widget.distanceText,
                      onClose: widget.onClose,
                      onOpenDetail: widget.onOpenDetail,
                    ),
                    // 펼침 내용은 시트가 미리보기보다 올라올 때 서서히 나타난다 —
                    // 미리보기 상태에서 탭바 밑으로 비쳐 보이지 않게.
                    AnimatedOpacity(
                      opacity: ((_extent - PinSheet.peek) / 0.12).clamp(0.0, 1.0),
                      duration: const Duration(milliseconds: 120),
                      child: _ExpandedContent(
                        pin: pin,
                        state: detail,
                        requested: _detailRequested,
                        onOpenDetail: widget.onOpenDetail,
                      ),
                    ),
                    // 하단 탭바 + 여유.
                    const SizedBox(height: 110),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  final VoidCallback onTap;
  const _Handle({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line2,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

/// 미리보기 — 시트가 낮을 때도 다 보이는 부분.
class _PeekContent extends StatelessWidget {
  final MapPin pin;
  final String? distanceText;
  final VoidCallback onClose;
  final VoidCallback onOpenDetail;

  const _PeekContent({
    required this.pin,
    required this.distanceText,
    required this.onClose,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final placeLabel = AppConstants.placeTypes[pin.placeType] ?? '기타';
    final statusText = pin.isFull
        ? '마감'
        : (pin.maxMembers > 0 && pin.currentMembers / pin.maxMembers >= 0.8)
            ? '마감 임박'
            : '모집중';
    final meta = [
      AppDateUtils.formatDateTime(pin.date, pin.startTime),
      placeLabel,
      if (pin.regionDong.isNotEmpty) pin.regionDong,
      if (distanceText != null) distanceText!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  pin.title,
                  style: AppTextStyles.sectionHead,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkResponse(
                onTap: onClose,
                radius: 20,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 22, color: AppColors.ink3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(meta, style: AppTextStyles.body2, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Row(
            children: [
              Pill(
                label: '$statusText ${pin.currentMembers}/${pin.maxMembers}',
                tone: pin.isFull ? PillTone.muted : PillTone.hi,
              ),
              const SizedBox(width: 6),
              Pill(label: '${pin.ageMonthMin}~${pin.ageMonthMax}개월', tone: PillTone.sky),
            ],
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            text: pin.joined ? '내 방으로 이동' : '방 상세 보기',
            onPressed: onOpenDetail,
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '위로 끌어 올리면 더 볼 수 있어요',
              style: AppTextStyles.caption.copyWith(fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// 펼침 — 방 소개 · 참여자 · 약속. 상세 로드 전엔 자리만 잡는다.
class _ExpandedContent extends StatelessWidget {
  final MapPin pin;
  final RoomDetailState state;
  final bool requested;
  final VoidCallback onOpenDetail;

  const _ExpandedContent({
    required this.pin,
    required this.state,
    required this.requested,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final room = state.room;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DashedDivider(),
          if (room == null) ...[
            const SizedBox(height: 24),
            Center(
              child: requested && state.error == null
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                    )
                  : Text(
                      state.error ?? '위로 끌어 올리면 소개와 참여자를 볼 수 있어요',
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center,
                    ),
            ),
          ] else ...[
            // 방장
            const SizedBox(height: 14),
            Row(
              children: [
                InitialAvatar(
                  label: room.host.nickname,
                  size: 36,
                  tone: InitialAvatar.toneFor(room.host.id),
                  imageUrl: room.host.profileImageUrl,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: room.host.nickname, style: AppTextStyles.body1Bold),
                      TextSpan(text: ' · 방장', style: AppTextStyles.caption),
                    ]),
                  ),
                ),
              ],
            ),

            // 소개
            if ((room.description ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('모임 소개', style: AppTextStyles.sectionHead),
              const SizedBox(height: 6),
              Text(
                room.description!.trim(),
                style: AppTextStyles.paragraph,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // 참여자
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '참여자 ', style: AppTextStyles.sectionHead),
                TextSpan(
                  text: '${room.currentMembers}',
                  style: AppTextStyles.hand.copyWith(color: AppColors.ink2),
                ),
                TextSpan(text: ' / ${room.maxMembers}', style: AppTextStyles.caption),
              ]),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  for (final m in (room.members ?? const <RoomMember>[]).take(6))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InitialAvatar(
                        label: m.nickname,
                        size: 40,
                        tone: InitialAvatar.toneFor(m.id),
                        imageUrl: m.profileImageUrl,
                      ),
                    ),
                  if (room.currentMembers < room.maxMembers) const EmptySlotAvatar(size: 40),
                ],
              ),
            ),

            // 준비물 · 비용
            if (room.requiredItems.isNotEmpty || room.cost > 0) ...[
              const SizedBox(height: 16),
              DashedBox(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (room.requiredItems.isNotEmpty)
                      _kv('준비물', room.requiredItems.join(', ')),
                    if (room.cost > 0) ...[
                      if (room.requiredItems.isNotEmpty) const SizedBox(height: 6),
                      _kv('비용', '${room.cost}원'),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),
            GlassButton(text: '자세히 보기', onPressed: onOpenDetail),
          ],
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 48, child: Text(k, style: AppTextStyles.caption)),
          Expanded(child: Text(v, style: AppTextStyles.body2.copyWith(color: AppColors.ink))),
        ],
      );
}
