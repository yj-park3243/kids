import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/version/version_check_service.dart';
import 'providers/auth_provider.dart';

/// 본인인증이 필요한 기능 앞에 세우는 게이트.
///
/// 가입 직후에 인증을 강제하면 온보딩에서 이탈한다(실측: 카카오 가입 1초 만에
/// 이탈). 그래서 인증은 실제로 필요한 시점 — 모임 만들기·참여 — 으로 미룬다.
///
/// 이미 인증했으면 곧바로 true. 아니면 안내를 띄우고, 사용자가 동의하면 인증
/// 화면으로 보낸 뒤 인증 여부를 돌려준다. [action] 은 '모임에 참여하려면' 처럼
/// 안내 문구 앞부분에 들어간다.
Future<bool> ensurePhoneVerified(
  BuildContext context,
  WidgetRef ref, {
  required String action,
}) async {
  if (ref.read(authProvider).user?.isPhoneVerified == true) return true;
  // 앱 심사 모드 — 서버가 우회를 켜면 리뷰어가 인증 없이 기능을 볼 수 있다.
  if (VersionCheckService.bypassPhoneVerification) return true;

  var proceed = false;
  await AwesomeDialog(
    context: context,
    dialogType: DialogType.info,
    animType: AnimType.scale,
    title: '본인 인증이 필요해요',
    desc: '$action 휴대폰 본인 인증이 필요해요.\n'
        '아이와 함께하는 모임이라 한 번만 확인할게요.',
    btnCancelText: '나중에',
    btnOkText: '인증하기',
    btnCancelOnPress: () {},
    btnOkOnPress: () => proceed = true,
  ).show();

  if (!proceed || !context.mounted) return false;

  await context.push('/phone-verification');
  if (!context.mounted) return false;
  // 인증 화면이 성공 시 checkAuth 로 프로필을 다시 받아온다.
  return ref.read(authProvider).user?.isPhoneVerified == true;
}

/// 모임 만들기 진입 — 본인인증을 통과해야 폼으로 보낸다.
/// 진입점이 여러 곳(홈/모임 찾기/지도/빈 상태)이라 한곳에 모아 둔다.
Future<void> openRoomCreate(BuildContext context, WidgetRef ref) async {
  if (!await ensurePhoneVerified(context, ref, action: '모임을 만들려면')) return;
  if (!context.mounted) return;
  context.push('/rooms/create');
}
