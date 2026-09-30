import 'dart:typed_data';

import 'package:esp_provisioning_ble/esp_provisioning_ble.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// BLE transport implementation using flutter_blue_plus.
///
/// Implements [ProvTransport] to provide BLE communication with an ESP32
/// device running the ESP-IDF provisioning firmware. Handles connection,
/// service/characteristic discovery, and data exchange over GATT.
class TransportBLE implements ProvTransport {
  final BluetoothDevice device;
  final String serviceUUID;
  final Map<String, String> endpointTable;

  /// Cached characteristics keyed by endpoint name (e.g., 'prov-session').
  /// Populated after [connect] discovers services.
  late final Map<String, BluetoothCharacteristic> _characteristics;

  /// Default BLE service UUID for ESP32 provisioning.
  static const defaultServiceUUID = '021a9004-0382-4aea-bff4-6b3f1c5adfb4';

  /// Default endpoint-to-characteristic short UUID mapping.
  static const defaultEndpoints = {
    'prov-scan': 'ff50',
    'prov-session': 'ff51',
    'prov-config': 'ff52',
    'proto-ver': 'ff53',
    'custom-data': 'ff54',
  };

  TransportBLE(
    this.device, {
    this.serviceUUID = defaultServiceUUID,
    this.endpointTable = defaultEndpoints,
  });

  /// Builds the full 128-bit characteristic UUID from an endpoint short UUID.
  String _buildCharUUID(String endpointHex) {
    final hex = int.parse(
      endpointHex,
      radix: 16,
    ).toRadixString(16).padLeft(4, '0');
    return '${serviceUUID.substring(0, 4)}$hex${serviceUUID.substring(8)}';
  }

  @override
  Future<bool> connect() async {
    await disconnect();

    try {
      await device.connect(
        autoConnect: false,
        license: License.free,
      );
      print('Connected to ${device.platformName}');
    } catch (e) {
      print('Failed to connect: $e');
      return false;
    }

    try {
      await device.requestMtu(256);
    } catch (e) {
      print('MTU negotiation failed (using default): $e');
    }

    try {
      final services = await device.discoverServices();
      _cacheCharacteristics(services);
    } catch (e) {
      print('Service discovery failed: $e');
      return false;
    }

    return device.isConnected;
  }

  /// Finds the provisioning service and caches its characteristics in a map
  /// keyed by endpoint name for fast lookup during [sendReceive].
  void _cacheCharacteristics(List<BluetoothService> services) {
    _characteristics = {};

    final targetUUIDs = {
      for (final entry in endpointTable.entries)
        _buildCharUUID(entry.value): entry.key,
    };

    for (final service in services) {
      for (final char in service.characteristics) {
        final uuid = char.uuid.toString().toLowerCase();
        final endpointName = targetUUIDs[uuid];
        if (endpointName != null) {
          _characteristics[endpointName] = char;
        }
      }
    }

    print(
      'Cached ${_characteristics.length}/${endpointTable.length} characteristics',
    );
  }

  @override
  Future<Uint8List> sendReceive(String? epName, Uint8List? data) async {
    final char = _characteristics[epName ?? ''];
    if (char == null) {
      throw StateError('Characteristic not found for endpoint: $epName');
    }

    if (data != null && data.isNotEmpty) {
      await char.write(data.toList(), withoutResponse: false);
    }

    final response = await char.read();
    return Uint8List.fromList(response);
  }

  @override
  Future<bool> disconnect() async {
    if (device.isConnected) {
      try {
        await device.disconnect();
        return true;
      } catch (e) {
        print('Failed to disconnect: $e');
        return false;
      }
    }
    return true;
  }

  @override
  Future<bool> checkConnect() async {
    return device.isConnected;
  }
}