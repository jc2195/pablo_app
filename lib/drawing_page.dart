import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drawing_app/change_event.dart';
import 'package:drawing_app/drawn_line.dart';
import 'package:drawing_app/menu_page.dart';
import 'package:drawing_app/point_data.dart';
import 'package:drawing_app/sketcher.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import 'drawing_package.dart';
import 'package:zoom_widget/zoom_widget.dart';
import 'package:http/http.dart' as http;

class DrawingPage extends StatefulWidget {
  String drawingUuid;
  bool hasSaveData;
  double mmCanvasHeight;
  double mmCanvasWidth;

  DrawingPage({inputUuid, name, mmCanvasHeight, mmCanvasWidth}) {
    if (inputUuid != null) {
      this.drawingUuid = inputUuid;
      this.hasSaveData = true;
      print(drawingUuid);
    } else {
      var uuid = DateTime.now();
      this.drawingUuid = uuid.toString();
      this.hasSaveData = false;
      this.drawingUuid = this.drawingUuid + '@' + name;
      this.mmCanvasHeight = mmCanvasHeight;
      this.mmCanvasWidth = mmCanvasWidth;
      print(this.drawingUuid);
    }
  }

  @override
  _DrawingPageState createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    load();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    awsWebsocketChannel.sink.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override void didChangeMetrics() {
    setState(() {
    });
  }

  GlobalKey _globalKey = new GlobalKey();
  List<DrawnLine> lines = <DrawnLine>[];
  DrawnLine line;
  List<PointData> points = [];
  Color selectedColor = Colors.black;
  double selectedWidth = 5.0;
  Offset lastPosition;
  double touchPressure = 1;
  VelocityTracker velocityTracker =
      VelocityTracker.withKind(PointerDeviceKind.stylus);
  double mmVelocity = 0;
  int committedLines = 0;
  bool isLive = false;
  List<ChangeEvent> changeEvents = [];
  int changeEventIndex = 0;
  List<String> streamCache = [];
  Color pickerColor = Colors.blue;
  List<Color> customColorPalette = [];
  bool autoSaveEnabled = true;
  bool awsEnabled = false;
  bool interactiveModeEnabled = false;
  double mmCanvasHeight = 210;
  double mmCanvasWidth = 297;
  TransformationController transformationController = TransformationController();
  double pixelCanvasWidth;
  double pixelCanvasHeight;
  double currentPixelWidth;
  double currentPixelHeight;

  final awsWebsocketChannel = WebSocketChannel.connect(
    Uri.parse('wss://9l7x3k4723.execute-api.eu-west-1.amazonaws.com/production'),
  );

  FlutterBlue flutterBlue = FlutterBlue.instance;
  var bluetoothCharacteristic;

  StreamController<List<DrawnLine>> linesStreamController =
      StreamController<List<DrawnLine>>.broadcast();
  StreamController<DrawnLine> currentLineStreamController =
      StreamController<DrawnLine>.broadcast();

  void makeBtConnection(d) async {
    await d.connect();
    List<BluetoothService> services = await d.discoverServices();
    var c;
    for (var service in services) {
      print(service);
      if (service.uuid == Guid("00000001-710e-4a5b-8d75-3e5b444bc3cf")) {
        var characteristics = service.characteristics;
        for (var characteristic in characteristics) {
          if (characteristic.uuid ==
              Guid("00000003-710e-4a5b-8d75-3e5b444bc3cf")) {
            c = characteristic;
          }
        }
      }
    }
    setState(() {
      bluetoothCharacteristic = c;
      makeToast("Bluetooth Connected");
    });
  }

  findPi() async {
    flutterBlue.startScan(timeout: Duration(seconds: 2));
    var deviceList = [];
    flutterBlue.scanResults.listen((results) {
      for (ScanResult r in results) {
        deviceList.add(r.device);
        print('${r.device.name} found! rssi: ${r.rssi}');
        if (r.device.name == "raspberrypi") {
          var d = r.device;
          flutterBlue.stopScan();
          print(d);
          makeBtConnection(d);
        }
      }
    });
    await Future.delayed(const Duration(seconds: 2));
    for (var device in deviceList) {
      if (device.name == "raspberrypi") {
        print(device);
        device.connect();
      }
    }
    return(deviceList);
  }

