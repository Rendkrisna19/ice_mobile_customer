import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Import Style
import 'core/style/app_colors.dart';

// Import Feature Pages
import 'features/splash/presentation/pages/splash_page.dart';

void main() {
  // Pastikan binding terinisialisasi sebelum mengatur orientasi/system UI
  WidgetsFlutterBinding.ensureInitialized();

  // Opsi: Kunci orientasi ke Portrait (Aplikasi Food Delivery jarang Landscape)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Mengatur warna Status Bar agar transparan/sesuai desain
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // Icon hitam (karena bg terang)
  ));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZAD - Culinary Ecosystem',
      debugShowCheckedModeBanner: false, // Menghilangkan banner debug

      // --- KONFIGURASI TEMA GLOBAL ---
      theme: ThemeData(
        // Menggunakan font default Flutter dulu (Roboto), 
        // nanti bisa diganti 'Inter' jika sudah setup di pubspec.yaml
        fontFamily: 'Inter', 
        
        // Warna Utama
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.surface, // Background default semua halaman (Alabaster)

        // Skema Warna Material 3
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
          error: AppColors.error,
          background: AppColors.surface,
        ),
        
        // Mengatur tampilan AppBar default
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: AppColors.black),
          titleTextStyle: TextStyle(
            color: AppColors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Mengatur visual density agar tidak terlalu rapat/renggang
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),

      // --- TITIK AWAL APLIKASI ---
      // Langsung memanggil SplashPage yang baru kita buat
      home: const SplashPage(),
    );
  }
}