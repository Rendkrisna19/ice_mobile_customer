import 'package:flutter/material.dart';

class AppColors {
  // Prevent instantiation
  AppColors._();

  // ===========================================================================
  // PALETTE DEFINITION (Definisi Warna Sesuai Nama di Desain)
  // ===========================================================================
  
  static const Color deepForest = Color.fromARGB(255, 26, 83, 61);
  static const Color timberwolf = Color(0xFFC7B198);
  static const Color alabaster  = Color(0xFFF0ECE4);
  static const Color slateGray  = Color(0xFF4B5563);
  
  static const Color vibrantGreen = Color(0xFF22C55E);
  static const Color tomatoRed    = Color(0xFFEF4444);
  static const Color amber        = Color(0xFFF59E0B);

  // ===========================================================================
  // SEMANTIC ROLES (Penggunaan Warna dalam Aplikasi)
  // ===========================================================================

  // --- PRIMARY ---
  // Deep Forest
  static const Color primary = deepForest;
  
  // --- SECONDARY ---
  // Timberwolf
  static const Color secondary = timberwolf;

  // --- SURFACE ---
  // Alabaster - Background utama
  static const Color surface = alabaster;

  // --- NEUTRAL / INK ---
  // Slate Gray - Untuk teks utama
  static const Color neutral = slateGray;

  // --- STATES ---
  // Success - Vibrant Green
  static const Color success = vibrantGreen;
  
  // Error - Tomato Red
  static const Color error = tomatoRed;
  
  // Warning - Amber
  static const Color warning = amber;

  // --- UTILS ---
  static const Color white = Colors.white;
  static const Color black = Colors.black;
}