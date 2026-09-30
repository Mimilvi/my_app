import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  // Публичный MQTT-брокер (не требует регистрации)
  static const String _broker = 'test.mosquitto.org';
  static const int _port = 1883;

  final String clientId;
  late MqttServerClient _client;
  bool _connected = false;

  // Поток входящих сообщений: (topic, payload)
  final _messageController = StreamController<MapEntry<String, String>>.broadcast();
  Stream<MapEntry<String, String>> get messages => _messageController.stream;

  // Поток статуса подключения
  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStatus => _statusController.stream;

  MqttService({required this.clientId}) {
    _client = MqttServerClient.withPort(_broker, clientId, _port);
    _client.logging(on: false);
    _client.keepAlivePeriod = 30;
    _client.autoReconnect = true;
    _client.onConnected = _onConnected;
    _client.onDisconnected = _onDisconnected;
  }

  bool get isConnected => _connected;

  void _onConnected() {
    _connected = true;
    _statusController.add(true);
    print('[MQTT] Подключено к $_broker');
  }

  void _onDisconnected() {
    _connected = false;
    _statusController.add(false);
    print('[MQTT] Отключено');
  }

  /// Подключение к брокеру
  Future<bool> connect() async {
    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    _client.connectionMessage = connMessage;

    try {
      await _client.connect();
    } catch (e) {
      print('[MQTT] Ошибка подключения: $e');
      _client.disconnect();
      return false;
    }

    if (_client.connectionStatus?.state == MqttConnectionState.connected) {
      // Слушаем входящие сообщения
      _client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> events) {
        for (final event in events) {
          final topic = event.topic;
          final payload =
              MqttPublishPayload.bytesToStringAsString(
                  (event.payload as MqttPublishMessage).payload.message);
          print('[MQTT] Получено: $topic → $payload');
          _messageController.add(MapEntry(topic, payload));
        }
      });
      return true;
    }
    return false;
  }

  /// Подписка на тему
  void subscribe(String topic) {
    if (!_connected) return;
    _client.subscribe(topic, MqttQos.atLeastOnce);
    print('[MQTT] Подписка на $topic');
  }

  /// Публикация сообщения
  void publish(String topic, String message) {
    if (!_connected) return;
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    print('[MQTT] Отправлено: $topic → $message');
  }

  /// Отключение
  void disconnect() {
    _client.disconnect();
  }
}