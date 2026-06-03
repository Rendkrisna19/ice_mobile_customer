import 'package:flutter/material.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/app_typography.dart';
import 'package:ice_mobile_customer/core/config/api_config.dart';

class MerchantCard extends StatelessWidget {
  final String name;
  final String distance;
  final String duration;
  final double rating;
  final String coverImage; // Bisa diganti Asset/Network/Network
  final String logoImage;  // Bisa diganti Asset/Network/Network
  final bool isOpen;
  String getFullImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    // handle path 'storage/...'
    if (path.startsWith('storage/')) return '${ApiConfig.domain}/$path';
    return '${ApiConfig.domain}/$path';
  }

  const MerchantCard({
    super.key,
    required this.name,
    required this.distance,
    required this.duration,
    required this.rating,
    required this.coverImage,
    required this.logoImage,
    this.isOpen = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isOpen ? AppColors.white : AppColors.neutral.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(isOpen ? 0.05 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. BAGIAN ATAS (GAMBAR COVER + LOGO)
          SizedBox(
            height: 180, // Tinggi area gambar
            child: Stack(
              children: [
                // Gambar Cover (Full Width)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      (coverImage.startsWith('http') || coverImage.startsWith('file/')
                          ? Image.network(
                              getFullImageUrl(coverImage),
                              width: double.infinity,
                              height: 150,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, _, __) => Container(
                                height: 150,
                                width: double.infinity,
                                color: AppColors.neutral.withOpacity(0.2),
                                child: const Icon(Icons.image, color: AppColors.neutral),
                              ),
                            )
                          : Image.asset(
                              coverImage,
                              width: double.infinity,
                              height: 150,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, _, __) => Container(
                                height: 150,
                                width: double.infinity,
                                color: AppColors.neutral.withOpacity(0.2),
                                child: const Icon(Icons.image, color: AppColors.neutral),
                              ),
                            )),
                      if (!isOpen)
                        Container(color: Colors.black.withOpacity(0.28)),
                    ],
                  ),
                ),

                // Logo Bulat (Overlap)
                Positioned(
                  bottom: 0, // Nempel di bawah Stack
                  left: 16,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(4), // Jarak putih
                    child: ClipOval(
                      child: (logoImage.startsWith('http') || logoImage.startsWith('file/')
                          ? Image.network(
                              getFullImageUrl(logoImage),
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, _, __) => Container(
                                color: AppColors.secondary,
                                child: const Icon(Icons.store, size: 30, color: AppColors.primary),
                              ),
                            )
                          : Image.asset(
                              logoImage,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, _, __) => Container(
                                color: AppColors.secondary,
                                child: const Icon(Icons.store, size: 30, color: AppColors.primary),
                              ),
                            )),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. BAGIAN BAWAH (INFORMASI TEKS)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Detail Nama & Jarak (Kiri)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isOpen ? AppColors.black : AppColors.neutral,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$distance | $duration",
                        style: AppTypography.bodySmall.copyWith(
                          color: isOpen
                              ? AppColors.neutral.withOpacity(0.7)
                              : AppColors.error.withOpacity(0.9),
                          fontWeight: isOpen ? FontWeight.w400 : FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                // Rating (Kanan)
                Row(
                  children: [
                    const Icon(Icons.star, color: AppColors.warning, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      rating.toString(),
                      style: AppTypography.labelLarge.copyWith(
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}