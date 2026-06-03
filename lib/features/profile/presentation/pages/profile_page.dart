import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/config/api_config.dart'; // Import untuk URL Domain
import '../../../../core/style/app_colors.dart';
import '../../../../core/style/app_typography.dart';
import '../../data/datasources/profile_remote_datasource.dart';

// [WAJIB] Pastikan path import ini sesuai dengan lokasi file LoginPage kamu
import '../../../auth/presentation/pages/login_page.dart'; 

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileRemoteDataSource _profileService = ProfileRemoteDataSource();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _userData;
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final data = await _profileService.getUserProfile();
      if (mounted) {
        setState(() {
          _userData = data;
          _nameController.text = data['name'] ?? "";
          _emailController.text = data['email'] ?? "";
          
          // [PENTING] Baca dari key 'phone' sesuai backend baru
          _phoneController.text = data['phone'] ?? ""; 
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _pickedImage = File(image.path);
        _isSaving = true;
      });

      try {
        final response = await _profileService.updatePhoto(_pickedImage!);
        if (response != null && response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Foto berhasil diganti!")));
          await _fetchUserData(); // Ambil data ulang biar URL gambar ke-refresh
        } else {
          throw Exception("Upload Gagal");
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal mengganti foto profil.")));
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveProfileChanges() async {
    setState(() => _isSaving = true);
    try {
      final response = await _profileService.updateProfile(
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text, 
      );

      if (response != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil berhasil disimpan!")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menyimpan data.")));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Akun"),
        content: const Text(
          "Tindakan ini permanen. Semua data Anda akan dihapus dan tidak dapat dikembalikan.\n\nYakin ingin menghapus akun?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus Akun", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isSaving = true);
    try {
      final response = await _profileService.deleteAccount();
      if (!mounted) return;
      if (response['success'] == true) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Gagal menghapus akun')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus akun. Coba lagi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- LOGIKA LOGOUT ---
  Future<void> _handleLogout() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi"),
        content: const Text("Yakin ingin keluar akun?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Keluar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      // 1. Panggil API Logout untuk hapus token lokal
      await _profileService.logout();
      
      // 2. Gunakan MaterialPageRoute untuk langsung memanggil layarnya
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()), // Langsung panggil widget-nya
          (Route<dynamic> route) => false, // Bersihkan semua tumpukan halaman
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    String? fullPhotoUrl;
    if (_userData != null && _userData!['profile_image'] != null) {
      fullPhotoUrl = "${ApiConfig.domain}/${_userData!['profile_image']}";
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text("Profil Saya", style: AppTypography.headlineSmall.copyWith(fontSize: 18)),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // --- 1. FOTO PROFIL ---
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.neutral.withOpacity(0.2), width: 2),
                    ),
                    child: ClipOval(
                      child: _pickedImage != null
                          ? Image.file(_pickedImage!, fit: BoxFit.cover) 
                          : (fullPhotoUrl != null)
                              ? Image.network(
                                  fullPhotoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => const Icon(Icons.person, size: 60, color: Colors.grey),
                                )
                              : const Icon(Icons.person, size: 60, color: Colors.grey),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),

            // --- 2. FORM DATA ---
            _buildEditField("Username", _nameController),
            const SizedBox(height: 20),
            _buildEditField("Email", _emailController, inputType: TextInputType.emailAddress),
            const SizedBox(height: 20),
            _buildEditField("Nomor HP", _phoneController, inputType: TextInputType.phone),
            
            const SizedBox(height: 40),

            // --- 3. TOMBOL SIMPAN ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfileChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text("Simpan Perubahan", style: AppTypography.labelLarge.copyWith(color: Colors.white)),
              ),
            ),

            const SizedBox(height: 16),

            // --- 4. TOMBOL LOGOUT ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _handleLogout,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text("Keluar Akun", style: AppTypography.labelLarge.copyWith(color: AppColors.error)),
              ),
            ),

            const SizedBox(height: 12),

            // --- 5. TOMBOL HAPUS AKUN ---
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isSaving ? null : _handleDeleteAccount,
                child: Text(
                  "Hapus Akun Permanen",
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.grey,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, {TextInputType inputType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.neutral)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: inputType,
          style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF9F9F9),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.neutral.withOpacity(0.1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.neutral.withOpacity(0.1))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
            suffixIcon: const Icon(Icons.edit, size: 16, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}