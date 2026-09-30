import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: Icon(
              themeService.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            ),
            title: const Text('Тёмная тема'),
            subtitle: Text(
              themeService.isDarkMode ? 'Включена' : 'Выключена',
            ),
            value: themeService.isDarkMode,
            onChanged: (value) {
              themeService.toggleTheme(value);
            },
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.notifications),
            title: Text('Уведомления'),
          ),
          const ListTile(
            leading: Icon(Icons.language),
            title: Text('Язык'),
          ),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('О приложении'),
          ),
        ],
      ),
    );
  }
}