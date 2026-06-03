import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// Import Core Components & Styles
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/app_typography.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_text_field.dart';

// Import Pages
import '../../../home/presentation/pages/home_page.dart';
import 'login_page.dart';
import 'otp_verification_page.dart';

// Import Service
import '../../data/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers (Phone dihapus)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmationController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isPasswordConfirmationVisible = false;
  bool _isLoading = false;

  // Inisialisasi Service
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // LOGIKA REGISTER DENGAN OTP
  Future<void> _handleRegister() async {
    // 1. Validasi Form UI
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _passwordConfirmationController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Kata sandi tidak cocok"),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      // 2. Request OTP
      final otpResult = await _authService.requestRegisterOtp(_emailController.text.trim());
      setState(() => _isLoading = false);
      if (otpResult['success'] == true) {
        // Pindah ke halaman OTP
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationPage(
              email: _emailController.text.trim(),
              name: _nameController.text.trim(),
              password: _passwordController.text.trim(),
              phone: _phoneController.text.trim(),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(otpResult['message'] ?? 'Gagal request OTP')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error Aplikasi: $e"),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, 
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. LOGO
                Image.asset(
                  'assets/images/logo.png',
                  width: 200,
                  height: 80,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, _, __) => Text(
                    "ZAD+", 
                    style: AppTypography.headlineLarge.copyWith(color: AppColors.primary)
                  ),
                ),
                
                const SizedBox(height: 8),
                Text(
                  "Buat Akun Baru",
                  style: AppTypography.titleMedium.copyWith(color: AppColors.neutral),
                ),

                const SizedBox(height: 32),

                // 2. FORM INPUT
                
                // Nama Lengkap
                AppTextField(
                  label: "",
                  hint: "Nama Lengkap",
                  controller: _nameController,
                  validator: (value) => (value == null || value.isEmpty) 
                      ? "Nama wajib diisi" 
                      : null,
                ),

                const SizedBox(height: 16),

                // Email
                AppTextField(
                  label: "",
                  hint: "Alamat Email",
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => (value == null || !value.contains("@")) 
                      ? "Email tidak valid" 
                      : null,
                ),

                const SizedBox(height: 16),

                // Phone
                AppTextField(
                  label: "",
                  hint: "Nomor HP",
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: (value) => (value == null || value.isEmpty)
                      ? "Nomor HP wajib diisi"
                      : null,
                ),

                const SizedBox(height: 16),

                // Password
                AppTextField(
                  label: "",
                  hint: "Buat Kata Sandi",
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  validator: (value) => (value == null || value.length < 6) 
                      ? "Password minimal 6 karakter" 
                      : null,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.neutral,
                    ),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),

                const SizedBox(height: 16),

                // Password Confirmation
                AppTextField(
                  label: "",
                  hint: "Konfirmasi Kata Sandi",
                  controller: _passwordConfirmationController,
                  obscureText: !_isPasswordConfirmationVisible,
                  validator: (value) => (value == null || value.isEmpty)
                      ? "Konfirmasi password wajib diisi"
                      : null,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordConfirmationVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.neutral,
                    ),
                    onPressed: () => setState(() => _isPasswordConfirmationVisible = !_isPasswordConfirmationVisible),
                  ),
                ),

                const SizedBox(height: 16),

                // 3. TOMBOL DAFTAR
                _isLoading 
                  ? const CircularProgressIndicator(color: AppColors.primary)
                  : AppButton(
                      text: "Daftar Sekarang",
                      type: ButtonType.primary,
                      onPressed: _handleRegister,
                    ),

                const SizedBox(height: 24),

                // 4. FOOTER
                RichText(
                  text: TextSpan(
                    style: AppTypography.bodyMedium,
                    children: [
                      const TextSpan(text: "Sudah punya akun? "),
                      TextSpan(
                        text: "Masuk",
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginPage()),
                            );
                          },
                      ),
                    ],
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