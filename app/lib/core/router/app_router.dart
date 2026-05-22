import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/child_setup_screen.dart';
import '../../features/auth/presentation/email_login_screen.dart';
import '../../features/auth/presentation/email_register_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/phone_verification_screen.dart';
import '../../features/auth/presentation/profile_setup_screen.dart';
import '../../features/chat/presentation/chat_room_screen.dart';
import '../../features/follow/presentation/following_list_screen.dart';
import '../../features/growth_guide/presentation/growth_guide_detail_screen.dart';
import '../../features/growth_guide/presentation/growth_guide_list_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/mypage/presentation/appeal_screen.dart';
import '../../features/mypage/presentation/blocked_users_screen.dart';
import '../../features/mypage/presentation/my_rooms_screen.dart';
import '../../features/mypage/presentation/mypage_screen.dart';
import '../../features/mypage/presentation/profile_edit_screen.dart';
import '../../features/notice/presentation/notice_detail_screen.dart';
import '../../features/notice/presentation/notice_list_screen.dart';
import '../../features/notification/presentation/notification_screen.dart';
import '../../features/notification/presentation/notification_settings_screen.dart';
import '../../features/review/presentation/review_summary_screen.dart';
import '../../features/review/presentation/review_write_screen.dart';
import '../../features/room/presentation/attendance_screen.dart';
import '../../features/room/presentation/join_request_screen.dart';
import '../../features/room/presentation/photo_detail_screen.dart';
import '../../features/room/presentation/photo_grid_screen.dart';
import '../../features/room/presentation/photo_upload_screen.dart';
import '../../features/room/presentation/room_create_screen.dart';
import '../../features/room/presentation/room_detail_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/support/presentation/inquiry_screen.dart';
import '../../widgets/bottom_nav.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // Splash
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),

    // Onboarding
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),

    // Auth
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/email-login',
      builder: (context, state) => const EmailLoginScreen(),
    ),
    GoRoute(
      path: '/email-register',
      builder: (context, state) => const EmailRegisterScreen(),
    ),
    GoRoute(
      path: '/phone-verification',
      builder: (context, state) => const PhoneVerificationScreen(),
    ),
    GoRoute(
      path: '/profile-setup',
      builder: (context, state) => const ProfileSetupScreen(),
    ),
    GoRoute(
      path: '/child-setup',
      builder: (context, state) => const ChildSetupScreen(),
    ),

    // Main with bottom nav
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainScaffold(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/map',
              builder: (context, state) => const MapScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chat',
              builder: (context, state) => const MyRoomsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/mypage',
              builder: (context, state) => const MyPageScreen(),
            ),
          ],
        ),
      ],
    ),

    // Room
    GoRoute(
      path: '/rooms/create',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RoomCreateScreen(),
    ),
    GoRoute(
      path: '/rooms/:roomId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final roomId = state.pathParameters['roomId']!;
        return RoomDetailScreen(roomId: roomId);
      },
    ),
    GoRoute(
      path: '/rooms/:roomId/requests',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final roomId = state.pathParameters['roomId']!;
        return JoinRequestScreen(roomId: roomId);
      },
    ),
    GoRoute(
      path: '/rooms/:roomId/photos',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          PhotoGridScreen(roomId: state.pathParameters['roomId']!),
    ),
    GoRoute(
      path: '/rooms/:roomId/photos/upload',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          PhotoUploadScreen(roomId: state.pathParameters['roomId']!),
    ),
    GoRoute(
      path: '/rooms/:roomId/photos/:photoId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = (state.extra as Map?) ?? const {};
        final ids = (extra['photoIds'] as List?)?.cast<String>() ??
            [state.pathParameters['photoId']!];
        final idx = (extra['initialIndex'] as int?) ?? 0;
        return PhotoDetailScreen(
          roomId: state.pathParameters['roomId']!,
          photoIds: ids,
          initialIndex: idx,
        );
      },
    ),

    // Chat room
    GoRoute(
      path: '/chat/:chatRoomId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final chatRoomId = state.pathParameters['chatRoomId']!;
        return ChatRoomScreen(chatRoomId: chatRoomId);
      },
    ),

    // Notifications
    GoRoute(
      path: '/notifications',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const NotificationScreen(),
    ),
    GoRoute(
      path: '/notification-settings',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const NotificationSettingsScreen(),
    ),

    // 아이 추가 (마이페이지에서 진입 — child-setup 가입 흐름과 분리)
    GoRoute(
      path: '/child-add',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ChildSetupScreen(popOnDone: true),
    ),

    // Profile edit
    GoRoute(
      path: '/profile-edit',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ProfileEditScreen(),
    ),

    // Support — 1:1 문의
    GoRoute(
      path: '/inquiry',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const InquiryScreen(),
    ),

    // 차단 사용자 관리
    GoRoute(
      path: '/blocked-users',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BlockedUsersScreen(),
    ),

    // 계정 정지 안내 + 증거 재제출
    GoRoute(
      path: '/appeal',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AppealScreen(),
    ),

    // 출석 체크 (방 호스트 전용)
    GoRoute(
      path: '/rooms/:roomId/attendance',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          AttendanceScreen(roomId: state.pathParameters['roomId']!),
    ),

    // 리뷰 작성 (query: roomId, extra: List<ReviewMember>)
    GoRoute(
      path: '/reviews/write',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final roomId = state.uri.queryParameters['roomId'] ?? '';
        final members =
            (state.extra is List<ReviewMember>)
                ? state.extra as List<ReviewMember>
                : const <ReviewMember>[];
        return ReviewWriteScreen(
          args: ReviewWriteArgs(roomId: roomId, members: members),
        );
      },
    ),

    // 사용자 리뷰 요약
    GoRoute(
      path: '/users/:userId/reviews',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          ReviewSummaryScreen(userId: state.pathParameters['userId']!),
    ),

    // 팔로잉 목록
    GoRoute(
      path: '/follow/following',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const FollowingListScreen(),
    ),

    // 발달 가이드
    GoRoute(
      path: '/growth-guide',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const GrowthGuideListScreen(),
    ),
    GoRoute(
      path: '/growth-guide/:ageMonth',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final ageMonth =
            int.tryParse(state.pathParameters['ageMonth'] ?? '0') ?? 0;
        return GrowthGuideDetailScreen(ageMonth: ageMonth);
      },
    ),

    // 공지사항
    GoRoute(
      path: '/notices',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const NoticeListScreen(),
    ),
    GoRoute(
      path: '/notices/:noticeId',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          NoticeDetailScreen(noticeId: state.pathParameters['noticeId']!),
    ),
  ],
);
