import 'package:json_annotation/json_annotation.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

class PointSerializer implements JsonConverter<Point, Map> {
  const PointSerializer();

  @override
  Point fromJson(Map json) => Point(json['x'], json['y'], json['p']);

  @override
  Map toJson(Point point) => {'x': point.x, 'y': point.y, 'p': point.p};
}