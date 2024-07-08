import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'dart:async';
import 'package:octoplus/controller/application_controller.dart';

import 'dart:io' show Platform;

import 'package:permission_handler/permission_handler.dart';

Uuid octoplusUartUUID = Uuid.parse("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
Uuid octoplusUartRX = Uuid.parse("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");
Uuid octoplusUartTX = Uuid.parse("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");

Uuid tindeqServiceUUID = Uuid.parse("7e4e1701-1ea6-40c9-9dcc-13d34ffead57");
Uuid tindeqWriteUUID = Uuid.parse("7e4e1703-1ea6-40c9-9dcc-13d34ffead57");
Uuid tindeqNotifyUUID = Uuid.parse("7e4e1702-1ea6-40c9-9dcc-13d34ffead57");

var tindeqResponseCodes = {"cmd_resp": 0, "weight_measure": 1, "low_pwr": 4};
var tindeqCmds = {
  "TARE_SCALE": 0x64,
  "START_WEIGHT_MEAS": 0x65,
  "STOP_WEIGHT_MEAS": 0x66,
  "START_PEAK_RFD_MEAS": 0x67,
  "START_PEAK_RFD_MEAS_SERIES": 0x68,
  "ADD_CALIB_POINT": 0x69,
  "SAVE_CALIB": 0x6A,
  "GET_APP_VERSION": 0x6B,
  "GET_ERR_INFO": 0x6C,
  "CLR_ERR_INFO": 0x6D,
  "SLEEP": 0x6E,
  "GET_BATT_VLTG": 0x6F,
};

String targetNameOctoplus = "OCTOPLUS";
String targetNameProgressor = "Progressor";
String targetNameGripMeter = "GripMeter";
List<String> targetNames = [
  targetNameOctoplus,
  targetNameProgressor,
  targetNameGripMeter
];

class BluetoothController {
  static final BluetoothController _singleton =
      BluetoothController._internalConstructor();

  factory BluetoothController() {
    return _singleton;
  }

  BluetoothController._internalConstructor() {
    AppCtrl.hertzLister.addListener(() {
      double periodms = 1 / AppCtrl.hertzLister.value.toDouble() * 1000;
      targetMillis = periodms.round();
    });
    AppCtrl.hertzLister.value = AppCtrl.hertzLister.value;

    AppCtrl.restartListener.addListener(() {
      _currentCalculatedTimeMillis = 0;
      _prevPrevPoint = [0, 0, 0, 0, 0, 0, 0, 0];
      _prevPoint = [0, 0, 0, 0, 0, 0, 0, 0];
      aggregateData = [];
      lastMillisAggregate = 0;
      lastMillisTindeq = null;
    });

    AppCtrl.dataServiceRunningListener.addListener(() {
      if (_tindeq) {
        lastMillisTindeq = null;
        bool running = AppCtrl.dataServiceRunningListener.value;
        if (running) {
          BluetoothController().sendDataRaw(tindeqCmds["START_WEIGHT_MEAS"]);
        } else {
          BluetoothController().sendDataRaw(tindeqCmds["STOP_WEIGHT_MEAS"]);
        }
      }
    });
  }

  //ble things
  final flutterReactiveBle = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? _scanStream;
  Stream<ConnectionStateUpdate>? _currentConnectionStream;
  StreamSubscription<ConnectionStateUpdate>? _connection;
  QualifiedCharacteristic? _txCharacteristic;
  QualifiedCharacteristic? _rxCharacteristic;
  Stream<List<int>>? _receivedDataStream;
  //TextEditingController? _dataToSendText;
  bool scanning = false;
  bool connected = false;
  bool _tindeq = false;

  int _currentCalculatedTimeMillis = 0;
  List<double> _prevPrevPoint = [0, 0, 0, 0, 0, 0, 0, 0];
  List<double> _prevPoint = [0, 0, 0, 0, 0, 0, 0, 0];
  List<List<double>> aggregateData = [];
  int lastMillisAggregate = 0;
  int targetMillis = 1000;

  int? lastMillisTindeq;

  void _onNewReceivedDataTindeq(List<int> data) {
    Uint8List bytes = Uint8List.fromList(data);
    ByteData byteData = ByteData.sublistView(bytes);

    if (byteData.getInt8(0) == tindeqResponseCodes["weight_measure"]) {
      //float and long come along
      for (int i = 2; i + 7 < data.length; i += 8) {
        double weight = byteData.getFloat32(i, Endian.little);
        int milliTime = byteData.getInt32(i + 4, Endian.little) ~/ 1000;

        if (lastMillisTindeq == null) {
          lastMillisTindeq = milliTime;
          return;
        }

        int time = milliTime - lastMillisTindeq!;
        lastMillisTindeq = milliTime;

        Uint8List bytesToSend = Uint8List(36);
        ByteData dataToSend = ByteData.sublistView(bytesToSend);
        dataToSend.setInt32(0, time, Endian.little);
        dataToSend.setInt32(4, (weight * 1000).toInt(), Endian.little);
        //rest of sensors stay @ 0
        //AppCtrl.logDataListener.value = "Parsed ${data}";
        AppCtrl.logDataListener.value = "Parsed ${weight} @ ${time}";

        _onNewReceivedDataOctoplus(bytesToSend);
      }
    }
  }

  void _onNewReceivedDataOctoplus(List<int> data) {
    // Unpack the data
    int millisDelta =
        (data[3] << 24) | (data[2] << 16) | (data[1] << 8) | (data[0]);
    List<double> dataAsDouble = [];
    for (int i = 1; i < 9; i++) {
      int rawData = (data[i * 4 + 3] << 24) |
          (data[i * 4 + 2] << 16) |
          (data[i * 4 + 1] << 8) |
          (data[i * 4 + 0]);
      int rawDataSigned = rawData.toSigned(32);
      dataAsDouble.add(rawDataSigned.toDouble() / 1000.0);
    }

    // Filter every three raw values and get the median point, avoiding
    // unwanted spikes that might arise from capture errors
    List<double> medianPoint = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    for (int i = 0; i < 8; i++) {
      if (_prevPrevPoint[i] <= _prevPoint[i] &&
          _prevPoint[i] <= dataAsDouble[i]) {
        medianPoint[i] = _prevPoint[i];
      } else if (_prevPoint[i] <= _prevPrevPoint[i] &&
          _prevPrevPoint[i] < dataAsDouble[i]) {
        medianPoint[i] = _prevPrevPoint[i];
      } else {
        medianPoint[i] = dataAsDouble[i];
      }
    }
    _prevPrevPoint = _prevPoint;
    _prevPoint = dataAsDouble;

    // Aggregate data to control data rate within the app regardless of data
    // capture rate
    aggregateData.add(medianPoint);
    lastMillisAggregate += millisDelta;
    int diffHigh = lastMillisAggregate + millisDelta - targetMillis;
    // whenever next sample aggregated would lower sample rate, push update
    if (diffHigh >= 0) {
      // send only if the data service is running
      if (AppCtrl.dataServiceRunningListener.value) {
        // the time of update is the time of the last sample, this way we ensure
        // that the total time added is coherent with the received data. Calculating
        // averages would result in time drift
        _currentCalculatedTimeMillis += lastMillisAggregate;
        AppCtrl.lastUpdateTimeSeconds = _currentCalculatedTimeMillis / 1000.0;
        // if we are indeed aggregating data (more than 1 sample), just calculate
        // the average.
        if (aggregateData.length > 1) {
          medianPoint = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
          for (List<double> point in aggregateData) {
            for (int i = 0; i < 8; i++) {
              medianPoint[i] += point[i];
            }
          }
          for (int i = 0; i < 8; i++) {
            medianPoint[i] /= aggregateData.length;
          }
        } else {
          medianPoint = aggregateData[0];
        }

        // update listeners
        AppCtrl.leftPinkyValListener.value = medianPoint[0];
        AppCtrl.leftRingValListener.value = medianPoint[1];
        AppCtrl.leftMiddleValListener.value = medianPoint[2];
        AppCtrl.leftPointerValListener.value = medianPoint[3];
        AppCtrl.rightPointerValListener.value = medianPoint[4];
        AppCtrl.rightMiddleValListener.value = medianPoint[5];
        AppCtrl.rightRingValListener.value = medianPoint[6];
        AppCtrl.rightPinkyValListener.value = medianPoint[7];

        medianPoint[8] =
            medianPoint[0] + medianPoint[1] + medianPoint[2] + medianPoint[3];
        medianPoint[9] =
            medianPoint[4] + medianPoint[5] + medianPoint[6] + medianPoint[7];
        medianPoint[10] = medianPoint[9] + medianPoint[8];

        AppCtrl.leftHandValListener.value = medianPoint[8];
        AppCtrl.rightHandValListener.value = medianPoint[9];
        AppCtrl.totalWeightValListener.value = medianPoint[10];

        AppCtrl.newDataListener.value = medianPoint;
      }

      // reset aggregation data after each update trigger, regardless of
      // data service state
      lastMillisAggregate = 0;
      aggregateData = [];
    }
  }

  void sendDataRaw(int? value) async {
    AppCtrl.logDataListener.value = "Written $value";
    if (value == null) return;
    if (connected) {
      await flutterReactiveBle
          .writeCharacteristicWithResponse(_rxCharacteristic!, value: [value]);
    }
  }

  void sendData(String data) async {
    if (connected && !_tindeq) {
      //avoid sending unwanted data
      await flutterReactiveBle.writeCharacteristicWithResponse(
          _rxCharacteristic!,
          value: data.codeUnits);
    }
  }

  void disconnect() async {
    await _connection!.cancel();
    connected = false;
  }

  void startScan() async {
    //TODO replace True with permission == PermissionStatus.granted is for IOS test
    AppCtrl.logDataListener.value = "Start scan!";
    scanning = true;
    _scanStream =
        flutterReactiveBle.scanForDevices(withServices: []).listen((device) {
      AppCtrl.logDataListener.value = "Device ${device.id} found!";
      if (device.name == targetNameOctoplus) {
        AppCtrl.logDataListener.value =
            "$targetNameOctoplus device ${device.id} found!";
        _stopScanAndConnectOctoplus(device);
        _tindeq = false;
      } else if (device.name
          .toLowerCase()
          .contains(targetNameProgressor.toLowerCase())) {
        AppCtrl.logDataListener.value =
            "$targetNameProgressor device ${device.id} found!";
        _stopScanAndConnectProgressor(device);
        _tindeq = true;
      } /*else if (device.name
          .toLowerCase()
          .contains(targetNameGripMeter.toLowerCase())) {
        AppCtrl.logDataListener.value =
            "$targetNameGripMeter device ${device.id} found!";
        _stopScanAndConnectProgressor(device);
        _tindeq = true;
      }*/
      else {
        AppCtrl.logDataListener.value =
            "Device ${device.id}:${device.name} found!";
      }
    }, onError: (Object error) {
      AppCtrl.logDataListener.value = "ERROR while scanning:$error";
    });
  }

  void _stopScanAndConnectOctoplus(DiscoveredDevice device) async {
    await stopScan();
    _onConnectOctoplus(device);
  }

  void _stopScanAndConnectProgressor(DiscoveredDevice device) async {
    await stopScan();
    _onConnectProgressor(device);
  }

  Future<void> stopScan() async {
    AppCtrl.logDataListener.value = "Stopping scan!";
    await _scanStream!.cancel();
    scanning = false;
  }

  void _onConnectOctoplus(DiscoveredDevice device) {
    flutterReactiveBle.requestMtu(deviceId: device.id, mtu: 64);
    _currentConnectionStream = flutterReactiveBle.connectToAdvertisingDevice(
      id: device.id,
      prescanDuration: const Duration(seconds: 1),
      withServices: [octoplusUartUUID, octoplusUartRX, octoplusUartTX],
    );
    _connection = _currentConnectionStream!.listen((event) {
      var id = event.deviceId.toString();
      switch (event.connectionState) {
        case DeviceConnectionState.connecting:
          {
            AppCtrl.logDataListener.value = "Connecting to $id";
            break;
          }
        case DeviceConnectionState.connected:
          {
            connected = true;
            AppCtrl.logDataListener.value = "Connected to $id";
            _txCharacteristic = QualifiedCharacteristic(
                serviceId: octoplusUartUUID,
                characteristicId: octoplusUartTX,
                deviceId: event.deviceId);
            _receivedDataStream = flutterReactiveBle
                .subscribeToCharacteristic(_txCharacteristic!);
            _receivedDataStream!.listen((data) {
              _onNewReceivedDataOctoplus(data);
            }, onError: (dynamic error) {
              AppCtrl.logDataListener.value = "Error:$error$id";
            });
            _rxCharacteristic = QualifiedCharacteristic(
                serviceId: octoplusUartUUID,
                characteristicId: octoplusUartRX,
                deviceId: event.deviceId);
            break;
          }
        case DeviceConnectionState.disconnecting:
          {
            connected = false;
            AppCtrl.logDataListener.value = "Disconnecting from $id";
            break;
          }
        case DeviceConnectionState.disconnected:
          {
            AppCtrl.logDataListener.value = "Disconnected from $id";
            break;
          }
      }
    });
  }

  void _onConnectProgressor(DiscoveredDevice device) {
    flutterReactiveBle.requestMtu(deviceId: device.id, mtu: 64);
    _currentConnectionStream = flutterReactiveBle.connectToAdvertisingDevice(
      id: device.id,
      prescanDuration: const Duration(seconds: 1),
      withServices: [tindeqServiceUUID, tindeqNotifyUUID, tindeqWriteUUID],
    );
    _connection = _currentConnectionStream!.listen((event) {
      var id = event.deviceId.toString();
      switch (event.connectionState) {
        case DeviceConnectionState.connecting:
          {
            AppCtrl.logDataListener.value = "Connecting to $id";
            break;
          }
        case DeviceConnectionState.connected:
          {
            connected = true;
            AppCtrl.logDataListener.value = "Connected to $id";
            _txCharacteristic = QualifiedCharacteristic(
                serviceId: tindeqServiceUUID,
                characteristicId: tindeqNotifyUUID,
                deviceId: event.deviceId);
            _receivedDataStream = flutterReactiveBle
                .subscribeToCharacteristic(_txCharacteristic!);
            _receivedDataStream!.listen((data) {
              _onNewReceivedDataTindeq(data);
            }, onError: (dynamic error) {
              AppCtrl.logDataListener.value = "Error:$error$id";
            });
            _rxCharacteristic = QualifiedCharacteristic(
                serviceId: tindeqServiceUUID,
                characteristicId: tindeqWriteUUID,
                deviceId: event.deviceId);
            break;
          }
        case DeviceConnectionState.disconnecting:
          {
            connected = false;
            AppCtrl.logDataListener.value = "Disconnecting from $id";
            break;
          }
        case DeviceConnectionState.disconnected:
          {
            AppCtrl.logDataListener.value = "Disconnected from $id";
            break;
          }
      }
    });
  }
}

class BluetoothButton extends StatefulWidget {
  const BluetoothButton({super.key});

  @override
  State<BluetoothButton> createState() {
    return BluetoothButtonState();
  }
}

class BluetoothButtonState extends State<BluetoothButton> {
  Future<void> showNoPermissionDialog() async => showDialog<void>(
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

  void _startScan() async {
    bool goForIt = await checkAndroidBLEPermissions();

    if (goForIt) {
      BluetoothController().startScan();
      setState(() {});
    } else {
      await showNoPermissionDialog();
    }
  }

  @override
  void initState() {
    //shit hack to update the bluetooth button
    AppCtrl.logDataListener.addListener(() {
      setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        if (!BluetoothController().connected) {
          if (!BluetoothController().scanning) {
            _startScan();
          }
          if (BluetoothController().scanning) {
            BluetoothController().stopScan();
          }
        } else {
          BluetoothController().disconnect();
        }
        setState(() {});
      },
      color: BluetoothController().scanning
          ? (BluetoothController().connected ? Colors.yellow : Colors.blue)
          : (BluetoothController().connected ? Colors.green : Colors.grey),
      icon: BluetoothController().scanning
          ? (BluetoothController().connected
              ? const Icon(Icons.play_arrow)
              : const Icon(Icons.bluetooth_searching))
          : (BluetoothController().connected
              ? const Icon(Icons.bluetooth_connected)
              : const Icon(Icons.bluetooth)),
    );
  }
}

//PROBLEMS
//after reaching 300s, it takes too much time to update the inner data.
//better to just flush periodically? dunno or use a linked list or sometin

class PlayButton extends StatefulWidget {
  const PlayButton({super.key});

  @override
  State<PlayButton> createState() {
    return PlayButtonState();
  }
}

class PlayButtonState extends State<PlayButton> {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        setState(() {
          AppCtrl.dataServiceRunningListener.value =
              !AppCtrl.dataServiceRunningListener.value;
        });
      },
      color:
          AppCtrl.dataServiceRunningListener.value ? Colors.green : Colors.grey,
      icon: Icon(AppCtrl.dataServiceRunningListener.value
          ? Icons.pause
          : Icons.play_arrow),
    );
  }
}

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
