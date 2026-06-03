import 'package:flutter/material.dart';
import '../style/app_colors.dart';
import '../style/app_typography.dart';

enum BadgeType { success, warning, error, neutral }

class AppBadge extends StatelessWidget {
  final String text;
  final BadgeType type;

  const AppBadge({
    super.key,
    required this.text,
    this.type = BadgeType.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getColors();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors['bg'],
        borderRadius: BorderRadius.circular(20), // Pill shape
      ),
      child: Text(
        text,
        style: AppTypography.labelSmall.copyWith(
          color: colors['text'],
        ),
      ),
    );
  }

  Map<String, Color> _getColors() {
    switch (type) {
      case BadgeType.success:
        return {'bg': AppColors.success.withOpacity(0.1), 'text': AppColors.success};
      case BadgeType.warning:
        return {'bg': AppColors.warning.withOpacity(0.1), 'text': AppColors.warning};
      case BadgeType.error:
        return {'bg': AppColors.error.withOpacity(0.1), 'text': AppColors.error};
      case BadgeType.neutral:
      default:
        return {'bg': AppColors.neutral.withOpacity(0.1), 'text': AppColors.neutral};
    }
  }
}