import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_error.dart';
import '../../../widgets/app_bar.dart';
import '../../../widgets/common_button.dart';
import '../../../widgets/common_input.dart';
import '../../../widgets/top_toast.dart';
import '../providers/auth_provider.dart';
import '../data/kcp_repository.dart';

/// 비밀번호 재설정 — 이메일 발송 인프라가 없어 KCP 본인인증으로 계정을 찾는다.
/// 1) KCP 인증(WebView) → 서버가 `kids://kcp-cert?status=reset&resetToken=…` 로 돌려줌
/// 2) 새 비밀번호 입력 → POST /auth/reset-password
///
/// 본인인증을 한 번도 안 한 계정(CI 없음)은 서버가 "일치하는 계정이 없습니다"로 거절한다.
class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  ConsumerState<PasswordResetScreen> createState() =>
      _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen> {
  static const _kcpReturnScheme = 'kids';
  static const _kcpReturnHost = 'kcp-cert';
  static const _authTimeout = Duration(minutes: 5);
  static final _passwordRule =
      RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$');

  WebViewController? _controller;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _timeoutTimer;

  // 2단계
  String? _resetToken;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadKcpForm();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _loadKcpForm() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final html = await ref.read(kcpRepositoryProvider).getResetForm();
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null &&
                uri.scheme == _kcpReturnScheme &&
                uri.host == _kcpReturnHost) {
              final token = uri.queryParameters['resetToken'];
              if (uri.queryParameters['status'] == 'reset' &&
                  token != null &&
                  token.isNotEmpty) {
                _timeoutTimer?.cancel();
                setState(() => _resetToken = token);
              } else {
                final message =
                    uri.queryParameters['message'] ?? '인증에 실패했습니다.';
                _showError(Uri.decodeComponent(message));
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            if ((error.url ?? '').startsWith('$_kcpReturnScheme://')) return;
            if (error.isForMainFrame != true) return;
            if (mounted && _errorMessage == null) {
              _showError('인증 페이지를 불러올 수 없습니다.\n네트워크를 확인하고 다시 시도해주세요.');
            }
          },
        ),
      );
      await controller.loadHtmlString(html);
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _isLoading = false;
      });
      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(_authTimeout, () {
        if (mounted && _resetToken == null && _errorMessage == null) {
          _showError('인증 시간이 초과되었습니다.\n다시 시도해주세요.');
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '본인인증 서비스를 불러오지 못했습니다.\n잠시 후 다시 시도해주세요.';
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    _timeoutTimer?.cancel();
    setState(() => _errorMessage = message);
  }

  Future<void> _submit() async {
    final pw = _passwordController.text;
    if (!_passwordRule.hasMatch(pw)) {
      showTopToast(context, '비밀번호는 8자 이상, 영문+숫자+특수문자를 포함해야 해요',
          backgroundColor: AppColors.bad);
      return;
    }
    if (pw != _confirmController.text) {
      showTopToast(context, '비밀번호가 서로 달라요', backgroundColor: AppColors.bad);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            resetToken: _resetToken!,
            newPassword: pw,
          );
      if (!mounted) return;
      showTopToast(context, '비밀번호를 변경했어요. 새 비밀번호로 로그인해 주세요',
          backgroundColor: AppColors.ok);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showTopToast(context, apiErrorMessage(e, fallback: '비밀번호 변경에 실패했어요'),
          backgroundColor: AppColors.bad);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: '비밀번호 재설정'),
      body: SafeArea(
        child: _resetToken != null ? _buildPasswordForm() : _buildKcpStep(),
      ),
    );
  }

  Widget _buildKcpStep() {
    return Stack(
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
                  const Icon(Icons.error_outline_rounded,
                      size: 48, color: AppColors.ink3),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body1,
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(text: '다시 시도', onPressed: _loadKcpForm),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.push('/inquiry'),
                    child: Text(
                      '문제가 있나요? 고객센터 문의',
                      style:
                          AppTextStyles.body2.copyWith(color: AppColors.link),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_isLoading)
          ColoredBox(
            color: AppColors.paper.withValues(alpha: 0.72),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.ink),
                strokeWidth: 2.4,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPasswordForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('새 비밀번호', style: AppTextStyles.display),
          const SizedBox(height: 6),
          Text('본인 확인이 끝났어요. 새 비밀번호를 입력해 주세요.',
              style: AppTextStyles.body2),
          const SizedBox(height: 28),
          CommonInput(
            label: '새 비밀번호',
            hint: '8자 이상, 영문+숫자+특수문자',
            controller: _passwordController,
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_off : Icons.visibility,
                color: AppColors.ink3,
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: 16),
          CommonInput(
            label: '새 비밀번호 확인',
            hint: '한 번 더 입력',
            controller: _confirmController,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            text: '비밀번호 변경',
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
