import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/dialog.dart';

class DialogService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>? _deviceDialogs(String deviceId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('devices')
        .doc(deviceId)
        .collection('dialogs');
  }

  /// Поток диалогов конкретного устройства
  Stream<List<DialogEntry>> streamDialogs(String deviceId) {
    final ref = _deviceDialogs(deviceId);
    if (ref == null) return Stream.value([]);

    return ref
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => DialogEntry.fromMap(d.id, d.data()))
            .toList());
  }

  /// Добавить диалог конкретному устройству
  Future<void> addDialog({
    required String deviceId,
    required String userMessage,
    required String assistantMessage,
  }) async {
    final ref = _deviceDialogs(deviceId);
    if (ref == null) throw Exception('Пользователь не авторизован');

    await ref.add({
      'userMessage': userMessage,
      'assistantMessage': assistantMessage,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Удалить диалог
  Future<void> deleteDialog({
    required String deviceId,
    required String dialogId,
  }) async {
    final ref = _deviceDialogs(deviceId);
    if (ref == null) return;
    await ref.doc(dialogId).delete();
  }
}