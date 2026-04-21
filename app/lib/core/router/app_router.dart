import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/child_setup_screen.dart';
import '../../features/auth/presentation/email_login_screen.dart';
import '../../features/auth/presentation/email_register_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/profile_setup_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/chat/presentation/chat_room_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/mypage/presentation/my_rooms_screen.dart';
import '../../features/mypage/presentation/mypage_screen.dart';
import '../../features/mypage/presentation/profile_edit_screen.dart';
import '../../features/notification/presentation/notification_screen.dart';
import '../../features/room/presentation/join_request_screen.dart';
import '../../features/room/presentation/room_create_screen.dart';
import '../../features/room/presentation/room_detail_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
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
              path: '/rooms',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chat',
              builder: (context, state) => const ChatListScreen(),
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

    // My rooms
    GoRoute(
      path: '/my-rooms',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MyRoomsScreen(),
    ),

    // Profile edit
    GoRoute(
      path: '/profile-edit',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ProfileEditScreen(),
    ),
  ],
);
