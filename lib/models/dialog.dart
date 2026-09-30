import 'package:cloud_firestore/cloud_firestore.dart';

class DialogEntry {
  final String id;
  final String userMessage;
  final String assistantMessage;
  final DateTime? createdAt;

  DialogEntry({
    required this.id,
    required this.userMessage,
    required this.assistantMessage,
    this.createdAt,
  });

  factory DialogEntry.fromMap(String id, Map<String, dynamic> map) {
    return DialogEntry(
      id: id,
      userMessage: map['userMessage'] ?? '',
      assistantMessage: map['assistantMessage'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userMessage': userMessage,
      'assistantMessage': assistantMessage,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}