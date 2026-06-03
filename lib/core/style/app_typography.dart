import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static const String _fontFamily = 'Inter'; 

  // --- HEADLINES & TITLES ---
  
  // Headline Large: 32px/40px, Bold
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    height: 1.25, // 40px
    fontWeight: FontWeight.bold, // w700
    color: AppColors.neutral,
    letterSpacing: -0.32, // -1%
  );

  // Headline Medium: 24px/32px, Bold
  static const TextStyle headlineMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    height: 1.33, // 32px
    fontWeight: FontWeight.bold, // w700
    color: AppColors.neutral,
    letterSpacing: -0.24, // -1%
  );

  // Headline Small: 20px/28px, Bold
  static const TextStyle headlineSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    height: 1.4, // 28px
    fontWeight: FontWeight.bold, // w700
    color: AppColors.neutral,
  );

  // Title Medium: 16px/24px, SemiBold
  static const TextStyle titleMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    height: 1.5, // 24px
    fontWeight: FontWeight.w600, // SemiBold
    color: AppColors.neutral,
  );

  // --- BODY & PARAGRAPHS ---

  // Body Large: 16px/24px, Regular
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    height: 1.5, // 24px
    fontWeight: FontWeight.w400, // Regular
    color: AppColors.neutral,
  );

  // Body Medium: 14px/20px, Regular (Default text)
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    height: 1.42, // 20px
    fontWeight: FontWeight.w400, // Regular
    color: AppColors.neutral,
  );

  // Body Small: 12px/16px, Regular
  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    height: 1.33, // 16px
    fontWeight: FontWeight.w400, // Regular
    color: AppColors.neutral,
  );

  // --- LABELS & UTILITIES ---

  // Label Large: 16px/20px, Bold (Tombol CTA)
  static const TextStyle labelLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    height: 1.25, // 20px
    fontWeight: FontWeight.bold, // w700
    color: AppColors.neutral,
    letterSpacing: 0.32, // +2%
  );

  // Label Small: 10px/13px, Bold (Badge)
  static const TextStyle labelSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10,
    height: 1.3, // 13px
    fontWeight: FontWeight.bold, // w700
    color: AppColors.neutral,
    letterSpacing: 0.5, // +5%
  );

  // --- DATA & PRICES ---
  
  // Price Display: 24px, SemiBold (Total Bayar)
  static const TextStyle priceDisplay = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600, // SemiBold
    color: AppColors.primary, // Biasanya harga pakai warna primary/hijau
    letterSpacing: -0.48, // -2%
  );
}