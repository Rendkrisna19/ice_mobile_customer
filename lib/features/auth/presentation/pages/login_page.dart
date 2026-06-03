import 'dart:convert'; // [WAJIB] Tambahkan untuk parsing error JSON
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// Import Core Components & Styles
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/app_typography.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_text_field.dart';
import '../../../home/presentation/pages/home_page.dart';
import 'register_page.dart';

// Import Service
import '../../data/auth_service.dart'; 

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isPasswordVisible = false;
  bool _isLoading = false; 

  final AuthService _authService = AuthService(); 

  // [BARU] State khusus untuk menangkap pesan error dari server
  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    // [BARU] Hilangkan pesan error merah jika user mulai mengetik ulang
    _emailController.addListener(() {
      if (_emailError != null) setState(() => _emailError = null);
    });
    _passwordController.addListener(() {
      if (_passwordError != null) setState(() => _passwordError = null);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- HELPER PARSING ERROR ---
  // Membersihkan text "Exception" dan JSON mentah dari backend
  String _extractErrorMessage(String rawMessage) {
    String msg = rawMessage;
    
    // Coba cari JSON di dalam string
    int jsonStart = msg.indexOf('{');
    int jsonEnd = msg.lastIndexOf('}');
    
    if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
      try {
        String jsonStr = msg.substring(jsonStart, jsonEnd + 1);
        var decoded = jsonDecode(jsonStr);
        if (decoded['message'] != null) {
          return decoded['message'];
        }
      } catch (_) {}
    }
    
    // Hapus kata Exception jika masih ada
    return msg.replaceAll("Exception:", "").trim();
  }

  // --- LOGIC LOGIN ---
  Future<void> _handleLogin() async {
    // Tutup keyboard
    FocusScope.of(context).unfocus();

    // Reset error dari server
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await _authService.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (mounted) setState(() => _isLoading = false);

    if (result['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Berhasil masuk! Selamat datang."), backgroundColor: AppColors.primary),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } else {
      // --- PENANGANAN ERROR PINTAR ---
      String cleanError = _extractErrorMessage(result['message'] ?? "Gagal terhubung ke server");
      String lowerError = cleanError.toLowerCase();

      setState(() {
        // Cek apakah error karena email/user tidak ditemukan
        if (lowerError.contains('email') || lowerError.contains('pengguna') || lowerError.contains('ditemukan') || lowerError.contains('not found')) {
          _emailError = cleanError;
        } 
        // Cek apakah error karena sandi salah
        else if (lowerError.contains('sandi') || lowerError.contains('password') || lowerError.contains('salah') || lowerError.contains('match')) {
          _passwordError = cleanError;
        } 
        // Error umum (Server mati, dll)
        else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(cleanError),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });

      // Panggil ulang validasi agar kotak input otomatis jadi merah
      _formKey.currentState!.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, 
      // [FIX KEYBOARD] Agar form tidak tenggelam saat keyboard muncul
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48), // 48 is padding
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // LOGO
                        Image.asset(
                          'assets/images/logo.png',
                          width: 250, 
                          height: 100, 
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, error, stackTrace) {
                            return Column(
                              children: [
                                Text("ZAD+", style: AppTypography.headlineLarge.copyWith(fontSize: 48, color: AppColors.primary)),
                                Text("Lifestyle & Care", style: AppTypography.bodyMedium),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 48),

                        // FORM INPUT EMAIL
                        AppTextField(
                          label: "", 
                          hint: "customer@zadapps.com", 
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          // [MODIFIKASI] Validator gabungan (Default + Server Error)
                          validator: (value) {
                            if (_emailError != null) return _emailError; // Error dari server
                            if (value == null || value.isEmpty || !value.contains("@")) {
                              return "Format email tidak valid";
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // FORM INPUT PASSWORD
                        AppTextField(
                          label: "",
                          hint: "Kata Sandi",
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          // [MODIFIKASI] Validator gabungan (Default + Server Error)
                          validator: (value) {
                            if (_passwordError != null) return _passwordError; // Error dari server
                            if (value == null || value.isEmpty) {
                              return "Kata sandi wajib diisi";
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

                        const SizedBox(height: 32),

                        // TOMBOL MASUK
                        SizedBox(
                          width: double.infinity,
                          child: _isLoading 
                            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                            : AppButton(
                                text: "Masuk",
                                type: ButtonType.primary,
                                onPressed: _handleLogin, 
                              ),
                        ),

                        // Spacer agar ketika keyboard muncul, tidak mentok
                        const Spacer(),
                        const SizedBox(height: 40),

                        // FOOTER DAFTAR
                        RichText(
                          text: TextSpan(
                            style: AppTypography.bodyMedium,
                            children: [
                              const TextSpan(text: "Belum punya akun? "),
                              TextSpan(
                                text: "Daftar",
                                style: AppTypography.labelLarge.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (context) => const RegisterPage()),
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
        ),
      ),
    );
  }
}