import 'package:flutter/material.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../../core/style/app_colors.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  
  @override
  void initState() {
    super.initState();
    _checkTokenAndNavigate();
  }

  Future<void> _checkTokenAndNavigate() async {
    // Delay splash screen 3 detik
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    if (!mounted) return;

    // Selalu ke HomePage — user bisa browse tanpa login.
    // Login hanya diminta saat akses fitur yang membutuhkan akun (Aktivitas, Profil).
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Menggunakan Putih bersih agar logo "pop-up" sesuai screenshot.
      // Jika ingin warna 'Alabaster' dari palette sebelumnya, ganti jadi: AppColors.surface
      backgroundColor: Colors.white, 
      
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0), // Memberi jarak kiri-kanan
          child: Image.asset(
            'assets/images/logo.png', // Logo ZAD + Apps (Lifestyle & Care)
            fit: BoxFit.contain,      // Menjaga rasio gambar agar tidak gepeng
            // Anda bisa mengatur width jika logo terlalu besar/kecil
            // width: MediaQuery.of(context).size.width * 0.7, 
          ),
        ),
      ),
    );
  }
}