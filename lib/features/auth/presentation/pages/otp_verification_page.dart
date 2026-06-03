import 'package:flutter/material.dart';
import '../../data/auth_service.dart';
import '../../../home/presentation/pages/home_page.dart';

class OtpVerificationPage extends StatefulWidget {
  final String email;
  final String name;
  final String password;
  final String phone;

  const OtpVerificationPage({
    super.key,
    required this.email,
    required this.name,
    required this.password,
    required this.phone,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  String? _lastResponse;
  bool? _lastIsSuccess;

  Future<void> _verifyOtp() async {
    setState(() => _isLoading = true);

    final response = await AuthService().verifyOtpRegister(
      email: widget.email,
      name: widget.name,
      password: widget.password,
      otp: _otpController.text.trim(),
      phone: widget.phone,
    );

    final isSuccess = response['success'] == true ||
        (response['status']?.toString().toLowerCase() == 'success');

    setState(() {
      _isLoading = false;
    });

    if (isSuccess) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? 'OTP salah')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi OTP')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text('Masukkan kode OTP yang dikirim ke email Anda'),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Kode OTP'),
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _verifyOtp,
                    child: const Text('Verifikasi & Daftar'),
                  ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
