import '../../../widgets/top_toast.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/common_button.dart';
import '../data/kcp_repository.dart';
import '../providers/auth_provider.dart';

class PhoneVerificationScreen extends ConsumerStatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  ConsumerState<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState
    extends ConsumerState<PhoneVerificationScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isVerifying = false;
  String? _errorMessage;
  Timer? _timeoutTimer;

  static const _kcpReturnScheme = 'kids';
  static const _kcpReturnHost = 'kcp-cert';
  static const _authTimeout = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _loadKcpForm();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _startTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_authTimeout, () {
      if (mounted && !_isVerifying && _errorMessage == null) {
        _showError('인증 시간이 초과되었습니다.\n다시 시도해주세요.');
      }
    });
  }

  Future<void> _loadKcpForm() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final kcpRepo = ref.read(kcpRepositoryProvider);
      final html = await kcpRepo.getForm();

      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null &&
                uri.scheme == _kcpReturnScheme &&
                uri.host == _kcpReturnHost) {
              final status = uri.queryParameters['status'];
              if (status == 'success') {
                _handleKcpSuccess(uri.queryParameters);
              } else {
                final message =
                    uri.queryParameters['message'] ?? '인증에 실패했습니다.';
                _showError(Uri.decodeComponent(message));
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            final errorUrl = error.url ?? '';
            if (errorUrl.startsWith('$_kcpReturnScheme://')) return;
            if (error.isForMainFrame != true) return;
            if (mounted && !_isVerifying && _errorMessage == null) {
              _showError('인증 페이지를 불러올 수 없습니다.\n네트워크를 확인하고 다시 시도해주세요.');
            }
          },
          onHttpError: (error) {
            final url = error.request?.uri.toString() ?? '';
            if (url.startsWith('$_kcpReturnScheme://')) return;
            final code = error.response?.statusCode ?? 0;
            if (code >= 500 &&
                mounted &&
                !_isVerifying &&
                _errorMessage == null) {
              _showError('본인인증 서버 오류입니다. (HTTP $code)\n잠시 후 다시 시도해주세요.');
            }
          },
        ),
      );
      await controller.loadHtmlString(html);

      if (mounted) {
        setState(() {
          _controller = controller;
          _isLoading = false;
        });
        _startTimeout();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '본인인증 서비스를 불러오지 못했습니다.\n잠시 후 다시 시도해주세요.';
        });
      }
    }
  }

  Future<void> _handleKcpSuccess(Map<String, String> params) async {
    if (_isVerifying) return;
    _timeoutTimer?.cancel();
    setState(() => _isVerifying = true);

    try {
      final accessToken = params['accessToken']?.toString() ?? '';
      final refreshToken = params['refreshToken']?.toString() ?? '';
      final userId = params['userId']?.toString() ?? '';
      final merged = params['merged'] == 'true';

      if (accessToken.isEmpty || userId.isEmpty) {
        _showError('인증 결과를 받지 못했습니다.');
        return;
      }

      // 새 토큰으로 교체
      await SecureStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      // 인증 후 내 프로필 다시 받아 상태 갱신
      await ref.read(authProvider.notifier).checkAuth();

      if (!mounted) return;

      // 프로필 조회 실패(토큰 무효 등) 상태로 홈에 진입하면 모든 API가
      // 실패해 빈 화면에 갇힌다 — 홈 강행 대신 에러를 보여준다.
      if (ref.read(authProvider).status == AuthStatus.unauthenticated) {
        _showError('로그인 상태를 확인하지 못했습니다.\n다시 시도해주세요.');
        return;
      }

      // 계정 병합(이미 다른 계정이 쓰던 CI)이면 토큰이 그 계정으로 바뀌었으니
      // 스택을 정리하고 홈으로. 그 외에는 인증을 요청한 화면으로 돌아간다.
      if (merged) {
        showTopToast(context, '기존 계정으로 로그인되었습니다.');
        context.go('/home');
      } else {
        showTopToast(context, '본인 인증이 완료됐어요',
            backgroundColor: AppColors.ok);
        context.pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      _showError('인증 처리 중 오류가 발생했습니다.\n($e)');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    _timeoutTimer?.cancel();
    setState(() => _errorMessage = message);
  }

  /// 본인인증을 완료할 수 없는 상황(예: 이미 다른 계정에서 사용 중인 CI)에서
  /// 앱을 지우는 것 외에 벗어날 방법이 없던 문제를 해소 — 로그아웃 후 로그인으로.
  Future<void> _switchAccount() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    // 본인인증은 모임 만들기·참여 앞의 게이트라 언제든 그만둘 수 있어야 한다.
    return Scaffold(
      appBar: CustomAppBar(
        title: '본인인증',
        actions: [
          TextButton(
            onPressed: _switchAccount,
            child: Text('다른 계정',
                style: AppTextStyles.body2.copyWith(color: AppColors.link)),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (_controller != null && _errorMessage == null)
              WebViewWidget(controller: _controller!),
            if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: AppColors.ink3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body1,
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        text: '다시 시도',
                        onPressed: _loadKcpForm,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.push('/inquiry'),
                        child: Text(
                          '문제가 있나요? 고객센터 문의',
                          style: AppTextStyles.body2
                              .copyWith(color: AppColors.link),
                        ),
                      ),
                      TextButton(
                        onPressed: _switchAccount,
                        child: Text(
                          '다른 계정으로 로그인',
                          style: AppTextStyles.body2
                              .copyWith(color: AppColors.link),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_isLoading || _isVerifying)
              ColoredBox(
                color: AppColors.paper.withValues(alpha: 0.72),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.ink),
                        strokeWidth: 2.4,
                      ),
                      const SizedBox(height: 16),
                      Text('처리 중입니다...', style: AppTextStyles.body2),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
