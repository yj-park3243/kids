import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// 수첩 장치 모음 (docs/09_UI_수첩안.md).
///
/// 전부 "지금·여기·오늘"을 가리키는 표시로만 쓴다. 장식으로 늘어놓으면 스티커북이 된다.
/// - [Highlight]      형광펜 자국 — 인사말 핵심 단어, 오늘 날짜, 활성 탭 아이콘 뒤
/// - [DashedDivider]  점선 괘선 — 목록 행 구분, 정보 목록
/// - [DashedBox]      점선 상자 — 약속/할 일, '+ 아이 추가'
/// - [Stamp]          D-day 도장 — 홈 다음 모임 카드, 후기 마감
/// - [MaskingTape]    마스킹테이프 — 홈 다음 모임 카드 위 한 곳
/// - [DateBlock]      손글씨 날짜 — 목록 행 왼쪽

/// 글자 아래쪽 절반에 살짝 기울어진 노란 형광펜.
///
/// ```dart
/// Highlight(child: Text('만나요', style: AppTextStyles.greeting))
/// ```
class Highlight extends StatelessWidget {
  final Widget child;
  final Color color;
  /// 글자 높이 대비 형광펜 두께 (0~1). 인사말 0.45, 작은 글씨 0.55.
  final double coverage;
  final double tiltDegrees;
  final EdgeInsets inset;

  const Highlight({
    super.key,
    required this.child,
    this.color = AppColors.hi,
    this.coverage = 0.45,
    this.tiltDegrees = -1.5,
    this.inset = const EdgeInsets.symmetric(horizontal: 2),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 글자보다 좌우로 살짝 넘치게 — Container margin 은 음수를 못 쓰므로 Positioned 로.
        Positioned(
          left: -inset.left,
          right: -inset.right,
          top: 0,
          bottom: 1,
          child: FractionallySizedBox(
            alignment: Alignment.bottomCenter,
            heightFactor: coverage,
            child: Transform.rotate(
              angle: tiltDegrees * math.pi / 180,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// 아이콘 뒤에 깔리는 형광펜 자국 (활성 탭, 오늘 숫자).
class HighlightMark extends StatelessWidget {
  final Widget child;
  final double width;
  final double height;
  final double tiltDegrees;
  final Alignment alignment;

  const HighlightMark({
    super.key,
    required this.child,
    this.width = 30,
    this.height = 14,
    this.tiltDegrees = -2,
    this.alignment = const Alignment(0, 0.25),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: alignment,
      clipBehavior: Clip.none,
      children: [
        Transform.rotate(
          angle: tiltDegrees * math.pi / 180,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: AppColors.hi,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// 수첩 점선 괘선. 목록 행 사이, 정보 목록 사이.
class DashedDivider extends StatelessWidget {
  final Color color;
  final double thickness;
  final double dash;
  final double gap;
  final EdgeInsets margin;

  const DashedDivider({
    super.key,
    this.color = AppColors.line2,
    this.thickness = 1,
    this.dash = 4,
    this.gap = 4,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: SizedBox(
        height: thickness,
        width: double.infinity,
        child: CustomPaint(
          painter: _DashPainter(color: color, thickness: thickness, dash: dash, gap: gap),
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final double dash;
  final double gap;

  _DashPainter({required this.color, required this.thickness, required this.dash, required this.gap});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + dash, size.width), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) =>
      old.color != color || old.thickness != thickness || old.dash != dash || old.gap != gap;
}

/// 세로 점선 — 통계 칸 사이 구분.
class DashedVerticalDivider extends StatelessWidget {
  final double height;
  final Color color;
  const DashedVerticalDivider({super.key, this.height = 32, this.color = AppColors.line2});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      height: height,
      child: CustomPaint(painter: _VDashPainter(color)),
    );
  }
}

class _VDashPainter extends CustomPainter {
  final Color color;
  _VDashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0.5, y), Offset(0.5, math.min(y + 3, size.height)), paint);
      y += 6;
    }
  }

  @override
  bool shouldRepaint(covariant _VDashPainter old) => old.color != color;
}

/// 빈 자리 아바타 — 점선 둥근 네모 + "+". 겹친 아바타 끝이나 참여자 목록 끝에.
class EmptySlotAvatar extends StatelessWidget {
  final double size;
  const EmptySlotAvatar({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return DashedBox(
      radius: size * 0.38,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.add_rounded, size: size * 0.5, color: AppColors.ink3),
      ),
    );
  }
}

/// 점선 테두리 상자. 배경은 종이 그대로(투명) — 카드보다 한 단계 가벼운 묶음.
class DashedBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color color;
  final Color? fill;
  final VoidCallback? onTap;

  const DashedBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 14,
    this.color = AppColors.line2,
    this.fill,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final body = CustomPaint(
      painter: _DashedRRectPainter(color: color, radius: radius, fill: fill),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return body;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: body);
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final Color? fill;

  _DashedRRectPainter({required this.color, required this.radius, this.fill});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(0.5);
    if (fill != null) {
      canvas.drawRRect(rrect, Paint()..color = fill!);
    }
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    const dash = 4.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + dash, metric.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color || old.radius != radius || old.fill != fill;
}

/// D-day 도장. 살짝 기울어진 노란 사각 + 손글씨.
class Stamp extends StatelessWidget {
  final String text;
  final double tiltDegrees;
  final double fontSize;

  const Stamp({
    super.key,
    required this.text,
    this.tiltDegrees = -3,
    this.fontSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tiltDegrees * math.pi / 180,
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 5, 9, 4),
        decoration: BoxDecoration(
          color: AppColors.hi,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          text,
          style: AppTextStyles.stamp.copyWith(fontSize: fontSize),
        ),
      ),
    );
  }
}

/// 카드 위 마스킹테이프. 카드를 Stack 으로 감싸고 `top: -9` 에 놓는다.
///
/// ```dart
/// Stack(clipBehavior: Clip.none, children: [
///   AppCard(hero: true, child: ...),
///   const Positioned(top: -9, left: 0, right: 0, child: Center(child: MaskingTape())),
/// ])
/// ```
class MaskingTape extends StatelessWidget {
  final double width;
  const MaskingTape({super.key, this.width = 74});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -2 * math.pi / 180,
      child: Container(
        width: width,
        height: 20,
        decoration: BoxDecoration(
          color: AppColors.hi.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(2),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 1, offset: Offset(0, 1)),
          ],
        ),
      ),
    );
  }
}

