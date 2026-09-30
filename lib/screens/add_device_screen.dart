import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ble_service.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _ble = BleService();

  BluetoothDevice? _connectedDevice;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndScan();
  }

  Future<void> _requestPermissionsAndScan() async {
    // Запрашиваем разрешения на Bluetooth и геолокацию
    final permissions = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    final allGranted = permissions.values.every((p) => p.isGranted);
    if (!allGranted) {
      _showMessage('Разрешения не предоставлены. BLE не будет работать.');
      return;
    }

    // Проверяем, включён ли Bluetooth
    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      _showMessage('Включите Bluetooth на устройстве');
      return;
    }

    await _ble.startScan();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _connectTo(BluetoothDevice device) async {
    try {
      _showMessage('Подключение к ${device.platformName}...');
      await _ble.connect(device);
      setState(() => _connectedDevice = device);
      _showMessage('Подключено!');
    } catch (e) {
      _showMessage('Ошибка подключения: $e');
    }
  }

  Future<void> _disconnect() async {
    final device = _connectedDevice;
    if (device == null) return;

    await _ble.disconnect(device);
    setState(() => _connectedDevice = null);
    _showMessage('Отключено');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Добавить колонку'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _ble.startScan(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Информационная плашка
          Container(
            width: double.infinity,
            color: Colors.blue.shade50,
            padding: const EdgeInsets.all(12),
            child: const Text(
              'Включите колонку и удерживайте кнопку сопряжения, '
              'пока она не начнёт мигать. Затем выберите её из списка ниже.',
              style: TextStyle(fontSize: 13),
            ),
          ),

          // Индикатор сканирования
          StreamBuilder<bool>(
            stream: _ble.isScanning,
            builder: (context, snapshot) {
              final scanning = snapshot.data ?? false;
              return Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    if (scanning)
                      const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    const SizedBox(width: 10),
                    Text(scanning
                        ? 'Сканирование...'
                        : 'Сканирование завершено'),
                  ],
                ),
              );
            },
          ),

          const Divider(height: 1),

          // Список найденных устройств
          Expanded(
            child: StreamBuilder<List<ScanResult>>(
              stream: _ble.scanResults,
              builder: (context, snapshot) {
                final results = snapshot.data ?? [];
                if (results.isEmpty) {
                  return const Center(
                    child: Text(
                      'Устройства не найдены.\nНажмите 🔄 вверху, чтобы повторить.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final r = results[index];
                    final device = r.device;
                    final name = device.platformName.isNotEmpty
                        ? device.platformName
                        : '(без имени)';
                    final isConnected = _connectedDevice?.remoteId == device.remoteId;

                    return ListTile(
                      leading: Icon(
                        isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                        color: isConnected ? Colors.green : null,
                      ),
                      title: Text(name),
                      subtitle: Text(
                        '${device.remoteId} • сигнал: ${r.rssi} dBm',
                      ),
                      trailing: isConnected
                          ? TextButton(
                              onPressed: _disconnect,
                              child: const Text('Отключить'),
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: isConnected ? null : () => _connectTo(device),
                    );
                  },
                );
              },
            ),
          ),

          // Кнопка «Продолжить», если подключено
          if (_connectedDevice != null)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.wifi),
                  label: const Text('Передать Wi-Fi'),
                  onPressed: () {
                    _showMessage('Следующий шаг: передача Wi-Fi через BLE');
                    // Позже здесь будет реальная логика esp_provisioning_ble
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}