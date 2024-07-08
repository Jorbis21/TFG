import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';

class BluetoothManager {
  BluetoothManager._privateConstructor();

  static final BluetoothManager _singleton =
      BluetoothManager._privateConstructor();

  final FlutterReactiveBle ble = FlutterReactiveBle();
  final String deviceId = "Medidor de Potencia";
  late DiscoveredDevice powerMeter;
  late QualifiedCharacteristic rxCharacteristic;
  late QualifiedCharacteristic txCharacteristic;
  late Stream<ConnectionStateUpdate> connectionStream;
  late StreamSubscription<ConnectionStateUpdate> connectionSubscription;

  // UUIDs del servicio y características que estás utilizando
  final Uuid serviceUUID = Uuid.parse("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX");
  final Uuid rxCharacteristicUUID =
      Uuid.parse("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX");
  final Uuid txCharacteristicUUID =
      Uuid.parse("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX");

  Uuid UART_UUID = Uuid.parse("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
  Uuid UART_RX = Uuid.parse("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
  Uuid UART_TX = Uuid.parse("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");

  factory BluetoothManager() {
    return _singleton;
  }

  Future<void> checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();

    for (var status in statuses.values) {
      if (!status.isGranted) {
        throw Exception("Bluetooth permissions not granted");
      }
    }
  }

  Stream<DiscoveredDevice> startScan() {
    checkPermissions();
    return ble.scanForDevices(
        withServices: [serviceUUID], scanMode: ScanMode.balanced);
  }

  Future<void> connectToDevice() async {
    final scanStream = startScan();
    await for (final device in scanStream) {
      if (device.id == this.deviceId) {
        powerMeter = device;
        connectionStream = ble.connectToDevice(
          id: device.id,
          connectionTimeout: const Duration(seconds: 10),
        );
        connectionSubscription = connectionStream.listen((connectionState) {
          if (connectionState.connectionState ==
              DeviceConnectionState.connected) {
            discoverServices();
          }
        });
        break;
      }
    }
  }

  Future<void> discoverServices() async {
    rxCharacteristic = QualifiedCharacteristic(
      serviceId: serviceUUID,
      characteristicId: rxCharacteristicUUID,
      deviceId: powerMeter.id,
    );
    txCharacteristic = QualifiedCharacteristic(
      serviceId: serviceUUID,
      characteristicId: txCharacteristicUUID,
      deviceId: powerMeter.id,
    );
  }

  Future<void> sendData(String data) async {
    List<int> bytes = utf8.encode(data);
    await ble.writeCharacteristicWithResponse(txCharacteristic, value: bytes);
  }

  Future<String> receiveData() async {
    List<int> bytes = await ble.readCharacteristic(rxCharacteristic);
    return utf8.decode(bytes);
  }

  Future<void> disconnect() async {
    await connectionSubscription.cancel();
  }

  Stream<List<int>> onDataReceived() {
    return ble.subscribeToCharacteristic(rxCharacteristic);
  }
}