/// 목록 행 왼쪽의 손글씨 날짜. 토요일은 하늘, 일요일은 빨강.
///
/// [today] 면 숫자 뒤에 형광펜 자국.
class DateBlock extends StatelessWidget {
  final DateTime date;
  final bool today;
  final double width;

  const DateBlock({
    super.key,
    required this.date,
    this.today = false,
    this.width = 44,
  });

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Widget build(BuildContext context) {
    final color = switch (date.weekday) {
      DateTime.saturday => AppColors.skyInk,
      DateTime.sunday => AppColors.bad,
      _ => AppColors.ink,
    };
    Widget number = Text(
      '${date.day}',
      style: AppTextStyles.handXl.copyWith(color: color),
    );
    if (today) {
      number = HighlightMark(width: 34, height: 13, child: number);
    }
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          number,
          const SizedBox(height: 1),
          Text(
            _weekdays[date.weekday - 1],
            style: AppTextStyles.caption.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

/// 목록 그룹 라벨 ("오늘 · 9월 12일 금요일", "다음 주").
class GroupLabel extends StatelessWidget {
  final String text;
  final EdgeInsets padding;

  const GroupLabel(this.text, {super.key, this.padding = const EdgeInsets.only(top: 20, bottom: 2)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(text, style: AppTextStyles.groupLabel),
    );
  }
}

/// 섹션 제목 줄 — 왼쪽 굵은 제목, 오른쪽 조용한 액션.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets padding;
  /// 링크성 액션("사진첩 ›")이면 [AppColors.link]. 기본은 조용한 ink3.
  final Color? actionColor;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.only(top: 26, bottom: 12),
    this.actionColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(title, style: AppTextStyles.sectionHead)),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Text(action!, style: AppTextStyles.body2.copyWith(color: actionColor ?? AppColors.ink3)),
            ),
        ],
      ),
    );
  }
}

