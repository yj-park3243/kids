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
      final nextRoute = params['nextRoute']?.toString() ?? 'profile-setup';
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

      if (merged || nextRoute == 'home') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기존 계정으로 로그인되었습니다.')),
        );
        context.go('/home');
      } else {
        context.go('/profile-setup');
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('본인인증을 완료해야 이용 가능합니다.')),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const CustomAppBar(title: '본인인증', showBack: false),
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
                          size: 64,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body1.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        PrimaryButton(
                          text: '다시 시도',
                          onPressed: _loadKcpForm,
                        ),
                      ],
                    ),
                  ),
                ),
              if (_isLoading || _isVerifying)
                Container(
                  color: Colors.black26,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '처리 중입니다...',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
