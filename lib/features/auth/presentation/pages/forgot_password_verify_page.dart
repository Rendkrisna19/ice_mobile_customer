import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/app_typography.dart';
import '../../../../core/components/app_text_field.dart';
import '../../data/auth_service.dart';
import 'login_page.dart';

class ForgotPasswordVerifyPage extends StatefulWidget {
  final String email;

  const ForgotPasswordVerifyPage({super.key, required this.email});

  @override
  State<ForgotPasswordVerifyPage> createState() => _ForgotPasswordVerifyPageState();
}

class _ForgotPasswordVerifyPageState extends State<ForgotPasswordVerifyPage> {
  final _formKey = GlobalKey<FormState>();
  
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isResending = false;
  int _countdown = 60;
  Timer? _timer;
  String? _errorMessage;
  bool _isSuccess = false;
  bool _isPasswordVisible = false;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    _passwordController.dispose();
    super.dispose();
  }

  String get _otpCode => _otpControllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    final otp = _otpCode;
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Masukkan 6 digit kode OTP');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _authService.verifyForgotPasswordOtp(
      email: widget.email,
      otp: otp,
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response['success'] == true) {
      setState(() => _isSuccess = true);
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kata sandi berhasil diubah!'), backgroundColor: AppColors.success),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } else {
      setState(() {
        _errorMessage = response['message'] ?? 'Kode OTP salah atau sandi sama dengan yang lama';
      });
      // Clear OTP
      for (var c in _otpControllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isResending = true);
    final result = await _authService.requestForgotPasswordOtp(widget.email);
    if (!mounted) return;
    setState(() => _isResending = false);

    if (result['success'] == true) {
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kode OTP baru telah dikirim'), backgroundColor: AppColors.success),
      );
      for (var c in _otpControllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Gagal mengirim OTP'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 24),

                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isSuccess ? Icons.check_circle : Icons.lock_reset,
                    color: Colors.white,
                    size: 40,
                  ),
                ),

                const SizedBox(height: 28),

                // Title
                Text(
                  _isSuccess ? 'Kata Sandi Diubah!' : 'Atur Kata Sandi Baru',
                  style: AppTypography.headlineSmall.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: 8),

                // Subtitle
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.neutral),
                    children: [
                      const TextSpan(text: 'Masukkan kode OTP dari email '),
                      TextSpan(
                        text: widget.email,
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: '\ndan kata sandi baru Anda.'),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // OTP Input Boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    return Container(
                      width: 48,
                      height: 56,
                      margin: EdgeInsets.only(right: index < 5 ? 8 : 0),
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        enabled: !_isLoading && !_isSuccess,
                        style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: _errorMessage != null ? AppColors.error.withOpacity(0.05) : AppColors.surface,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: _errorMessage != null ? AppColors.error.withOpacity(0.3) : Colors.transparent),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: _errorMessage != null ? AppColors.error.withOpacity(0.3) : Colors.transparent),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.primary, width: 2),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() => _errorMessage = null);
                          if (value.length == 1 && index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          } else if (value.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                        },
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 24),

                // Password Baru
                AppTextField(
                  label: "Kata Sandi Baru",
                  hint: "Minimal 8 karakter",
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  validator: (value) {
                    if (value == null || value.length < 8) {
                      return "Minimal 8 karakter";
                    }
                    return null;
                  },
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.neutral,
                    ),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),

                const SizedBox(height: 16),

                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_errorMessage!, style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),

                // Verify Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : _isSuccess
                          ? Container(
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(child: Icon(Icons.check, color: Colors.white, size: 28)),
                            )
                          : ElevatedButton(
                              onPressed: _verifyOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AppColors.primary.withOpacity(0.3),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: Text('Ubah Kata Sandi', style: AppTypography.labelLarge.copyWith(color: Colors.white)),
                            ),
                ),

                const SizedBox(height: 24),

                // Resend OTP
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Tidak menerima kode? ', style: AppTypography.bodyMedium.copyWith(color: AppColors.neutral)),
                    if (_countdown > 0 && !_isResending)
                      Text('$_countdown detik', style: AppTypography.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600))
                    else
                      GestureDetector(
                        onTap: _isResending ? null : _resendOtp,
                        child: Text(
                          _isResending ? 'Mengirim...' : 'Kirim Ulang',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