/// 포스트잇 — 자주 쓰는 조건을 붙였다 떼는 프리셋. (모임 찾기 보드, 홈 바로가기)
///
/// 붙이면([selected]) 회전이 0으로 펴지고 위에 테이프, 오른쪽 아래 펜 ✓ 가 찍힌다.
/// 색은 [PostItTone] 두 가지 — 기간은 노랑, 장소는 하늘. 그 이상 늘리지 않는다.
/// 포스트잇은 종이 위에 붙은 물건이라 얇은 그림자를 갖는다(카드 그림자 규칙의 예외).
enum PostItTone { hi, sky }

class PostIt extends StatelessWidget {
  final String label;
  final String? caption;
  final PostItTone tone;
  final bool selected;
  final VoidCallback? onTap;
  /// 붙이기 전 기울기. 보드에서 인덱스별로 ±1~2.5° 를 번갈아 준다.
  final double tiltDegrees;
  final double width;
  final double height;

  const PostIt({
    super.key,
    required this.label,
    this.caption,
    this.tone = PostItTone.hi,
    this.selected = false,
    this.onTap,
    this.tiltDegrees = -2,
    this.width = 74,
    this.height = 66,
  });

  /// 보드에서 인덱스별 기울기 — 같은 자리는 늘 같은 각도.
  static double tiltFor(int index) =>
      const [-2.5, 1.5, -1.0, 2.0, -1.5, 1.0][index % 6];

  @override
  Widget build(BuildContext context) {
    final bg = tone == PostItTone.hi ? AppColors.hi : AppColors.sky;
    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: width,
      height: height,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF281C0A).withValues(alpha: selected ? 0.16 : 0.12),
            blurRadius: selected ? 14 : 10,
            offset: Offset(0, selected ? 6 : 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            maxLines: 2,
            style: AppTextStyles.stamp.copyWith(fontSize: 17, height: 1.1),
          ),
          if (caption != null)
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(fontSize: 10.5, color: AppColors.ink2),
            ),
        ],
      ),
    );

    final stack = Stack(
      clipBehavior: Clip.none,
      children: [
        body,
        // 테이프 — 붙였을 때만.
        if (selected)
          Positioned(
            top: -6,
            left: width / 2 - 17,
            child: Transform.rotate(
              angle: -2 * math.pi / 180,
              child: Container(
                width: 34,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        // 펜 체크 — 붙였을 때만.
        if (selected)
          Positioned(
            right: 5,
            bottom: 2,
            child: Transform.rotate(
              angle: -8 * math.pi / 180,
              child: Text('✓', style: AppTextStyles.stamp.copyWith(fontSize: 22)),
            ),
          ),
      ],
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedRotation(
        turns: (selected ? 0 : tiltDegrees) / 360,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: AnimatedScale(
          scale: selected ? 1.04 : 1,
          duration: const Duration(milliseconds: 160),
          child: stack,
        ),
      ),
    );
  }
}

/// 점선 포스트잇 자리 — "＋ 조건 더보기" 같은 진입.
class PostItSlot extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const PostItSlot({
    super.key,
    required this.label,
    this.onTap,
    this.width = 74,
    this.height = 66,
  });

  @override
  Widget build(BuildContext context) {
    return DashedBox(
      radius: 2,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.ink3,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}

/// 모서리에 붙은 이름표 스티커 — 앱바 오른쪽 위 "두번 33개월".
class NameTag extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const NameTag({super.key, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Transform.rotate(
        angle: 5 * math.pi / 180,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
          decoration: BoxDecoration(
            color: AppColors.sky,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF281C0A).withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            text,
            style: AppTextStyles.stamp.copyWith(fontSize: 15, color: AppColors.skyInk),
          ),
        ),
      ),
    );
  }
}
