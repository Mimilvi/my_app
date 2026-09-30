import 'package:flutter/material.dart';
import '../models/dialog.dart';
import '../services/dialog_service.dart';

class DialogsScreen extends StatefulWidget {
  /// ID устройства, чьи диалоги показываем
  final String deviceId;
  /// Имя устройства — для заголовка
  final String deviceName;

  const DialogsScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<DialogsScreen> createState() => _DialogsScreenState();
}

class _DialogsScreenState extends State<DialogsScreen> {
  final _service = DialogService();

  void _showAddDialog() {
    final userController = TextEditingController();
    final assistantController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Новый диалог'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Ваш вопрос',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: assistantController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Ответ колонки',
                  border: OutlineInputBorder(),
                ),
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
                if (userController.text.isEmpty ||
                    assistantController.text.isEmpty) {
                  return;
                }
                await _service.addDialog(
                  deviceId: widget.deviceId,
                  userMessage: userController.text.trim(),
                  assistantMessage: assistantController.text.trim(),
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  void _openDialog(DialogEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 70 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDate(entry.createdAt),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Text('Вы:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(entry.userMessage),
              const SizedBox(height: 16),
              const Text('Колонка:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(entry.assistantMessage),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Удалить диалог'),
                  onPressed: () async {
                    await _service.deleteDialog(
                      deviceId: widget.deviceId,
                      dialogId: entry.id,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Диалоги • ${widget.deviceName}'),
      ),
      body: StreamBuilder<List<DialogEntry>>(
        stream: _service.streamDialogs(widget.deviceId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }

          final dialogs = snapshot.data ?? [];

          if (dialogs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'У этой колонки пока нет диалогов.\nНажмите «+» внизу, чтобы добавить тестовый.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: dialogs.length,
            itemBuilder: (context, index) {
              final d = dialogs[index];
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: ListTile(
                  leading: const Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.blue,
                  ),
                  title: Text(
                    d.userMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        d.assistantMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(d.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _openDialog(d),
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
    );
  }
}