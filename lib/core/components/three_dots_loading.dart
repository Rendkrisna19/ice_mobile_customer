import 'package:flutter/material.dart';
import '../style/app_colors.dart';

class ThreeDotsLoading extends StatefulWidget {
  const ThreeDotsLoading({super.key});

  @override
  State<ThreeDotsLoading> createState() => _ThreeDotsLoadingState();
}

class _ThreeDotsLoadingState extends State<ThreeDotsLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Animasi berulang (looping)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Logika matematika sederhana untuk membuat efek gelombang pada opacity
            // Membuat delay antar titik
            double value = (_controller.value + (index * 0.2)) % 1.0;
            double opacity = (value < 0.5) ? value * 2 : (1.0 - value) * 2;
            
            return Opacity(
              opacity: 0.3 + (opacity * 0.7), // Min opacity 0.3, Max 1.0
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 10,  // Ukuran titik
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.primary, // Warna Deep Forest
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}