import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:rx_ble/rx_ble.dart';

int time() => DateTime.now().millisecondsSinceEpoch;

class YesNoDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Location Permission Required'),
      content: Text(
        "This app needs location permission in order to access Bluetooth.\n"
        "Continue?",
      ),
      actions: <Widget>[
        SimpleDialogOption(
          child: Text(
            "NO",
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          onPressed: () {
            Navigator.of(context).pop(false);
          },
        ),
        SimpleDialogOption(
          child: Text(
            "YES",
            style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
          onPressed: () {
            Navigator.of(context).pop(true);
          },
        )
      ],
    );
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  var returnValue;
  String deviceId;
  Exception returnError;
  final results = <String, ScanResult>{};
  var chars = Map<String, List<String>>();
  final uuidControl = TextEditingController();
  final mtuControl = TextEditingController();
  final writeCharValueControl = TextEditingController();
  final randomWriteNum = TextEditingController(text: '100');
  final randomWriteSize = TextEditingController(text: '100');
  var connectionState = BleConnectionState.disconnected;
  var isWorking = false;

  Function wrapCall(Function fn) {
    return () async {
      var value, error;
      setState(() {
        returnError = returnValue = null;
        isWorking = true;
      });
      try {
        value = await fn();
        print('returnValue: $value');
      } catch (e, trace) {
        print('returnError: $e\n$trace');
        error = e;
      } finally {
        if (mounted) {
          setState(() {
            isWorking = false;
            returnError = error;
            returnValue = value;
          });
        }
      }
    };
  }

  Future<void> requestAccessRationale() async {
    return await RxBle.requestAccess(
      showRationale: () async {
        return await showDialog(
              context: context,
              builder: (context) => YesNoDialog(),
            ) ??
            false;
      },
    );
  }

  Future<void> startScan() async {
    await for (final scanResult in RxBle.startScan()) {
      results[scanResult.rssi.toString()] = scanResult;
      print('${scanResult.deviceId.toString()} : ${scanResult.deviceName}');
      if (!mounted) return;
      setState(() {
        returnValue = JsonEncoder.withIndent(" " * 2, (o) {
          if (o is ScanResult) {
            return o.toString();
          } else {
            return o;
          }
        }).convert(results);
      });
    }
  }

  Future<String> discoverChars() async {
    final value = await RxBle.discoverChars(deviceId);
    if (!mounted) return null;
    setState(() {
      chars = value;
    });
    return JsonEncoder.withIndent(" " * 2).convert(chars);
  }

  Future<void> readChar() async {
    final value = await RxBle.readChar(deviceId, uuidControl.text);
    return value.toString() +
        "\n\n" +
        RxBle.charToString(value, allowMalformed: true);
  }

  Future<void> observeChar() async {
    var start = time();
    await for (final value in RxBle.observeChar(deviceId, uuidControl.text)) {
      final end = time();
      if (!mounted) return;
      setState(() {
        returnValue = value.toString() +
            "\n\n" +
            RxBle.charToString(value, allowMalformed: true) +
            "\n\nDelay: ${(end - start)} ms";
      });
      start = time();
    }
  }

  Future<void> writeChar() async {
    return await RxBle.writeChar(
      deviceId,
      uuidControl.text,
      RxBle.stringToChar(writeCharValueControl.text),
    );
  }

  Future<void> requestMtu() async {
    return await RxBle.requestMtu(deviceId, int.parse(mtuControl.text));
  }

  Future<void> randomWrite() async {
    final rand = new Random();
    final futures = List.generate(int.parse(randomWriteNum.text), (_) {
      return RxBle.writeChar(
        deviceId,
        uuidControl.text,
        Uint8List.fromList(
          List.generate(int.parse(randomWriteSize.text), (_) {
            return rand.nextInt(33) + 89;
          }),
        ),
      );
    });
    final start = time();
    await Future.wait(futures);
    final end = time();
    return "${end - start} ms";
  }

  Future<void> continuousRead() async {
    while (true) {
      final start = time();
      final value = await RxBle.readChar(deviceId, uuidControl.text);
      final end = time();
      if (!mounted) return;
      setState(() {
        returnValue = value.toString() +
            "\n\n" +
            RxBle.charToString(value, allowMalformed: true) +
            "\n\nDelay: ${start - end} ms";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 100.0),
                child: RaisedButton(
                  child: Text('Start Scanning'),
                  onPressed: wrapCall(startScan),
                ),
              ),
            ),
            Divider(),
            if (results.isEmpty) Text('Start scanning to connect to a device'),
            
            DetectedNotifier(results: results,),
              
            Divider(),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (isWorking) CircularProgressIndicator(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class DetectedNotifier extends StatefulWidget {
  final Map<String, ScanResult> results;

  DetectedNotifier({this.results});
  @override
  _DetectedNotifierState createState() => _DetectedNotifierState();
}

class _DetectedNotifierState extends State<DetectedNotifier> {

  List<String> strings = [];

  Widget checkConnection() {
    for (final scanResult in widget.results.values)
     if(scanResult.deviceName.toString() == 'Saru') {
       return Text('Device Found');
     }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: checkConnection(),
    );
  }
}