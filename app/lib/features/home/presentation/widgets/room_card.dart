import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../models/room.dart';
import '../../../../widgets/design/design_chip.dart';
import '../../../../widgets/design/notebook.dart';

/// 목록 한 행 (docs/09_UI_수첩안.md §4 '모임 찾기').
///
/// `[DateBlock] | 제목 + 메타 한 줄 + pill ≤2 | 상태 pill + 인원`
/// 카드가 아니라 행이다 — 행 사이 구분은 [DashedDivider] 로 목록 쪽에서 그린다.
class RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback? onTap;

  /// 옛 API — 행 전체 탭이 방 상세로 가므로 [onTap] 이 없을 때의 대체로만 쓴다.
  final VoidCallback? onOpenDetail;

  /// 안읽음 배지를 탭했을 때 열 채팅방.
  final VoidCallback? onOpenChat;

  /// 0 보다 크면 오른쪽에 berry 숫자 배지.
  final int unreadCount;

  /// 기본 pill 줄(개월수 + 승인 필요/준비물) 대신 쓸 pill 목록.
  /// 빈 목록을 주면 pill 줄이 사라진다.
  final List<Widget>? pills;

  /// 오른쪽 열(상태 pill + 인원) 대신 쓸 위젯. 안읽음 배지와의 간격은
  /// 호출부가 정한다 — 아무것도 안 보이려면 `SizedBox.shrink()` 를 준다.
  final Widget? trailing;

  const RoomCard({
    super.key,
    required this.room,
    this.onTap,
    this.onOpenDetail,
    this.onOpenChat,
    this.unreadCount = 0,
    this.pills,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(room.date);
    final rowPills = pills ?? defaultRoomPills(room);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? onOpenDetail,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (date != null) ...[
                DateBlock(date: date, today: _isToday(date)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      room.title,
                      style: AppTextStyles.cardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    RoomMetaLine(parts: roomMetaParts(room)),
                    if (rowPills.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Wrap(spacing: 6, runSpacing: 4, children: rowPills),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (unreadCount > 0)
                    UnreadBadge(count: unreadCount, onTap: onOpenChat),
                  if (trailing != null)
                    trailing!
                  else ...[
                    Padding(
                      padding: EdgeInsets.only(top: unreadCount > 0 ? 6 : 0),
                      child: roomStatusPill(room),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${room.currentMembers}/${room.maxMembers}명',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 좁은 자리(지도 시트·대시보드)용 작은 행 — 날짜 36 + 제목 + 메타 한 줄.
class RoomCardCompact extends StatelessWidget {
  final Room room;
  final VoidCallback? onTap;

  const RoomCardCompact({super.key, required this.room, this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(room.date);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (date != null) ...[
                DateBlock(date: date, today: _isToday(date), width: 36),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      room.title,
                      style: AppTextStyles.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    RoomMetaLine(parts: roomMetaParts(room)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 행 메타 한 줄 — "10:30 · 플레이타임 망원점 · 망원동". 구분자는 3px 점.
class RoomMetaLine extends StatelessWidget {
  final List<String> parts;

  const RoomMetaLine({super.key, required this.parts});

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    for (final part in parts) {
      if (spans.isNotEmpty) {
        spans.add(const WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: _MetaDot(),
          ),
        ));
      }
      spans.add(TextSpan(text: part));
    }
    return Text.rich(
      TextSpan(children: spans),
      style: AppTextStyles.body2,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _MetaDot extends StatelessWidget {
  const _MetaDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      decoration: const BoxDecoration(
        color: AppColors.line2,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 안읽음 숫자 배지 — berry 20px 알약. 탭하면 채팅방.
class UnreadBadge extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const UnreadBadge({super.key, required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    final body = Container(
      height: 20,
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.berry,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(count > 99 ? '99+' : '$count', style: AppTextStyles.badge),
    );
    if (onTap == null) return body;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: body,
    );
  }
}

/// 메타 한 줄에 들어갈 조각 — 시간 · 장소 · 동. 빈 값은 넣지 않는다.
List<String> roomMetaParts(Room room) {
  final place = (room.placeName ?? '').trim().isNotEmpty
      ? room.placeName!.trim()
      : (AppConstants.placeTypes[room.placeType] ?? '');
  return [
    _shortTime(room.startTime),
    if (place.isNotEmpty) place,
    if (room.regionDong.trim().isNotEmpty) room.regionDong.trim(),
  ].where((e) => e.isNotEmpty).toList();
}

/// 기본 pill 줄 — 개월수(sky) + 승인 필요/준비물(muted) 중 하나. 최대 2개.
List<Widget> defaultRoomPills(Room room) {
  return [
    Pill(
      label: '${room.ageMonthMin}~${room.ageMonthMax}개월',
      tone: PillTone.sky,
    ),
    if (room.isApprovalRequired)
      const Pill(label: '승인 필요', tone: PillTone.muted)
    else if (room.requiredItems.isNotEmpty)
      const Pill(label: '준비물', tone: PillTone.muted),
  ];
}

/// 상태 pill — 모집중만 형광펜, 나머지는 회색.
Pill roomStatusPill(Room room) {
  if (room.status == 'RECRUITING') {
    if (room.joined) return const Pill(label: '참여 중', tone: PillTone.muted);
    if (room.isFull) return const Pill(label: '마감', tone: PillTone.muted);
    return const Pill(label: '모집중', tone: PillTone.hi);
  }
  const labels = {
    'CLOSED': '마감',
    'IN_PROGRESS': '진행중',
    'COMPLETED': '종료',
    'CANCELLED': '취소',
  };
  return Pill(
    label: labels[room.status] ??
        AppConstants.roomStatus[room.status] ??
        room.status,
    tone: PillTone.muted,
  );
}

/// 날짜 그룹 라벨 — "오늘 · 9월 12일 금요일" / "내일" / "이번 주" / "다음 주" / "그 이후".
/// 지난 날짜는 달로 묶는다.
String roomGroupLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = target.difference(today).inDays;

  if (diff == 0) return '오늘 · ${DateFormat('M월 d일 EEEE', 'ko').format(date)}';
  if (diff == 1) return '내일';
  if (diff < 0) {
    return target.year == today.year
        ? DateFormat('M월', 'ko').format(date)
        : DateFormat('yyyy년 M월', 'ko').format(date);
  }
  // 이번 주 = 오늘이 속한 주의 일요일까지 (월요일 시작).
  final endOfWeek = today.add(Duration(days: 7 - today.weekday));
  if (!target.isAfter(endOfWeek)) return '이번 주';
  if (!target.isAfter(endOfWeek.add(const Duration(days: 7)))) return '다음 주';
  return '그 이후';
}

bool _isToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year && date.month == now.month && date.day == now.day;
}

/// "10:30" — 초가 붙어 와도 시:분까지만.
String _shortTime(String startTime) {
  final parts = startTime.split(':');
  if (parts.length < 2) return startTime;
  return '${parts[0]}:${parts[1]}';
}
