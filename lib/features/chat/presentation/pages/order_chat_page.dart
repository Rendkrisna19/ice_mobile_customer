import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ice_mobile_customer/core/style/app_colors.dart';
import 'package:ice_mobile_customer/core/style/app_typography.dart';
import '../../data/chat_remote_datasource.dart';
import '../../data/chat_message_model.dart';
import 'package:ice_mobile_customer/features/profile/data/datasources/profile_remote_datasource.dart';

class OrderChatPage extends StatefulWidget {
  final int transactionId;
  final int senderId;
  final int receiverId;
  final String sentBy;
  final String? driverName;
  final String? driverPlate;

  const OrderChatPage({
    super.key,
    required this.transactionId,
    required this.senderId,
    required this.receiverId,
    required this.sentBy,
    this.driverName,
    this.driverPlate,
  });

  @override
  State<OrderChatPage> createState() => _OrderChatPageState();
}

class _OrderChatPageState extends State<OrderChatPage> {
  final ChatRemoteDataSource _chatService = ChatRemoteDataSource();
  final ProfileRemoteDataSource _profileService = ProfileRemoteDataSource();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessageModel> _messages = [];
  bool _isLoading = true;
  String? _error;
  bool _sending = false;
  int? _senderId;

  String? _apiDriverName;
  String? _apiDriverPlate;
  String? _apiDriverPhone;

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _initSender();
    _fetchMessages(showLoading: true);
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _fetchMessages(showLoading: false);
    });
  }

  Future<void> _initSender() async {
    try {
      final user = await _profileService.getUserProfile();
      if (mounted) setState(() => _senderId = user['id']);
    } catch (_) {
      if (mounted) setState(() => _senderId = null);
    }
  }

  Future<void> _fetchMessages({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final Map<String, dynamic> responseData =
          await _chatService.fetchChatMessages(widget.transactionId);
      if (!mounted) return;

      final List<dynamic> rawMessages = responseData['messages'] ?? [];
      final newMessages =
          rawMessages.map((e) => ChatMessageModel.fromJson(e)).toList();

      setState(() {
        if (responseData['order_info'] != null) {
          _apiDriverName = responseData['order_info']['driver_name'];
          _apiDriverPlate = responseData['order_info']['driver_plate_number'];
          _apiDriverPhone = responseData['order_info']['driver_phone'];
        }
        _messages = newMessages;
        _isLoading = false;
      });

      // Scroll to latest message after frame renders
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted) return;
      if (showLoading) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || _senderId == null) return;
    setState(() => _sending = true);
    try {
      final data = await _chatService.sendChatMessage(
        transactionId: widget.transactionId,
        senderId: _senderId!,
        receiverId: widget.receiverId,
        message: text,
        sentBy: widget.sentBy,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessageModel.fromJson(data));
        _controller.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim pesan: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String? get _headerDriverName {
    if (widget.driverName != null && widget.driverName!.isNotEmpty) {
      return widget.driverName;
    }
    if (_apiDriverName != null && _apiDriverName!.isNotEmpty) {
      return _apiDriverName;
    }
    for (var m in _messages) {
      if (m.receiverId == widget.receiverId &&
          m.receiverName != null &&
          m.receiverName!.isNotEmpty) {
        return m.receiverName;
      }
    }
    return null;
  }

  String? get _headerDriverPlate {
    if (widget.driverPlate != null && widget.driverPlate!.isNotEmpty) {
      return widget.driverPlate;
    }
    if (_apiDriverPlate != null && _apiDriverPlate!.isNotEmpty) {
      return _apiDriverPlate;
    }
    for (var m in _messages) {
      if (m.receiverId == widget.receiverId &&
          m.receiverPlateNumber != null &&
          m.receiverPlateNumber!.isNotEmpty) {
        return m.receiverPlateNumber;
      }
    }
    return null;
  }

  Future<void> _launchWhatsApp(String phone, String name) async {
    String formattedPhone = phone;
    if (formattedPhone.startsWith('0')) {
      formattedPhone = "62${formattedPhone.substring(1)}";
    }
    
    String message = "Halo Pak $name, saya ingin konfirmasi untuk pesanan Order #${widget.transactionId}.";
    final Uri url = Uri.parse("https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal membuka WhatsApp")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverName = _headerDriverName;
    final driverPlate = _headerDriverPlate;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          'Chat Pesanan',
          style: AppTypography.headlineSmall
              .copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_apiDriverPhone != null && _apiDriverPhone!.isNotEmpty)
            IconButton(
              onPressed: () => _launchWhatsApp(_apiDriverPhone!, driverName ?? 'Driver'),
              icon: Image.asset('assets/icons/whatsapp.png', width: 24, height: 24, color: Colors.white, errorBuilder: (_,__,___) => const Icon(Icons.wechat, color: Colors.white, size: 24)),
              tooltip: 'Chat WA Driver',
            ),
        ],
      ),
      body: Column(
        children: [
          // HEADER CHAT
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha:0.95),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName != null && driverName.isNotEmpty
                            ? 'Chat dengan $driverName'
                            : 'Chat dengan Driver',
                        style: AppTypography.titleMedium.copyWith(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        driverPlate != null && driverPlate.isNotEmpty
                            ? driverPlate
                            : 'Pesanan #${widget.transactionId}',
                        style: AppTypography.bodySmall
                            .copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // LIST PESAN
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: AppTypography.bodyMedium
                                .copyWith(color: Colors.red)))
                    : _messages.isEmpty
                        ? Center(
                            child: Text(
                              'Belum ada pesan.\nMulai chat dengan driver!',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyMedium
                                  .copyWith(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(20),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final isMe = _senderId != null &&
                                  msg.senderId == _senderId;
                              return Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? AppColors.primary.withValues(alpha:0.9)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: isMe
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha:0.03),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            )
                                          ],
                                  ),
                                  child: Text(
                                    msg.message,
                                    style: AppTypography.bodyMedium.copyWith(
                                        color: isMe
                                            ? Colors.white
                                            : Colors.black),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          // INPUT PESAN
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_sending,
                    decoration: InputDecoration(
                      hintText: 'Ketik pesan...',
                      hintStyle: AppTypography.bodyMedium
                          .copyWith(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _sending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
