import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
//metet paquete de permisos y modificar los archivos correspondientes en la carpeta android
//Estan en los mensajes de disc
Uuid _UART_UUID = Uuid.parse("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
Uuid _UART_RX   = Uuid.parse("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
Uuid _UART_TX   = Uuid.parse("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");

String targetDevice = 'Medidor de Potencia';

class BLEController{
  static final BLEController _singleton =
      BLEController._internalConstructor();

  factory BLEController() {
    return _singleton;
  }

  BLEController._internalConstructor() {
    /* Aqui añadir tema de tiempo y datos recibidos
    a lo mejor hay que quitar esto */
  }
  final flutterReactiveBle = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? _scanStream;
  Stream<ConnectionStateUpdate>? _currentConnectionStream;
  StreamSubscription<ConnectionStateUpdate>? _connection;
  QualifiedCharacteristic? _txCharacteristic;
  QualifiedCharacteristic? _rxCharacteristic;
  Stream<List<int>>? _receivedDataStream;
  /* A partir de aqui funciones de recepcion y envio de datos */
}