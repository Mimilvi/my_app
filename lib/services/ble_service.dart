import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  /// Поток найденных устройств
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  /// Статус сканирования (идёт / не идёт)
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  /// Текущее состояние Bluetooth-адаптера
  Stream<BluetoothAdapterState> get adapterState =>
      FlutterBluePlus.adapterState;

  /// Запустить сканирование на 15 секунд
  Future<void> startScan() async {
    // Если уже сканируем — остановим
    if (await FlutterBluePlus.isScanning.first) {
      await FlutterBluePlus.stopScan();
    }
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
  }

  /// Остановить сканирование
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  /// Подключиться к устройству
  Future<void> connect(BluetoothDevice device) async {
    await device.connect(
  timeout: const Duration(seconds: 15),
  license: License.free,
);
  }

  /// Отключиться от устройства
  Future<void> disconnect(BluetoothDevice device) async {
    await device.disconnect();
  }

  /// Проверить, подключено ли устройство
  bool isConnected(BluetoothDevice device) {
    return device.isConnected;
  }
}