  void btToggle() async {
    if (bluetoothCharacteristic == null) {
      // var devices = await flutterBlue.connectedDevices;
      // var d;
      var d = await findPi();
      // print(devices);
      // for (var device in devices) {
      //   print(device);
      //   if (device.name == "raspberrypi") {
      //     d = device;
      //   }
      // }
      // await d.connect();
      List<BluetoothService> services = await d.discoverServices();
      var c;
      for (var service in services) {
        if (service.uuid == Guid("00000001-710e-4a5b-8d75-3e5b444bc3cf")) {
          var characteristics = service.characteristics;
          for (var characteristic in characteristics) {
            if (characteristic.uuid ==
                Guid("00000003-710e-4a5b-8d75-3e5b444bc3cf")) {
              c = characteristic;
            }
          }
        }
      }
      setState(() {
        bluetoothCharacteristic = c;
        makeToast("Bluetooth Connected");
      });
    } else {
      setState(() {
        bluetoothCharacteristic = null;
        makeToast("Bluetooth Disconnected");
      });
    }
  }

  Future<void> save() async {
    try {
      final drawingPackage = DrawingPackage(
          lines,
          selectedColor,
          selectedWidth,
          committedLines,
          changeEvents,
          changeEventIndex,
          streamCache,
          customColorPalette,
          autoSaveEnabled,
          mmCanvasHeight,
          mmCanvasWidth,
      );
      final drawingPackageJson = drawingPackage.toJson();
      final drawingPackageString = jsonEncode(drawingPackageJson);
      RenderRepaintBoundary boundary =
          _globalKey.currentContext.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage();
      ByteData byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData.buffer.asUint8List();
      final pathDirectory = await getApplicationDocumentsDirectory();
      final String path = pathDirectory.path;
      final Directory appDocDirFolder =
          Directory('$path/paintings/${widget.drawingUuid}');
      if (!(await appDocDirFolder.exists())) {
        await appDocDirFolder.create(recursive: true);
      }
      final imageFile =
          File('$path/paintings/${widget.drawingUuid}/thumbnail.png');
      await imageFile.writeAsBytes(pngBytes);
      final dataFile = File('$path/paintings/${widget.drawingUuid}/data.json');
      await dataFile.writeAsString(drawingPackageString);
      print("saved");
    } catch (e) {
      print(e);
    }
  }

  void autoSave() async {
    await new Future.delayed(const Duration(milliseconds : 500));
    if (autoSaveEnabled) {
      save();
    }
  }

  Future<void> exitWithSave() async {
    Navigator.pop(context);
    await save();
    Navigator.pop(context);
  }

  Future<void> load() async {
    if (widget.hasSaveData) {
      try {
        final pathDirectory = await getApplicationDocumentsDirectory();
        final String path = pathDirectory.path;
        final imageFile =
            File('$path/paintings/${widget.drawingUuid}/thumbnail.png');
        final imageContents = await imageFile.readAsBytes();
        final image = Image.memory(Uint8List.fromList(imageContents));
        final dataFile =
            File('$path/paintings/${widget.drawingUuid}/data.json');
        final dataContents = await dataFile.readAsString();
        final jsonDataContents = jsonDecode(dataContents);
        final drawingPackage = DrawingPackage.fromJson(jsonDataContents);
        var url = Uri.parse('https://ps9nil10u6.execute-api.eu-west-1.amazonaws.com/production');
        var response = await http.post(url, body: { "hello": "hi" });
        var decoded = jsonDecode(response.body);
        List<DrawnLine> decodedLines = decodeAwsData(decoded);
        setState(() {
          this.lines = drawingPackage.lines;
          this.selectedColor = drawingPackage.selectedColor;
          this.selectedWidth = drawingPackage.selectedWidth;
          this.committedLines = drawingPackage.committedLines;
          this.changeEvents = drawingPackage.changeEvents;
          this.changeEventIndex = drawingPackage.changeEventIndex;
          this.streamCache = drawingPackage.streamCache;
          this.customColorPalette = drawingPackage.customColorPalette;
          this.autoSaveEnabled = drawingPackage.autoSaveEnabled;
          this.mmCanvasHeight = drawingPackage.mmCanvasHeight;
          this.mmCanvasWidth = drawingPackage.mmCanvasWidth;
        });
        print('load complete');
      } catch (e) {
        print(e);
      }
    } else {
      setState(() {
        this.mmCanvasWidth = widget.mmCanvasWidth;
        this.mmCanvasHeight = widget.mmCanvasHeight;
      });
    }
  }

