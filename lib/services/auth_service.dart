import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Текущий пользователь (или null, если не авторизован)
  User? get currentUser => _auth.currentUser;

  /// Поток изменений состояния авторизации
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Регистрация нового пользователя
  Future<User?> signUp(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleError(e);
    }
  }

  /// Вход существующего пользователя
  Future<User?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleError(e);
    }
  }

  /// Выход из аккаунта
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Перевод кодов ошибок Firebase на понятный русский
  String _handleError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Пользователь с таким email не найден';
      case 'wrong-password':
        return 'Неверный пароль';
      case 'email-already-in-use':
        return 'Этот email уже зарегистрирован';
      case 'invalid-email':
        return 'Некорректный email';
      case 'weak-password':
        return 'Пароль слишком простой (минимум 6 символов)';
      case 'network-request-failed':
        return 'Нет подключения к интернету';
      default:
        return 'Ошибка: ${e.message ?? e.code}';
    }
  }
}