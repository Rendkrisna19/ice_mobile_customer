import 'package:flutter/material.dart';
import '../style/app_colors.dart';
import '../style/app_typography.dart';

enum ButtonType { primary, secondary, danger }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType type;
  final bool isLoading;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = ButtonType.primary,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    // Tentukan Warna berdasarkan Tipe
    final Color backgroundColor = _getBackgroundColor();
    final Color foregroundColor = _getForegroundColor();
    final BorderSide? border = _getBorder();

    return SizedBox(
      width: double.infinity, // Full width default
      height: 48, // Tinggi standar tombol mobile
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: AppColors.neutral.withOpacity(0.12),
          elevation: 0, // Flat style sesuai desain
          side: border,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8), // Radius sesuai gambar
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: type == ButtonType.secondary ? AppColors.primary : AppColors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: AppTypography.labelLarge.copyWith(
                      color: isLoading ? null : foregroundColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (type) {
      case ButtonType.primary:
        return AppColors.primary;
      case ButtonType.secondary:
        return Colors.transparent;
      case ButtonType.danger:
        return AppColors.error.withOpacity(0.1); // Merah muda
    }
  }

  Color _getForegroundColor() {
    switch (type) {
      case ButtonType.primary:
        return AppColors.white;
      case ButtonType.secondary:
        return AppColors.primary;
      case ButtonType.danger:
        return AppColors.error;
    }
  }

  BorderSide? _getBorder() {
    switch (type) {
      case ButtonType.secondary:
        return const BorderSide(color: AppColors.primary, width: 1.5);
      default:
        return null;
    }
  }
}