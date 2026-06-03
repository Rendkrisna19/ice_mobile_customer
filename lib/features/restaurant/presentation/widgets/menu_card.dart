import 'package:flutter/material.dart';
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/app_typography.dart';

class MenuCard extends StatefulWidget {
  final String name;
  final String description;
  final int price;
  final String imageUrl;
  final Function(int) onCountChanged;

  const MenuCard({
    super.key,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.onCountChanged,
  });

  @override
  State<MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<MenuCard> {
  int _quantity = 0;

  void _updateQuantity(int delta) {
    setState(() {
      _quantity += delta;
      if (_quantity < 0) _quantity = 0;
    });
    widget.onCountChanged(delta);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      // Garis pemisah tipis di bawah menu
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.neutral.withOpacity(0.1)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. DETAIL TEKS
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name,
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.description,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.neutral),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                
                // HARGA (Perbaikan: Hapus 'Jalur Polisi' / Strikethrough)
                Text(
                  "Rp ${widget.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}",
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.bold, // Harga dibuat tebal
                    decoration: TextDecoration.none, // Pastikan tidak ada coretan
                  ),
                ),
                
                const SizedBox(height: 12),

                // 2. TOMBOL ACTION (Deep Forest Color)
                _quantity == 0
                    ? 
                    // State A: Tombol Tambah (Outline Hijau)
                    SizedBox(
                        height: 32,
                        child: OutlinedButton(
                          onPressed: () => _updateQuantity(1),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary), // Border Deep Forest
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            foregroundColor: AppColors.primary, // Efek splash hijau
                          ),
                          child: Text(
                            "Tambah",
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primary, // Teks Deep Forest
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    : 
                    // State B: Counter (+ 1 -)
                    Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Tombol Kurang (Bulat Outline Hijau)
                          InkWell(
                            onTap: () => _updateQuantity(-1),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primary), // Border Deep Forest
                              ),
                              child: const Icon(Icons.remove, size: 16, color: AppColors.primary),
                            ),
                          ),
                          
                          // Angka
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text("$_quantity", style: AppTypography.labelLarge),
                          ),
                          
                          // Tombol Tambah (Bulat Outline Hijau)
                          InkWell(
                            onTap: () => _updateQuantity(1),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primary), // Border Deep Forest
                              ),
                              child: const Icon(Icons.add, size: 16, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // 3. GAMBAR MENU (Rounded)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              widget.imageUrl, 
              width: 110, // Sedikit diperbesar sesuai gambar
              height: 110,
              fit: BoxFit.cover,
              errorBuilder: (_,__,___) => Container(
                width: 110, height: 110, color: Colors.grey[200], child: const Icon(Icons.fastfood, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}