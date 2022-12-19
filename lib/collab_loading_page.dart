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
import 'package:drawing_app/collab_page.dart';

class CollabLoadingPage extends StatefulWidget {

  @override
  _CollabLoadingPageState createState() => _CollabLoadingPageState();
}

class _CollabLoadingPageState extends State<CollabLoadingPage> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override void didChangeMetrics() {
    setState(() {});
  }

  bool loading = true;
  List<DrawnLine> lines = <DrawnLine>[];
  double mmCanvasWidth = 600;
  double mmCanvasHeight = 750;
  double pixelCanvasHeight;
  double pixelCanvasWidth;

  final awsWebsocketChannel = WebSocketChannel.connect(
    Uri.parse('wss://9l7x3k4723.execute-api.eu-west-1.amazonaws.com/production'),
  );

  void goToNextPage() {
    Navigator.pop(context);
    Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CollabPage(lines: lines, mmCanvasWidth: 600.0, mmCanvasHeight: 750.0,))
    );
  }

  Future<void> load() async {
      try {
        var pixelCanvasWidths = provideCanvasPixelDimensions();
        setState(() {
          this.pixelCanvasWidth = pixelCanvasWidths["x"];
          this.pixelCanvasHeight = pixelCanvasWidths["y"];
        });
        var url = Uri.parse('https://ps9nil10u6.execute-api.eu-west-1.amazonaws.com/production');
        List<DrawnLine> decodedLines = [];
        var lastKey;
        var response = await http.post(url, body: { "hello": "hi" });
        var decoded = jsonDecode(response.body);
        decodedLines.addAll(decodeAwsData(decoded));
        if (!decoded.containsKey("LastEvaluatedKey")) {
          lastKey = null;
        } else {
          lastKey = decoded["LastEvaluatedKey"];
        }
        while (lastKey != null) {
          response = await http.post(url, body: jsonEncode({
            "exclusiveStartKey": decoded["LastEvaluatedKey"]
          }));
          decoded = jsonDecode(response.body);
          if (decoded.containsKey("LastEvaluatedKey")) {
            lastKey = decoded["LastEvaluatedKey"];
          } else {
            lastKey = null;
          }
          decodedLines.addAll(decodeAwsData(decoded));
        }
        setState(() {
          this.lines = decodedLines;
        });
        goToNextPage();
      } catch (e) {
        print(e);
      }
  }

  List<double> mmToOffset(List<double> input) {
    final List<double> numberfied = [input[0], input[1]];
    final double x = ((numberfied[0]/mmCanvasWidth)*pixelCanvasWidth);
    final double y = ((numberfied[1]/mmCanvasHeight)*pixelCanvasHeight);
    final List<double> output = [x, y];
    return (output);
  }

  List<DrawnLine> decodeAwsData(data) {
    List<DrawnLine> results = [];
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
    return (results);
  }

  double decodeSizeData(String input) {
    double output = double.parse(input.substring(2));
    return (output);
  }

  Color decodeColorData(String input) {
    Color output = Color(int.parse(input.substring(2)));
    return (output);
  }

  Map<String, double> provideCanvasPixelDimensions() {
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
    return({"x": pixelWidth, "y": pixelHeight});
  }

  @override
  Widget build(BuildContext context) {
    // Future.delayed(Duration.zero, (){
    //   load();
    // });

    return Scaffold(
        body: Center(
          child: CircularProgressIndicator()
        ),
    );
  }
}