import 'dart:async';
import 'dart:convert';
import 'package:medpotapp/pages/home.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

//metet paquete de permisos y modificar los archivos correspondientes en la carpeta android
//Estan en los mensajes de disc
Uuid UART_UUID = Uuid.parse("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
Uuid UART_RX = Uuid.parse("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
Uuid UART_TX = Uuid.parse("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");

int tActual = 0;
double valorActual = 0;

String targetDevice = 'Medidor de Potencia';

class BLEController {
  static final BLEController _singleton = BLEController._internalConstructor();

  factory BLEController() {
    return _singleton;
  }

  BLEController._internalConstructor() {
    /* Aqui añadir tema de tiempo y datos recibidos
    a lo mejor hay que quitar esto */
  }
  final flutterReactiveBle = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? scanStream;
  Stream<ConnectionStateUpdate>? currentConnectionStream;
  StreamSubscription<ConnectionStateUpdate>? connection;
  QualifiedCharacteristic? _txCharacteristic;
  QualifiedCharacteristic? _rxCharacteristic;
  Stream<List<int>>? receivedDataStream;
  Map<int, List<double>> rxData = {};
  int? currentTime;
  HomePageState? ui;
  bool scanning = false;
  bool connected = false;
  /* A partir de aqui funciones de recepcion y envio de datos */
  /* Permisos */
  Future<void> showNoPermissionDialog(BuildContext context) async =>
      showDialog<void>(
        context: context,
        barrierDismissible: false, // user must tap button!
        builder: (BuildContext context) => AlertDialog(
          title: const Text('No location permission '),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('No location permission granted.'),
                Text('Location permission is required for BLE to function.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Acknowledge'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
  Future<bool> checkAndroidBLEPermissions() async {
    if (Platform.isAndroid) {
      bool isLocation = true,
          isBlScan = true,
          isBlAdvertise = true,
          isBleConn = true;

      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect
      ].request();
      for (var status in statuses.entries) {
        if (status.key == Permission.location) {
          if (!status.value.isGranted) isLocation = false;
        } else if (status.key == Permission.bluetoothScan) {
          if (!status.value.isGranted) isBlScan = false;
        } else if (status.key == Permission.bluetoothAdvertise) {
          if (!status.value.isGranted) isBlAdvertise = false;
        } else if (status.key == Permission.bluetoothConnect) {
          if (!status.value.isGranted) isBleConn = false;
        }

        if (isLocation == false ||
            isBlScan == false ||
            isBlAdvertise == false ||
            isBleConn == false) {
          return Future.value(false);
        }
      }
    }
    return Future.value(true);
  }

  void stopScanAndConnect(DiscoveredDevice device) async {
    await stopScan();
    onConnect(device);
  }

  Future<void> stopScan() async {
    await scanStream!.cancel();
    scanning = false;
  }

  void onConnect(DiscoveredDevice device) {
    flutterReactiveBle.requestMtu(
        deviceId: device.id, mtu: 64); //seguro que hay que cambiar el mtu
    currentConnectionStream = flutterReactiveBle.connectToAdvertisingDevice(
        id: device.id,
        withServices: [UART_UUID, UART_RX, UART_TX],
        prescanDuration: const Duration(seconds: 1));
    connection = currentConnectionStream!.listen((event) {
      switch (event.connectionState) {
        case DeviceConnectionState.connecting:
          {
            break;
          }
        case DeviceConnectionState.connected:
          {
            connected = true;
            _txCharacteristic = QualifiedCharacteristic(
                characteristicId: UART_TX,
                serviceId: UART_UUID,
                deviceId: event.deviceId);
            _rxCharacteristic = QualifiedCharacteristic(
                characteristicId: UART_RX,
                serviceId: UART_UUID,
                deviceId: event.deviceId);

            receivedDataStream = flutterReactiveBle
                .subscribeToCharacteristic(_txCharacteristic!);

            receivedDataStream!.listen((data) {
              print("Data received: " + utf8.decode(data));
              onReceiveData(utf8.decode(data));
            });
            break;
          }
        case DeviceConnectionState.disconnecting:
          {
            connected = false;
            break;
          }
        case DeviceConnectionState.disconnected:
          {
            break;
          }
      }
    });
  }

  void startScan() async {
    bool goForIt = await checkAndroidBLEPermissions();
    if (goForIt) {
      scanning = true;
      scanStream =
          flutterReactiveBle.scanForDevices(withServices: []).listen((device) {
        if (device.name == targetDevice) {
          stopScanAndConnect(device);
        }
      });
      /* Faltan control de errores*/
    }
  }

  void disconnect() async {
    await connection!.cancel();
    connected = false;
  }

  void sendDataRaw(int? value) async {
    if (value == null) return;
    if (connected) {
      await flutterReactiveBle
          .writeCharacteristicWithResponse(_rxCharacteristic!, value: [value]);
    }
  }

  void sendData(String data) async {
    if (connected) {
      //avoid sending unwanted data
      await flutterReactiveBle.writeCharacteristicWithResponse(
          _rxCharacteristic!,
          value: data.codeUnits);
    }
  }

  void onReceiveData(String data) {
    if (decodeData(data)) {
      ui!.updateData(rxData);
    }
  }

  bool decodeData(String data) {
    /*
    Formato mensaje:
    Tiempo: int
    Una lectura: float
    */

    if (!data.contains('Una lectura') || !data.contains('Tiempo')) return false;

    List<String> parts = data.split(':');
    switch (parts[0]) {
      case 'Tiempo':
        currentTime = int.parse(parts[1]);
        break;
      case 'Una lectura':
        if (currentTime == 0) return false;
        rxData.putIfAbsent(currentTime, ifAbsent)
    }
    //if (parts.length != 2) return false;
    int time = parts[1] as int;
    double measure = parts[1].split(':')[1] as double;
    if (rxData.containsKey(time)) {
      rxData[time]!.add(measure);
    } else {
      rxData[time] = [measure];
    }

    /* final media =
        rxData[tiempo]!.reduce((a, b) => a + b) / rxData[tiempo]!.length;
    medias.add(media);
    */

    return true;
  }
}
