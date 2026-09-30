import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/device_service.dart';
import '../services/mqtt_service.dart';

class SmartHomeScreen extends StatefulWidget {
  const SmartHomeScreen({super.key});

  @override
  State<SmartHomeScreen> createState() => _SmartHomeScreenState();
}

class _SmartHomeScreenState extends State<SmartHomeScreen> {
  late MqttService _mqtt;
  final _deviceService = DeviceService();

  bool _connected = false;
  final List<String> _log = [];

  // Локальный кэш состояний устройств (id -> вкл/выкл)
  final Map<String, bool> _localStates = {};

  @override
  void initState() {
    super.initState();
    _mqtt = MqttService(
      clientId: 'flutter_${DateTime.now().millisecondsSinceEpoch}',
    );
    _initMqtt();
  }

  Future<void> _initMqtt() async {
    final ok = await _mqtt.connect();
    if (!mounted) return;

    setState(() {
      _connected = ok;
      _log.insert(
        0,
        ok ? '✅ Подключено к брокеру' : '❌ Не удалось подключиться',
      );
    });

    if (ok) {
      _mqtt.subscribe('smarthome/command/+');
      _mqtt.subscribe('smarthome/status/+');

      _mqtt.messages.listen((entry) {
        if (!mounted) return;
        setState(() {
          _log.insert(0, '📥 ${entry.key} → ${entry.value}');
          if (_log.length > 20) _log.removeLast();
        });
      });
    }
  }

  void _toggleDevice(Device device) {
    final newState = !(_localStates[device.id] ?? false);
    setState(() {
      _localStates[device.id] = newState;
      _log.insert(0, '📤 smarthome/command/${device.id} → ${newState ? 'ON' : 'OFF'}');
      if (_log.length > 20) _log.removeLast();
    });

    _mqtt.publish(
      'smarthome/command/${device.id}',
      newState ? 'ON' : 'OFF',
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'light':
        return Icons.lightbulb;
      case 'socket':
        return Icons.power;
      case 'speaker':
        return Icons.speaker;
      case 'thermostat':
        return Icons.thermostat;
      default:
        return Icons.devices_other;
    }
  }

  @override
  void dispose() {
    _mqtt.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Умный дом'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Icon(
              _connected ? Icons.cloud_done : Icons.cloud_off,
              color: _connected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: StreamBuilder<List<Device>>(
              stream: _deviceService.streamDevices(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Ошибка: ${snapshot.error}'));
                }

                final devices = snapshot.data ?? [];
                if (devices.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'Нет устройств.\nДобавьте их на главном экране.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return GridView.count(
                  crossAxisCount: 2,
                  padding: const EdgeInsets.all(12),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: devices.map((device) {
                    final isOn = _localStates[device.id] ?? false;
                    return Card(
                      elevation: 3,
                      color: isOn ? Colors.blue.shade50 : null,
                      child: InkWell(
                        onTap: () => _toggleDevice(device),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _iconForType(device.type),
                              size: 48,
                              color: isOn ? Colors.blue : Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                device.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isOn ? 'ВКЛ' : 'ВЫКЛ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isOn ? Colors.green : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          // Лог MQTT
          Container(
            height: 160,
            color: Colors.black87,
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MQTT лог:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView.builder(
                    itemCount: _log.length,
                    itemBuilder: (context, index) {
                      return Text(
                        _log[index],
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}