  void makeToast(message) {
    Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.TOP,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.black38,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  void changeLive() async {
    if (isLive) {
      makeToast("Live Mode Off");
    } else {
      makeToast("Live Mode On");
    }
    setState(() {
      isLive = !isLive;
    });
    autoSave();
  }

  List<double> offsetToMm(Offset offset) {
    // print([offset.dx, offset.dy]);
    double x = double.parse(((offset.dx/pixelCanvasWidth)*mmCanvasWidth).toStringAsFixed(3));
    double y = double.parse(((offset.dy/pixelCanvasHeight)*mmCanvasHeight).toStringAsFixed(3));
    List<double> result = [x, y];
    return (result);
  }

  List<double> mmToOffset(List<double> input) {
    final List<double> numberfied = [input[0], input[1]];
    final double x = ((numberfied[0]/mmCanvasWidth)*pixelCanvasWidth);
    final double y = ((numberfied[1]/mmCanvasHeight)*pixelCanvasHeight);
    final List<double> output = [x, y];
    return (output);
  }

  String mmToGcode(List mm) {
    var result = "G1 X${mm[0]} Y${mm[1]} Z0.000";
    return (result);
  }

  String mmToRaisedGcode(List mm) {
    var result = "G1 X${mm[0]} Y${mm[1]} Z5.000";
    return (result);
  }

  void changeLine(DrawnLine newLine) {
    line = newLine;
    if (isLive) {
      streamData(getOutputData(line.pointData.last));
    }
  }

  String getAwsData(PointData pointData) {
    return ("${pointData.mmCoordinates[0]} ${pointData.mmCoordinates[1]} ${pointData.pressure} ${pointData.velocity}");
  }

  String getAwsLine(DrawnLine line) {
    List<String> points = [];
    for (PointData pointData in line.pointData) {
      points.add(getAwsData(pointData));
    }
    Map<String, dynamic> data = {
      "color": getColorData(pickerColor),
      "size": getSizeData(selectedWidth),
      "data": jsonEncode(points)
    };
    Map<String, dynamic> unserialised = {
      "action": "sendLine",
      "data": jsonEncode(data)
    };
    String output = jsonEncode(unserialised);
    return(output);
  }

  List<DrawnLine> decodeAwsData(data) {
    List<DrawnLine> results = [];
    if (data.containsKey("LastEvaluatedKey")) {
      print('yay');
    } else {
      for (var line in data['Items']) {
        var decodedData = jsonDecode(line["data"]['S']);
        final Color color = decodeColorData(decodedData['color']);
        final double size = decodeSizeData(decodedData['size']);
        List<Point> path = [];
        List<PointData> pointData = [];
        for (var d in jsonDecode(decodedData["data"])) {
          d = d.split(" ");
          final List<double> mmCoordinates = [double.parse(d[0]), double.parse(d[1])];
          final double pressure = double.parse(d[2]);
          final double velocity = double.parse(d[3]);
          pointData.add(PointData(mmCoordinates, velocity, pressure));
          final List<double> locationData = mmToOffset(mmCoordinates);
          path.add(Point(locationData[0], locationData[1], pressure));
        }
        results.add(DrawnLine(path, pointData, color, size));
      }
    }
    return (results);
  }

  String getOutputData(PointData pointData) {
    String output = "${pointData.mmCoordinates[0]} ${pointData.mmCoordinates[1]} ${pointData.pressure} ${pointData.velocity}";
    return (output);
  }

  String getSizeData(double size) {
    return ("S $size");
  }

  double decodeSizeData(String input) {
    double output = double.parse(input.substring(2));
    return (output);
  }

  String getColorData(Color color) {
    String output = "C ${ColorToHex(color).toString().substring(6, 16)}";
    return (output);
  }

  Color decodeColorData(String input) {
    Color output = Color(int.parse(input.substring(2)));
    return (output);
  }

  String getMixData(Color color) {
    return ("M ${ColorToHex(color).toString().substring(6, 16)}");
  }

  String getStartData() {
    return ("L 0");
  }

  String getEndData() {
    return ("L 1");
  }

  void setColor(Color color) {
    setState(() {
      selectedColor = color;
    });
    autoSave();
    String colorData = getColorData(color);
    if (isLive) {
      streamData(colorData);
      streamLeftovers();
    } else {
      changeEvents.add(ChangeEvent(colorData, lines.length));
    }
  }

  Color invertColor(Color color) {
    final r = 255 - color.red;
    final g = 255 - color.green;
    final b = 255 - color.blue;

    return Color.fromARGB((color.opacity * 255).round(), r, g, b);
  }

  void setWidth(double width) {
    setState(() {
      selectedWidth = width;
    });
    autoSave();
    String sizeData = getSizeData(width);
    if (isLive) {
      streamData(sizeData);
      streamLeftovers();
    } else {
      changeEvents.add(ChangeEvent(sizeData, lines.length));
    }
  }

  List<int> charToDec(String chars) {
    List<int> result = [];
    for (var char = 0; char < chars.length; char++) {
      result.add(chars.codeUnitAt(char));
    }
    return (result);
  }

  void streamData(data) async {
    if (streamCache.length < 4) {
      streamCache.add(data);
    } else {
      final List<int> dataToSend = charToDec(streamCache[0] +
          "/" +
          streamCache[1] +
          "/" +
          streamCache[2] +
          "/" +
          streamCache[3] +
          "/" +
          data);
      streamCache = [];
      await bluetoothCharacteristic.write(dataToSend);
    }
  }

  void streamLeftovers() async {
    if (streamCache.length != 0) {
      String concatString = "";
      for (String s in streamCache) {
        if (concatString == "") {
          concatString += s;
        } else {
          concatString += ("/" + s);
        }
      }
      final List<int> dataToSend = charToDec(concatString);
      streamCache = [];
      await bluetoothCharacteristic.write(dataToSend);
    }
  }

  void sensePressure(PointerEvent pe, context) {
    touchPressure = double.parse((pe.pressure).toStringAsFixed(3));
    velocityTracker.addPosition(pe.timeStamp, pe.position);
    Velocity velocity = velocityTracker.getVelocity();
    mmVelocity = double.parse(
        (velocity.pixelsPerSecond.distance * (mmCanvasWidth/currentPixelWidth)).toStringAsFixed(3));
  }

  double provideWidth() {
    if (touchPressure < 2) {
      return (selectedWidth * touchPressure);
    } else {
      return (selectedWidth);
    }
  }

  Map<String, double> provideCanvasPixelDimensions(context) {
    final double deviceHeight = MediaQuery.of(context).size.height;
    final double deviceWidth = MediaQuery.of(context).size.width;
    final double deviceWhRatio = deviceWidth/deviceHeight;
    final double canvasWhRatio = mmCanvasWidth/mmCanvasHeight;
    double pixelHeight;
    double pixelWidth;
    if (canvasWhRatio > deviceWhRatio) {
      pixelWidth = deviceWidth;
      pixelHeight = deviceWidth/canvasWhRatio;
    } else {
      pixelHeight = deviceHeight;
      pixelWidth = deviceHeight*canvasWhRatio;
    }
    if (currentPixelWidth == null || currentPixelHeight == null) {
      setState(() {
        currentPixelWidth = pixelWidth;
        currentPixelHeight = pixelHeight;
        pixelCanvasWidth = pixelWidth;
        pixelCanvasHeight = pixelHeight;
      });
    }
    return({"x": pixelWidth, "y": pixelHeight});
  }

  openMenu(context) {
    Scaffold.of(context).openEndDrawer();
  }

  addColorToPalette(context) {
    Navigator.pop(context);
    if (customColorPalette.length < 10) {
      String mixData = getMixData(pickerColor);
      if (isLive) {
        streamData(mixData);
        streamLeftovers();
      } else {
        changeEvents.add(ChangeEvent(mixData, lines.length));
      }
      setState(() {
        customColorPalette.add(pickerColor);
      });
      autoSave();
    } else {
      makeToast("Color palette is full!");
    }
  }

  void showColorPicker() {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Pick a color"),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  ColorPicker(
                    pickerColor: pickerColor,
                    onColorChanged: (color) {
                      setState(() {
                        pickerColor = color;
                      });
                    },
                    paletteType: PaletteType.hueWheel,
                  ),
                  ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor:
                          MaterialStateProperty.all(Colors.blueAccent),
                    ),
                    child: const Text("Add to palette"),
                    onPressed: () {
                      addColorToPalette(context);
                    },
                  ),
                ],
              ),
            ),
          );
        });
  }

  void commitEventData(int currentPosition) {
    if (changeEventIndex < changeEvents.length &&
        changeEvents.length > 0 &&
        changeEvents[changeEventIndex].eventPosition == currentPosition) {
      while (changeEventIndex < changeEvents.length &&
          changeEvents[changeEventIndex].eventPosition == currentPosition) {
        streamData(changeEvents[changeEventIndex].eventData);
        changeEventIndex += 1;
      }
    }
  }

  void commit() async {
    if (committedLines == lines.length) {
      commitEventData(committedLines);
      streamLeftovers();
    }
    if (committedLines < lines.length) {
      int oldCommit = committedLines;
      committedLines = lines.length;
      for (int i = oldCommit; i < committedLines; i++) {
        commitEventData(i);
        streamData(getStartData());
        for (var point in lines[i].pointData) {
          streamData(getOutputData(point));
        }
        streamData(getEndData());
      }
      streamLeftovers();
      commitEventData(lines.length);
    }
    changeEventIndex = 0;
    changeEvents = [];
    makeToast("Committed painting");
  }

  void undo() {
    if (lines.length > committedLines) {
      autoSave();
      setState(() {
        line = null;
        lines = List.from(lines)..removeLast();
        linesStreamController.add(lines);
      });
    }
  }

  Future<void> clear() async {
    setState(() {
      lines = [];
      line = null;
      committedLines = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CupertinoColors.systemGrey3,
      endDrawer: Container(
        width: 150,
        child: Drawer(
          child: Stack(
            children: [
              buildStrokeToolbar(),
              buildColorToolbar(),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              transformationController: transformationController,
              onInteractionEnd: (details) {
                currentPixelWidth = transformationController.value.getMaxScaleOnAxis() * provideCanvasPixelDimensions(context)["x"];
                currentPixelHeight = transformationController.value.getMaxScaleOnAxis() * provideCanvasPixelDimensions(context)["y"];
                // print([currentPixelWidth, currentPixelHeight]);
              },
              boundaryMargin: const EdgeInsets.all(10000.0),
              minScale: 0.1,
              maxScale: 10,
              clipBehavior: Clip.none,
              scaleEnabled: true,
              alignPanAxis: false,
              panEnabled: false,
              child: Container(
                width: provideCanvasPixelDimensions(context)["x"],
                height: provideCanvasPixelDimensions(context)["y"],
                child: Stack(
                  children: [
                    buildAllPaths(context),
                    buildCurrentPath(context),
                  ],
                ),
              ),
            ),
          ),
          buildMenuBar(context),
          buildExitBar(context),
        ],
      ),
    );
  }

  Widget buildCurrentPath(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        sensePressure(_, context);
      },
      onPointerMove: (_) {
        sensePressure(_, context);
      },
      child: GestureDetector(
        onPanStart: interactiveModeEnabled ? null : onPanStart,
        onPanUpdate: interactiveModeEnabled ? null : onPanUpdate,
        onPanEnd: interactiveModeEnabled ? null : onPanEnd,
        child: RepaintBoundary(
          child: Container(
            padding: EdgeInsets.all(4.0),
            color: Colors.transparent,
            alignment: Alignment.topLeft,
            child: StreamBuilder<DrawnLine>(
              stream: currentLineStreamController.stream,
              builder: (context, snapshot) {
                return CustomPaint(
                  painter: Sketcher(
                    lines: [line],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget buildAllPaths(BuildContext context) {
    return RepaintBoundary(
      key: _globalKey,
      child: Container(
        // width: MediaQuery.of(context).size.width,
        // height: MediaQuery.of(context).size.height,
        color: Colors.white,
        padding: EdgeInsets.all(4.0),
        alignment: Alignment.topLeft,
        child: StreamBuilder<List<DrawnLine>>(
          stream: linesStreamController.stream,
          builder: (context, snapshot) {
            return CustomPaint(
              painter: Sketcher(
                lines: lines,
              ),
            );
          },
        ),
      ),
    );
  }

  void onPanStart(DragStartDetails details) {
    velocityTracker = VelocityTracker.withKind(PointerDeviceKind.stylus);
    RenderBox box = context.findRenderObject();
    Offset location = details.localPosition;
    if (isLive) {
      streamData(getStartData());
    }
    if (0 <= location.dy && location.dy <= pixelCanvasHeight && 0 <= location.dx && location.dx <= pixelCanvasWidth) {
      changeLine(DrawnLine(
          [Point(location.dx, location.dy, touchPressure)],
          [PointData(offsetToMm(location), mmVelocity, touchPressure)],
          selectedColor,
          selectedWidth));
    }
  }

  void onPanUpdate(DragUpdateDetails details) {
    RenderBox box = context.findRenderObject();
    Offset location = details.localPosition;
    if (0 <= location.dy && location.dy <= pixelCanvasHeight && 0 <= location.dx && location.dx <= pixelCanvasWidth) {
      Point point = Point(location.dx, location.dy, touchPressure);
      List<PointData> pointData = List.from(line.pointData)
        ..add(PointData(offsetToMm(location), mmVelocity, touchPressure));
      List<Point> path = List.from(line.path)..add(point);
      changeLine(DrawnLine(path, pointData, selectedColor, selectedWidth));
      currentLineStreamController.add(line);
    }
  }

  void onPanEnd(DragEndDetails details) {
    lines = List.from(lines)..add(line);

    linesStreamController.add(lines);
    autoSave();
    if (isLive) {
      committedLines = lines.length;
      streamData(getEndData());
      streamLeftovers();
    }
    if (awsEnabled) {
      // print(getAwsLine(line));
      String dataToSend = getAwsLine(line);
      awsWebsocketChannel.sink.add(dataToSend);
    }
  }

  Widget buildStrokeToolbar() {
    return Positioned(
      bottom: 40.0,
      right: 30.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          buildStrokeButton(5.0),
          buildStrokeButton(10.0),
          buildStrokeButton(15.0),
          buildStrokeButton(20.0),
        ],
      ),
    );
  }

  Widget buildStrokeButton(double strokeWidth) {
    return GestureDetector(
      onTap: () {
        setWidth(strokeWidth);
      },
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Container(
          width: selectedWidth == strokeWidth ? 82 : strokeWidth * 2,
          height: strokeWidth * 2,
          decoration: BoxDecoration(
              color: selectedColor, borderRadius: BorderRadius.circular(50.0)),
        ),
      ),
    );
  }

  Widget buildMenuBar(context) {
    return Builder(builder: (context) {
      return Positioned(
        top: 40.0,
        right: 20.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                children: [
                  buildMenuButton(context),
                  if (!isLive) ...[
                    Divider(
                      height: 10.0,
                    ),
                    buildUndoButton(),
                    Divider(
                      height: 10.0,
                    ),
                    buildCommitButton(),
                    Divider(
                      height: 10.0,
                    ),
                    if (!autoSaveEnabled) buildSaveButton(),
                    if (!autoSaveEnabled) Divider(height: 10.0,),
                    buildInteractiveModeButton(),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget buildExitBar(context) {
    return Builder(builder: (context) {
      return Positioned(
        top: 40.0,
        left: 20.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                children: [
                  buildExitButton(),
                  StreamBuilder(
                    stream: awsWebsocketChannel.stream,
                    builder: (context, snapshot) {
                      return Text(snapshot.hasData ? '${snapshot.data}' : '');
                    },
                  )
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget buildColorToolbar() {
    return Positioned(
      top: 40.0,
      right: 20.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          child: buildLiveButton(),
                          margin: EdgeInsets.only(right: 10),
                        ),
                        Divider(
                          height: 10.0,
                        ),
                        Container(
                          child: buildColorPickerButton(),
                          margin: EdgeInsets.only(right: 10),
                        ),
                        Divider(
                          height: 30.0,
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Container(
                          child: buildClearButton(),
                        ),
                        Divider(
                          height: 10.0,
                        ),
                        Container(
                          child: buildBtButton(),
                        ),
                        Divider(
                          height: 30.0,
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text("Autosave"),
                    buildAutoSaveSwitch(),
                    Text("Aws Enable"),
                    buildAwsSwitch(),
                  ],
                ),
                Divider(
                  height: 30.0,
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  for (var c in customColorPalette) buildColorButton(c),
                  for (var i = customColorPalette.length; i < 10; i++)
                    buildPlaceholderDot(),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  buildColorButton(Colors.red),
                  buildColorButton(Colors.deepOrange),
                  buildColorButton(Colors.yellow),
                  buildColorButton(Colors.green),
                  buildColorButton(Colors.blue),
                  buildColorButton(Colors.pink),
                  buildColorButton(Colors.deepPurple),
                  buildColorButton(Colors.white),
                  buildColorButton(Colors.blueGrey),
                  buildColorButton(Colors.black),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildColorButton(Color color) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: FloatingActionButton(
        mini: true,
        backgroundColor: color,
        child: Container(),
        onPressed: () {
          setColor(color);
        },
      ),
    );
  }

  Widget buildPlaceholderDot() {
    return Container(
      margin: EdgeInsets.all(20),
      height: 16,
      width: 16,
      decoration: BoxDecoration(
        gradient: RadialGradient(radius: 1, colors: [
          Colors.black45,
          Colors.black87,
        ], stops: [
          0.1,
          0.7
        ]),
        color: Colors.black38,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget buildColorPickerButton() {
    return GestureDetector(
      onTap: showColorPicker,
      child: CircleAvatar(
        child: Icon(
          Icons.color_lens,
          size: 20.0,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget buildMenuButton(context) {
    return GestureDetector(
      onTap: () {
        openMenu(context);
      },
      child: CircleAvatar(
        child: Icon(
          Icons.menu,
          size: 20.0,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget buildLiveButton() {
    return GestureDetector(
      onTap: changeLive,
      child: CircleAvatar(
        child: Icon(
          isLive ? Icons.play_arrow : Icons.stop,
          size: 20.0,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget buildBtButton() {
    return GestureDetector(
      onTap: btToggle,
      child: CircleAvatar(
        child: Icon(
          bluetoothCharacteristic == null
              ? Icons.bluetooth_disabled
              : Icons.bluetooth,
          size: 20.0,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget buildCommitButton() {
    return GestureDetector(
      onTap: commit,
      child: CircleAvatar(
        child: Icon(
          Icons.check,
          size: 20.0,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget buildSaveButton() {
    return GestureDetector(
      onTap: () {
        save();
        makeToast("Saved!");
      },
      child: CircleAvatar(
        child: Icon(
          Icons.save,
          size: 20.0,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget buildInteractiveModeButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          interactiveModeEnabled = !interactiveModeEnabled;
        });
      },
      child: CircleAvatar(
        backgroundColor: interactiveModeEnabled ? ThemeData.light().primaryColorDark : CupertinoColors.systemGrey2,
        child: Icon(
          Icons.zoom_out_map,
          size: 20.0,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget buildUndoButton() {
    return GestureDetector(
      onTap: undo,
      child: CircleAvatar(
        child: Icon(
          Icons.undo,
          size: 20.0,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget buildClearButton() {
    return GestureDetector(
      onTap: clear,
      child: CircleAvatar(
        child: Icon(
          Icons.delete,
          size: 20.0,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget buildExitButton() {
    return GestureDetector(
      onTapUp: (_) {
        if (autoSaveEnabled) {
          Navigator.pop(context);
        } else {
          showDialog<bool>(
            context: context,
            builder: (context) {
              return CupertinoAlertDialog(
                title: Text('Save?'),
                actions: <CupertinoDialogAction>[
                  CupertinoDialogAction(
                    child: const Text('No'),
                    isDestructiveAction: true,
                    isDefaultAction: false,
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                  ),
                  CupertinoDialogAction(
                    child: const Text('Yes'),
                    isDestructiveAction: false,
                    isDefaultAction: true,
                    onPressed: () {
                      exitWithSave();
                    },
                  )
                ],
              );
            },
          );
        }
      },
      child: CircleAvatar(
        child: Icon(
          Icons.close,
          size: 20.0,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget buildAutoSaveSwitch() {
    return MergeSemantics(
      child: GestureDetector(
        child: Container(
          child: Row(
            children: [
              CupertinoSwitch(
                value: autoSaveEnabled,
                onChanged: (bool value) { setState(() {
                  autoSaveEnabled = value;
                  save();
                }); },
              ),
            ],
          ),
        ),
        onTapUp: (_) { setState(() {
          autoSaveEnabled = !autoSaveEnabled;
        }); },
      ),
    );
  }

  Widget buildAwsSwitch() {
    return MergeSemantics(
      child: GestureDetector(
        child: Container(
          child: Row(
            children: [
              CupertinoSwitch(
                value: awsEnabled,
                onChanged: (bool value) { setState(() {
                  awsEnabled = value;
                }); },
              ),
            ],
          ),
        ),
        onTapUp: (_) { setState(() {
          awsEnabled = !awsEnabled;
        }); },
      ),
    );
  }
}
