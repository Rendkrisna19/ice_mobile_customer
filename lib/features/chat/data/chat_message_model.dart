class ChatMessageModel {
  final int id;
  final int transactionId;
  final int senderId;
  final int receiverId;
  final String message;
  final String sentBy;
  final DateTime createdAt;
  final String? senderName;
  final String? receiverName;
  final String? receiverPlateNumber;

  ChatMessageModel({
    required this.id,
    required this.transactionId,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.sentBy,
    required this.createdAt,
    this.senderName,
    this.receiverName,
    this.receiverPlateNumber,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'],
      transactionId: json['transaction_id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      message: json['message'],
      sentBy: json['sent_by'],
      createdAt: DateTime.parse(json['created_at']),
      senderName: json['sender']?['name'],
      receiverName: json['receiver']?['name'],
      receiverPlateNumber: json['receiver']?['plate_number'],
    );
  }
}
