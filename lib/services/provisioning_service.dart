import 'package:esp_provisioning_ble/esp_provisioning_ble.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'transport_ble.dart';

class ProvisioningService {
  EspProv? _espProv;
  bool _sessionEstablished = false;

  bool get isSessionEstablished => _sessionEstablished;

  /// Создать сессию с устройством
  Future<void> createSession({
    required BluetoothDevice device,
    String pop = 'abcd1234',
  }) async {
    // В версии 1.1.0 TransportBLE нужно создавать именно так
    final transport = TransportBLE(device);
    _espProv = EspProv(
      transport: transport,
      security: Security1(pop: pop),
    );

    // Возвращает EstablishSessionStatus, а не bool
    final status = await _espProv!.establishSession();

    // Проверяем статус
    if (status == EstablishSessionStatus.connected) {
      _sessionEstablished = true;
    } else {
      _sessionEstablished = false;
      if (status == EstablishSessionStatus.keymismatch) {
        throw Exception('Неверный PoP (Proof of Possession)');
      }
      throw Exception('Не удалось установить сессию: $status');
    }
  }

  /// Сканировать Wi-Fi сети, видимые ESP32
  Future<List<String>> scanWifiNetworks() async {
    if (_espProv == null || !_sessionEstablished) {
      throw Exception('Сессия не установлена');
    }

    final networks = await _espProv!.startScanWiFi();
    return networks.map((n) => n.ssid).toList();
  }

  /// Отправить SSID и пароль
  Future<void> sendWifiCredentials({
    required String ssid,
    required String password,
  }) async {
    if (_espProv == null || !_sessionEstablished) {
      throw Exception('Сессия не установлена');
    }

    // В версии 1.1.0 параметры именованные
    await _espProv!.sendWifiConfig(ssid: ssid, password: password);
  }

  /// Применить конфигурацию и дождаться результата
  Future<bool> applyWifiConfig() async {
    if (_espProv == null) throw Exception('Сессия не установлена');

    await _espProv!.applyWifiConfig();

    // Проверяем статус через ConnectionStatus
    final status = await _espProv!.getStatus();
    return status.state == WifiConnectionState.Connected;
  }

  /// Отключиться от устройства
  Future<void> disconnect() async {
    // В версии 1.1.0 у EspProv нет метода disconnect(),
    // поэтому просто обнуляем ссылки
    _espProv = null;
    _sessionEstablished = false;
  }
}