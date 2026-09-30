import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/device.dart';

class DeviceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Возвращает ссылку на коллекцию устройств текущего пользователя
  CollectionReference<Map<String, dynamic>>? _userDevices() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;
    return _firestore.collection('users').doc(userId).collection('devices');
  }

  /// Поток устройств — обновляется автоматически при изменениях
  Stream<List<Device>> streamDevices() {
    final ref = _userDevices();
    if (ref == null) return Stream.value([]);

    return ref.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Device.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Добавить новое устройство
  Future<void> addDevice({
    required String name,
    required String type,
    String status = 'offline',
    String? ip,
  }) async {
    final ref = _userDevices();
    if (ref == null) throw Exception('Пользователь не авторизован');

    await ref.add({
      'name': name,
      'type': type,
      'status': status,
      if (ip != null) 'ip': ip,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Удалить устройство
  Future<void> deleteDevice(String deviceId) async {
    final ref = _userDevices();
    if (ref == null) throw Exception('Пользователь не авторизован');

    await ref.doc(deviceId).delete();
  }

  /// Обновить статус
  Future<void> updateStatus(String deviceId, String status) async {
    final ref = _userDevices();
    if (ref == null) throw Exception('Пользователь не авторизован');

    await ref.doc(deviceId).update({'status': status});
  }
}