import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 화면 배경 — 종이 한 장.
///
/// 이전에는 블러 블롭 4개를 깔았지만, 위에 놓인 모든 것이 흐려 보이는 가장 큰
/// 원인이었다. 이름은 호환을 위해 남겼고 이제는 단색 [AppColors.paper] 다.
/// 새 화면은 `Scaffold.backgroundColor` 기본값(paper)으로 충분하니 굳이 감싸지 않아도 된다.
class AccentBlobsBackground extends StatelessWidget {
  final Widget child;
  final bool strong;

  const AccentBlobsBackground({
    super.key,
    required this.child,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: AppColors.paper, child: child);
  }
}
