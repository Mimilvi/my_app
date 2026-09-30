import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ble_service.dart';
import '../services/provisioning_service.dart';


class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _ble = BleService();
  final _prov = ProvisioningService();

  BluetoothDevice? _connectedDevice;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndScan();
  }

  Future<void> _requestPermissionsAndScan() async {
    final permissions = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    final allGranted = permissions.values.every((p) => p.isGranted);
    if (!allGranted) {
      _showMessage('Разрешения не предоставлены');
      return;
    }

    final state = await FlutterBluePlus.adapterState.first;
    if (state != BluetoothAdapterState.on) {
      _showMessage('Включите Bluetooth');
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

  Future<void> _connectAndProvision(BluetoothDevice device) async {
    setState(() => _busy = true);
    try {
      _showMessage('Подключение к ${device.platformName}...');
      await _ble.connect(device);
      await _ble.stopScan();

      _showMessage('Установка BLE-сессии...');
      await _prov.createSession(device: device);

      _showMessage('Получение списка Wi-Fi сетей...');
      final networks = await _prov.scanWifiNetworks();

      if (!mounted) return;
      setState(() => _busy = false);

      if (networks.isEmpty) {
        _showMessage('ESP32 не видит Wi-Fi сетей');
        await _cleanup();
        return;
      }

      // Показываем диалог выбора сети
      _showWifiDialog(networks);
    } catch (e) {
      setState(() => _busy = false);
      _showMessage('Ошибка: $e');
      await _cleanup();
    }
  }

  void _showWifiDialog(List<String> networks) {
    String? selected = networks.first;
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Подключение к Wi-Fi'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selected,
                    decoration: const InputDecoration(
                      labelText: 'Wi-Fi сеть',
                      border: OutlineInputBorder(),
                    ),
                    items: networks
                        .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selected = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Пароль',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _cleanup();
                  },
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selected == null) return;
                    Navigator.pop(context);
                    await _sendCredentials(
                      selected!,
                      passwordController.text,
                    );
                  },
                  child: const Text('Подключить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sendCredentials(String ssid, String password) async {
    setState(() => _busy = true);
    try {
      _showMessage('Отправка данных на колонку...');
      await _prov.sendWifiCredentials(ssid: ssid, password: password);

      _showMessage('Ожидание подключения колонки к Wi-Fi...');
      final ok = await _prov.applyWifiConfig();

      if (ok) {
        _showMessage('✅ Колонка успешно подключена к Wi-Fi!');
      } else {
        _showMessage('❌ Не удалось подключить колонку');
      }
    } catch (e) {
      _showMessage('Ошибка: $e');
    } finally {
      setState(() => _busy = false);
      await _cleanup();
    }
  }

  Future<void> _cleanup() async {
    try {
      await _prov.disconnect();
      if (_connectedDevice != null) {
        await _ble.disconnect(_connectedDevice!);
      }
    } catch (_) {}
    if (mounted) setState(() => _connectedDevice = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Добавить колонку'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : () => _ble.startScan(),
          ),
        ],
      ),
      body: Column(
        children: [
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

          if (_busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),

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

          Expanded(
            child: StreamBuilder<List<ScanResult>>(
              stream: _ble.scanResults,
              builder: (context, snapshot) {
                final results = snapshot.data ?? [];
                if (results.isEmpty) {
                  return const Center(
                    child: Text(
                      'Устройства не найдены.\nНажмите 🔄 вверху.',
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
                    return ListTile(
                      leading: const Icon(Icons.bluetooth),
                      title: Text(name),
                      subtitle: Text('${device.remoteId} • ${r.rssi} dBm'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _busy ? null : () => _connectAndProvision(device),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}