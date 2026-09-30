import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/device_service.dart';
import 'dialogs_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _deviceService = DeviceService();

  IconData _iconForType(String type) {
    switch (type) {
      case 'speaker':
        return Icons.speaker;
      case 'light':
        return Icons.lightbulb;
      case 'socket':
        return Icons.power;
      case 'thermostat':
        return Icons.thermostat;
      default:
        return Icons.devices_other;
    }
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    String selectedType = 'speaker';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Новое устройство'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Название'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Тип'),
                    items: const [
                      DropdownMenuItem(value: 'speaker', child: Text('Колонка')),
                      DropdownMenuItem(value: 'light', child: Text('Свет')),
                      DropdownMenuItem(value: 'socket', child: Text('Розетка')),
                      DropdownMenuItem(value: 'thermostat', child: Text('Термостат')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedType = v);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    try {
                      await _deviceService.addDevice(
                        name: name,
                        type: selectedType,
                      );
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    }
                  },
                  child: const Text('Добавить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои устройства'),
    actions: [
  IconButton(
    icon: const Icon(Icons.bluetooth),
    tooltip: 'Добавить колонку (BLE)',
    onPressed: () => Navigator.pushNamed(context, '/add-device'),
  ),
  IconButton(
    icon: const Icon(Icons.settings),
    onPressed: () => Navigator.pushNamed(context, '/settings'),
  ),
],
      ),
      body: StreamBuilder<List<Device>>(
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
                  'Пока нет устройств.\nНажмите «+», чтобы добавить.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Icon(
                    _iconForType(device.type),
                    color: device.isOnline ? Colors.green : Colors.grey,
                  ),
                  title: Text(device.name),
                  subtitle: Text(
                    '${device.type} • ${device.status}',
                  ),
              trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    IconButton(
      icon: const Icon(Icons.history),
      tooltip: 'История диалогов',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DialogsScreen(
              deviceId: device.id,
              deviceName: device.name,
            ),
          ),
        );
      },
    ),
    IconButton(
      icon: const Icon(Icons.delete_outline),
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удалить?'),
            content: Text('Удалить «${device.name}»?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await _deviceService.deleteDevice(device.id);
        }
      },
    ),
  ],
),
                  onTap: () => Navigator.pushNamed(context, '/smart-home'),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Устройства'),
          BottomNavigationBarItem(icon: Icon(Icons.lightbulb), label: 'Умный дом'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.pushNamed(context, '/smart-home');
          } else if (index == 2) {
            Navigator.pushNamed(context, '/profile');
          }
        },
      ),
    );
  }
}