import 'package:flutter/material.dart';
import '../style/app_colors.dart';
import '../style/app_typography.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final String hint;
  final String? caption; 
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool enabled;
  final TextInputType keyboardType;
  
  // --- INI YANG KITA TAMBAHKAN AGAR BISA MERAH ---
  final String? errorText; // Menerima pesan error
  final Function(String)? onChanged; // Menerima aksi ketik
  final String? Function(String?)? validator; 

  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    this.caption, 
    this.controller,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.enabled = true, 
    this.validator,
    this.keyboardType = TextInputType.text,
    
    // Daftarkan parameter baru di sini
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: AppTypography.labelLarge.copyWith(
            fontSize: 16, 
            fontWeight: FontWeight.w700, 
            color: const Color(0xFF111827), 
          )
        ),
        const SizedBox(height: 8),

        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          keyboardType: keyboardType,
          enabled: enabled,
          
          // Pasang fungsinya di sini
          onChanged: onChanged,

          style: AppTypography.bodyMedium.copyWith(
            color: enabled ? const Color(0xFF111827) : const Color(0xFF6B7280),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: AppColors.neutral.withOpacity(0.5),
            ),
            filled: true,
            fillColor: AppColors.white, 
            contentPadding: const EdgeInsets.symmetric(
              vertical: 10, 
              horizontal: 12,
            ),
            
            // --- INI KUNCINYA ---
            // Kalau errorText ada isinya, border otomatis jadi merah
            errorText: errorText,
            errorMaxLines: 2, 
            
            helperText: caption,
            helperStyle: const TextStyle(
              fontSize: 10,
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827), 
              letterSpacing: 0.5,
            ),

            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppColors.neutral)
                : null,
            suffixIcon: suffixIcon,

            // Borders
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10), 
              borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1), 
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF1A534B), 
                width: 2, 
              ),
            ),

            // Style untuk Error (Merah)
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1), 
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
            ),

            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFF0ECE4), width: 1), 
            ),
          ),
        ),
      ],
    );
  }
}