import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_constants.dart';
import 'core/constants/app_text_styles.dart';
import 'core/error/error_reporter.dart';
import 'core/push/push_token_service.dart';
import 'core/router/app_router.dart';
import 'core/scroll/app_scroll_behavior.dart';
import 'core/version/version_check_service.dart';
import 'features/share/deeplink/deeplink_handler.dart';
import 'features/share/deeplink/fcm_tap_handler.dart';
import 'firebase_options.dart';

void main() async {
  // 전역 에러를 서버로 리포트하는 zone 안에서 부트.
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // 1) Flutter framework 에러
      // 기존 핸들러를 보관해 함께 호출한다 — 디버그 콘솔 출력은 물론,
      // integration_test 하니스가 자기 onError 를 유지하도록. 체인 없이
      // 덮어쓰면 테스트 binding 이 깨져 모든 단계가 타임아웃된다.
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        originalOnError?.call(details);
        unawaited(ErrorReporter.instance.report(
          details.exceptionAsString(),
          stackTrace: details.stack?.toString(),
          screenName: details.library,
        ));
      };

      // 2) 비동기 / native engine 에러 (Flutter 외부)
      PlatformDispatcher.instance.onError = (error, stack) {
        unawaited(ErrorReporter.instance.report(
          error.toString(),
          stackTrace: stack.toString(),
        ));
        return false; // false → 기본 처리 계속
      };

      await initializeDateFormatting('ko');

      // Noto Sans KR 폰트 미리 로드 — 첫 화면 레이아웃이 폰트
      // 로딩으로 흔들리는(칩이 늦게 자리 잡는) 것을 방지.
      try {
        await GoogleFonts.pendingFonts([GoogleFonts.notoSansKr()]);
      } catch (_) {}

      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      );

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      await FlutterNaverMap().init(
        clientId: AppConstants.naverMapClientId,
        onAuthFailed: (ex) => debugPrint('NaverMap auth failed: $ex'),
      );

      // iOS App Tracking Transparency — IDFA 사용 광고 SDK 정책상
      // notDetermined 상태일 때 권한을 요청한다. 응답 무관하게 진행.
      if (Platform.isIOS) {
        try {
          final status =
              await AppTrackingTransparency.trackingAuthorizationStatus;
          if (status == TrackingStatus.notDetermined) {
            await AppTrackingTransparency.requestTrackingAuthorization();
          }
        } catch (_) {}
      }

      // AdMob — 광고 SDK는 백그라운드로 초기화 (UI 부트를 막지 않도록).
      unawaited(MobileAds.instance.initialize());

      // Kakao SDK — 공유 기능에 필요. TODO: 실제 네이티브 앱 키 주입.
      KakaoSdk.init(
        nativeAppKey: AppConstants.kakaoNativeAppKey,
      );

      // 딥링크 / FCM 탭 핸들러 — 라우터가 초기화된 직후 연결.
      unawaited(DeeplinkHandler.instance.init(appRouter));
      unawaited(FcmTapHandler.instance.init(appRouter));

      runApp(
        const ProviderScope(
          child: KidsApp(),
        ),
      );
    },
    // 3) zone 내부에서 잡히지 않은 에러
    (error, stack) {
      unawaited(ErrorReporter.instance.report(
        error.toString(),
        stackTrace: stack.toString(),
      ));
    },
  );
}

class KidsApp extends StatelessWidget {
  const KidsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '같이크자',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      scrollBehavior: const AppScrollBehavior(),
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      builder: (context, child) => GestureDetector(
        // 빈 영역 탭 / 스크롤 시 키보드 닫기 — 모든 화면 공통.
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: NotificationListener<ScrollStartNotification>(
          onNotification: (_) {
            FocusManager.instance.primaryFocus?.unfocus();
            return false;
          },
          child: _AppBootstrap(child: child ?? const SizedBox.shrink()),
        ),
      ),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          surface: AppColors.surface,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: AppTextStyles.button,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 1,
        ),
        splashColor: AppColors.primary.withValues(alpha: 0.1),
        highlightColor: AppColors.primary.withValues(alpha: 0.05),
      ),
    );
  }
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap({required this.child});

  final Widget child;

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 앱 부트스트랩 — 버전 체크(+위치/플랫폼 전송)와 FCM 토큰 등록.
      VersionCheckService.check(context);
      unawaited(PushTokenService.instance.init());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
