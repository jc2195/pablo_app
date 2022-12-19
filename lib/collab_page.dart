import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drawing_app/change_event.dart';
import 'package:drawing_app/drawn_line.dart';
import 'package:drawing_app/point_data.dart';
import 'package:drawing_app/sketcher.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'drawing_package.dart';
import 'package:http/http.dart' as http;

class CollabPage extends StatefulWidget {
  double mmCanvasHeight;
  double mmCanvasWidth;
  List<DrawnLine> lines;

  CollabPage({lines, mmCanvasHeight, mmCanvasWidth}) {
    this.mmCanvasHeight = mmCanvasHeight;
    this.mmCanvasWidth = mmCanvasWidth;
    this.lines = lines;
  }

  @override
  _CollabPageState createState() => _CollabPageState();
}

class _CollabPageState extends State<CollabPage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    lines = widget.lines;
    committedLines = lines.length;
    load();
    WidgetsBinding.instance.addObserver(this);
    // WidgetsBinding.instance.addPostFrameCallback((_) => loadPixelBrushSizes());
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
  List<DrawnLine> lines;
  DrawnLine line;
  List<PointData> points = [];
  Color selectedColor = Colors.black;
  double selectedWidth = 4.5;
  Offset lastPosition;
  double touchPressure = 1;
  VelocityTracker velocityTracker =
  VelocityTracker.withKind(PointerDeviceKind.stylus);
  double mmVelocity = 0;
  int committedLines = 0;
  bool isLive = false;
  Color pickerColor = Colors.black;
  List<Color> customColorPalette = [];
  bool interactiveModeEnabled = false;
  bool autoSaveEnabled = true;
  double mmCanvasHeight = 750;
  double mmCanvasWidth = 600;
  TransformationController transformationController = TransformationController();
  double pixelCanvasWidth;
  double pixelCanvasHeight;
  double currentPixelWidth;
  double currentPixelHeight;
  String lastSeenLine;
  bool clearing = false;
  bool pointilism = false;
  Map<Color, String> colorTranslation = {
    Colors.redAccent[700]: "1",
    Colors.yellowAccent[200]: "2",
    Colors.green: "3",
    Colors.blue: "4",
    Colors.deepOrange[700]: "5",
    Colors.black: "6"
  };
  Map<double, String> sizeTranslation = {
    4.5: "1",
    8.5: "2",
    13.0: "3"
  };
  Map<double, double> mmToPixelTranslation = {
    6.0: 4.5,
    14.0: 8.5,
    22.0: 13.0
  };
  Map<double, double> actualToVisibleWidth = {
    4.5: 6.0,
    8.5: 14.0,
    13.0: 22.0
  };

  StreamController<List<DrawnLine>> linesStreamController =
  StreamController<List<DrawnLine>>.broadcast();
  StreamController<DrawnLine> currentLineStreamController =
  StreamController<DrawnLine>.broadcast();

  WebSocketChannel awsWebsocketChannel = WebSocketChannel.connect(
  Uri.parse('wss://9l7x3k4723.execute-api.eu-west-1.amazonaws.com/production'),
  );

  Future<void> save() async {
    // try {
    //   final drawingPackage = DrawingPackage(
    //     lines,
    //     selectedColor,
    //     selectedWidth,
    //     committedLines,
    //     changeEvents,
    //     changeEventIndex,
    //     streamCache,
    //     customColorPalette,
    //     autoSaveEnabled,
    //     mmCanvasHeight,
    //     mmCanvasWidth,
    //   );
    //   final drawingPackageJson = drawingPackage.toJson();
    //   final drawingPackageString = jsonEncode(drawingPackageJson);
    //   RenderRepaintBoundary boundary =
    //   _globalKey.currentContext.findRenderObject() as RenderRepaintBoundary;
    //   ui.Image image = await boundary.toImage();
    //   ByteData byteData =
    //   await image.toByteData(format: ui.ImageByteFormat.png);
    //   Uint8List pngBytes = byteData.buffer.asUint8List();
    //   final pathDirectory = await getApplicationDocumentsDirectory();
    //   final String path = pathDirectory.path;
    //   final Directory appDocDirFolder =
    //   Directory('$path/paintings/${widget.drawingUuid}');
    //   if (!(await appDocDirFolder.exists())) {
    //     await appDocDirFolder.create(recursive: true);
    //   }
    //   final imageFile =
    //   File('$path/paintings/${widget.drawingUuid}/thumbnail.png');
    //   await imageFile.writeAsBytes(pngBytes);
    //   final dataFile = File('$path/paintings/${widget.drawingUuid}/data.json');
    //   await dataFile.writeAsString(drawingPackageString);
    //   print("saved");
    // } catch (e) {
    //   print(e);
    // }
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

    // if (widget.hasSaveData) {
    //   try {
    //     final pathDirectory = await getApplicationDocumentsDirectory();
    //     final String path = pathDirectory.path;
    //     final imageFile =
    //     File('$path/paintings/${widget.drawingUuid}/thumbnail.png');
    //     final imageContents = await imageFile.readAsBytes();
    //     final image = Image.memory(Uint8List.fromList(imageContents));
    //     final dataFile =
    //     File('$path/paintings/${widget.drawingUuid}/data.json');
    //     final dataContents = await dataFile.readAsString();
    //     final jsonDataContents = jsonDecode(dataContents);
    //     final drawingPackage = DrawingPackage.fromJson(jsonDataContents);
    //     setState(() {
    //       this.lines = drawingPackage.lines;
    //       this.selectedColor = drawingPackage.selectedColor;
    //       this.selectedWidth = drawingPackage.selectedWidth;
    //       this.committedLines = drawingPackage.committedLines;
    //       this.changeEvents = drawingPackage.changeEvents;
    //       this.changeEventIndex = drawingPackage.changeEventIndex;
    //       this.streamCache = drawingPackage.streamCache;
    //       this.customColorPalette = drawingPackage.customColorPalette;
    //       this.autoSaveEnabled = drawingPackage.autoSaveEnabled;
    //       this.mmCanvasHeight = drawingPackage.mmCanvasHeight;
    //       this.mmCanvasWidth = drawingPackage.mmCanvasWidth;
    //     });
    //     print('local load complete');
    //   } catch (e) {
    //     print(e);
    //   }
    //   try {
    //
    //   } catch (e) {
    //     print(e);
    //   }
    // } else {
    //   setState(() {
    //     this.mmCanvasWidth = widget.mmCanvasWidth;
    //     this.mmCanvasHeight = widget.mmCanvasHeight;
    //     this.lines = widget.lines;
    //   });
    // }
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
      commit();
      makeToast("Live Mode On");
    }
    setState(() {
      isLive = !isLive;
    });
  }

  void togglePointilism() async {
    if (pointilism) {
      makeToast("Pointilism Mode Off");
    } else {
      makeToast("Pointilism Mode On");
    }
    setState(() {
      pointilism = !pointilism;
    });
  }

  void clearPainting() async {
    setState(() {
      clearing = true;
    });
    makeToast("Please wait, clearing painting...");
    var url = Uri.parse('https://ps9nil10u6.execute-api.eu-west-1.amazonaws.com/production');
    var response = await http.delete(url, body: { "hello": "hi" });
    print(response);
    Navigator.pop(context);
  }

  void loadPixelBrushSizes() {
    setState(() {
      mmToPixelTranslation[6.0] = (pixelCanvasWidth/mmCanvasWidth)*6.0;
      mmToPixelTranslation[14.0] = (pixelCanvasWidth/mmCanvasWidth)*14.0;
      mmToPixelTranslation[22.0] = (pixelCanvasWidth/mmCanvasWidth)*22.0;
    });
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
      "color": getColorData(line.color),
      "size": getSizeData(line.width),
      "pointilism": (pointilism ? 1 : 0),
      "data": jsonEncode(points)
    };
    Map<String, dynamic> unserialised = {
      "action": "sendLine",
      "data": jsonEncode(data)
    };
    String output = jsonEncode(unserialised);
    return(output);
  }

  void ingestAwsLine(String data) {
    DrawnLine result = getLocalLineFromAws(data);
    lines = List.from(lines)..add(result);
    linesStreamController.add(lines);
  }

  DrawnLine getLocalLineFromAws(response) {
    var decoded = jsonDecode(jsonDecode(response)['data']);
    // print(decoded);
    final Color color = decodeColorData(decoded['color']);
    final double size = decodeSizeData(decoded['size']);
    List<Point> path = [];
    List<PointData> pointData = [];
    for (var d in jsonDecode(decoded["data"])) {
      d = d.split(" ");
      final List<double> mmCoordinates = [double.parse(d[0]), double.parse(d[1])];
      final double pressure = double.parse(d[2]);
      final double velocity = double.parse(d[3]);
      pointData.add(PointData(mmCoordinates, velocity, pressure));
      final List<double> locationData = mmToOffset(mmCoordinates);
      path.add(Point(locationData[0], locationData[1], pressure));
    }
    return (DrawnLine(path, pointData, color, size));
  }

  String getOutputData(PointData pointData) {
    String output = "${pointData.mmCoordinates[0]} ${pointData.mmCoordinates[1]} ${pointData.pressure} ${pointData.velocity}";
    return (output);
  }

  String getSizeData(double size) {
    return ("${sizeTranslation[size]} $size");
  }

  double decodeSizeData(String input) {
    double output = double.parse(input.substring(2));
    return (output);
  }

  String getColorData(Color color) {
    String output = "${colorTranslation[color]} ${ColorToHex(color).toString().substring(6, 16)}";
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
  }

  List<int> charToDec(String chars) {
    List<int> result = [];
    for (var char = 0; char < chars.length; char++) {
      result.add(chars.codeUnitAt(char));
    }
    return (result);
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

  Future<void> exit() async {
    Navigator.pop(context);
    Navigator.pop(context);
  }

  addColorToPalette(context) {
    Navigator.pop(context);
    if (customColorPalette.length < 10) {
      setState(() {
        customColorPalette.add(pickerColor);
      });
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

  void commit() async {
    if (committedLines == lines.length) {
    }
    if (committedLines < lines.length) {
      int oldCommit = committedLines;
      committedLines = lines.length;
      for (int i = oldCommit; i < committedLines; i++) {
        commitLines(i);
      }
    }
    makeToast("Committed painting");
  }

  void commitLines(int index) {
    DrawnLine line = lines[index];
    String dataToSend = getAwsLine(line);
    print(dataToSend);
    awsWebsocketChannel.sink.add(dataToSend);
  }

  void undo() {
    if (lines.length > committedLines) {
      setState(() {
        line = null;
        lines = List.from(lines)..removeLast();
        linesStreamController.add(lines);
      });
    }
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
          if (clearing) ...[
            Center(
                child: CircularProgressIndicator()
            ),
          ] else ...[
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
          ]
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
      child: Listener(
        onPointerDown: interactiveModeEnabled ? null : onPanStart,
        onPointerMove: interactiveModeEnabled ? null : onPanUpdate,
        onPointerUp: interactiveModeEnabled ? null : onPanEnd,
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

  void onPanStart(PointerDownEvent details) {
    velocityTracker = VelocityTracker.withKind(PointerDeviceKind.stylus);
    RenderBox box = context.findRenderObject();
    Offset location = details.localPosition;
    if (0 <= location.dy && location.dy <= pixelCanvasHeight && 0 <= location.dx && location.dx <= pixelCanvasWidth) {
      changeLine(DrawnLine(
          [Point(location.dx, location.dy, touchPressure)],
          [PointData(offsetToMm(location), mmVelocity, touchPressure)],
          selectedColor,
          selectedWidth));
    }
  }

  void onPanUpdate(PointerMoveEvent details) {
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

  void onPanEnd(PointerUpEvent details) {
    lines = List.from(lines)..add(line);
    linesStreamController.add(lines);
    if (isLive) {
      committedLines = lines.length;
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
          buildStrokeButton(mmToPixelTranslation[6.0]),
          buildStrokeButton(mmToPixelTranslation[14.0]),
          buildStrokeButton(mmToPixelTranslation[22.0]),
        ],
      ),
    );
  }

  Widget buildStrokeButton(double strokeWidth) {
    return GestureDetector(
      onTap: () {
        print(strokeWidth);
        setWidth(strokeWidth);
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
        child: Row(
          children: [
            Container(
              width: selectedWidth == strokeWidth ? 60 : strokeWidth * 2,
              height: strokeWidth * 4,
              decoration: BoxDecoration(
                  color: selectedColor, borderRadius: BorderRadius.circular(50.0)),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text((actualToVisibleWidth[strokeWidth] < 10 ? " " : "") + actualToVisibleWidth[strokeWidth].toString()),
            )
          ],
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
                    buildClearButton(),
                    Divider(
                      height: 10.0,
                    ),
                    buildInteractiveModeButton(),
                  ] else ...[
                    Divider(
                      height: 10.0,
                    ),
                    buildClearButton(),
                    Divider(
                      height: 10.0,
                    ),
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
                      if (snapshot.hasData) {
                        ingestAwsLine(snapshot.data);
                      }
                      return Text(snapshot.hasData ? '' : '');
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
                          height: 10.0,
                        ),
                        Container(
                          child: buildTextureButton(),
                          margin: EdgeInsets.only(right: 10),
                        ),
                        Divider(
                          height: 30.0,
                        ),
                      ],
                    ),
                  ],
                ),
                Divider(
                  height: 150.0,
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
                  for (var i = customColorPalette.length; i < 6; i++)
                    buildPlaceholderDot(),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  buildColorButton(Colors.redAccent[700]),
                  // buildColorButton(Colors.deepOrange),
                  buildColorButton(Colors.yellowAccent[200]),
                  buildColorButton(Colors.green),
                  buildColorButton(Colors.blue),
                  // buildColorButton(Colors.pink),
                  buildColorButton(Colors.deepOrange[700]),
                  // buildColorButton(Colors.white),
                  // buildColorButton(Colors.blueGrey),
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

  Widget buildClearButton() {
    return GestureDetector(
      onTap: clearPainting,
      child: CircleAvatar(
        child: Icon(
          Icons.delete,
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

  Widget buildTextureButton() {
    return GestureDetector(
      onTap: togglePointilism,
      child: CircleAvatar(
        child: Icon(
          pointilism ? Icons.more_horiz : Icons.remove,
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
                      exit();
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
}