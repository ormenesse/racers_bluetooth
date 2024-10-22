import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:developer';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
  ]);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Slider Bluetooth App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SliderBluetoothScreen(),
    );
  }
}

class SliderBluetoothScreen extends StatefulWidget {
  @override
  _SliderBluetoothScreenState createState() => _SliderBluetoothScreenState();
}

class _SliderBluetoothScreenState extends State<SliderBluetoothScreen> {
  FlutterBluePlus flutterBlue = FlutterBluePlus();
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? writeCharacteristic;
  double horizontalValue = 0.5;
  double verticalValue = 0;
  double defaultHorizontalValue = 0.5;
  double defaultVerticalValue = 0;
  Timer? timer;
  Timer? _resetTimerHorizontal;
  Timer? _resetTimerVertical;
  List<BluetoothDevice> scannedDevices = [];

  @override
  void initState() {
    super.initState();
    startBluetooth();
    startSendingData();
  }

  @override
  void dispose() {
    timer?.cancel();
    connectedDevice?.disconnect();
    super.dispose();
  }

  Future<void> startBluetooth() async {
    //FlutterBluePlus.startScan(timeout: Duration(seconds: 4));
    List<BluetoothDevice> connectedDevices =
        await FlutterBluePlus.connectedDevices;
    print("connected devices: " + connectedDevices.toString());
    setState(() {
      scannedDevices.addAll(connectedDevices);
    });
    print("INICIANDO A RODADA DE BLUETOOTH");
    await FlutterBluePlus.turnOn();
    print("SCAN DE BLUETOOTH");
    await FlutterBluePlus.startScan(
        timeout: Duration(seconds: 4), androidUsesFineLocation: true);
    print("TERMINOU SCAN");
    FlutterBluePlus.scanResults.listen((results) {
      // setState(() {
      //   scannedDevices = results.map((r) => r.device).toList();
      // });
      setState(() {
        scannedDevices.addAll(results.map((r) => r.device));
      });
    });
    setState(() {
      scannedDevices = scannedDevices.toSet().toList();
    });
    print("DISPOSITIVOS ESCANEADOS:" + scannedDevices.toString());
  }

  void connectToDevice(BluetoothDevice device) async {
    await device.connect();
    setState(() {
      connectedDevice = device;
    });

    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.write) {
          setState(() {
            writeCharacteristic = characteristic;
          });
        }
      }
    }
  }

  void disconnectToDevice() async {
    await connectedDevice?.disconnect();
  }

  void startSendingData() {
    timer = Timer.periodic(Duration(milliseconds: 12), (Timer t) {
      sendData();
    });
  }

  void sendData() async {
    if (writeCharacteristic != null) {
      List<int> data = [
        (horizontalValue * 255).toInt(),
        (verticalValue * 255).toInt(),
      ];
      print('data sent:' + data.toString());
      data = utf8.encode(data.toString());
      await writeCharacteristic?.write(data);
    }
  }

  Future<void> showDeviceSelectionDialog() async {
    await startBluetooth();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select Bluetooth Device'),
          content: Container(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: scannedDevices.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(scannedDevices[index].platformName.isNotEmpty
                      ? scannedDevices[index].platformName
                      : scannedDevices[index].remoteId.toString()),
                  onTap: () {
                    Navigator.pop(context);
                    connectToDevice(scannedDevices[index]);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double ScreenHeight = MediaQuery.of(context).size.height * 0.5;

    return Scaffold(
      appBar: AppBar(
        title: Text('Carrinho de controle remoto'),
        actions: [
          IconButton(
            icon: Icon(Icons.bluetooth),
            onPressed: showDeviceSelectionDialog,
          ),
          IconButton(
              onPressed: disconnectToDevice,
              icon: Icon(Icons.bluetooth_disabled))
        ],
      ),
      body: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Slider(
              activeColor: const Color.fromARGB(0, 155, 39, 176),
              inactiveColor: const Color.fromARGB(0, 225, 190, 231),
              value: horizontalValue,
              onChanged: _onSliderChanged,
              onChangeStart: _onSliderChangedStart,
              onChangeEnd: _onSliderChangedEnd,
              min: 0,
              max: 1,
            ),
          ),
          Container(
            height:
                ScreenHeight, // Limit the vertical slider to 50% of the screen height
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: RotatedBox(
                quarterTurns: 3,
                child: Slider(
                  activeColor: const Color.fromARGB(0, 155, 39, 176),
                  inactiveColor: const Color.fromARGB(0, 225, 190, 231),
                  value: verticalValue,
                  onChanged: _onSliderChangedV,
                  onChangeStart: _onSliderChangedStartV,
                  onChangeEnd: _onSliderChangedEndV,
                  min: 0,
                  max: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onSliderChangedStart(double value) {
    _resetTimerHorizontal?.cancel();
  }

  void _onSliderChanged(double value) {
    setState(() {
      horizontalValue = value;
    });
  }

  void _onSliderChangedEnd(double value) {
    _startResetTimerHorizontal();
  }

  void _startResetTimerHorizontal() {
    _resetTimerHorizontal?.cancel();
    _resetTimerHorizontal = Timer.periodic(Duration(milliseconds: 10), (timer) {
      setState(() {
        if (horizontalValue > defaultHorizontalValue) {
          horizontalValue -= 0.01;
        } else if (horizontalValue < defaultHorizontalValue) {
          horizontalValue += 0.01;
        }
        if ((horizontalValue - defaultHorizontalValue).abs() <= 0.01) {
          horizontalValue = defaultHorizontalValue;
          _resetTimerHorizontal?.cancel();
        }
      });
    });
  }

  void _onSliderChangedStartV(double value) {
    _resetTimerVertical?.cancel();
  }

  void _onSliderChangedV(double value) {
    setState(() {
      verticalValue = value;
    });
  }

  void _onSliderChangedEndV(double value) {
    _startResetTimerVertical();
  }

  void _startResetTimerVertical() {
    _resetTimerVertical?.cancel();
    _resetTimerVertical = Timer.periodic(Duration(milliseconds: 10), (timer) {
      setState(() {
        if (verticalValue > defaultVerticalValue) {
          verticalValue -= 0.01;
        } else if (verticalValue < defaultVerticalValue) {
          verticalValue += 0.01;
        }
        if ((verticalValue - defaultVerticalValue).abs() < 0.01) {
          verticalValue = defaultVerticalValue;
          _resetTimerVertical?.cancel();
        }
      });
    });
  }
}
