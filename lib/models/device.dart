import 'package:cloud_firestore/cloud_firestore.dart';

class Device {
  final String id;
  final String name;
  final String type;
  final String status;
  final String? ip;
  final DateTime? createdAt;

  Device({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    this.ip,
    this.createdAt,
  });

  /// Создание объекта из данных Firestore
  factory Device.fromMap(String id, Map<String, dynamic> map) {
    return Device(
      id: id,
      name: map['name'] ?? 'Без имени',
      type: map['type'] ?? 'unknown',
      status: map['status'] ?? 'offline',
      ip: map['ip'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Преобразование в формат Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'status': status,
      if (ip != null) 'ip': ip,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  bool get isOnline => status == 'online';
}