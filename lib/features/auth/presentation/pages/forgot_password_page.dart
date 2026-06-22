import 'package:flutter/material.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/app_typography.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_text_field.dart';
import '../../data/auth_service.dart';
import 'forgot_password_verify_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  Future<void> _handleRequestOtp() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final result = await _authService.requestForgotPasswordOtp(email);

    if (mounted) setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kode OTP terkirim ke email Anda."), backgroundColor: AppColors.success),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ForgotPasswordVerifyPage(email: email),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? "Gagal mengirim OTP"),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Lupa Kata Sandi?",
                  style: AppTypography.headlineLarge.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  "Masukkan email yang terdaftar untuk mengatur ulang kata sandi Anda.",
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.neutral),
                ),
                const SizedBox(height: 48),
                AppTextField(
                  label: "Alamat Email",
                  hint: "customer@zadapps.com",
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains("@")) {
                      return "Format email tidak valid";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : AppButton(
                          text: "Kirim Kode OTP",
                          type: ButtonType.primary,
                          onPressed: _handleRequestOtp,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
