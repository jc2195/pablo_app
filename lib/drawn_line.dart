import 'package:drawing_app/point_data.dart';
import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:json_annotation/json_annotation.dart';
import 'dart:ui';
import 'color_serializer.dart';
import 'point_serializer.dart';

part 'drawn_line.g.dart';

@JsonSerializable()
class DrawnLine {
  @PointSerializer()
  final List<Point> path;

  final List<PointData> pointData;

  @ColorSerializer()
  final Color color;

  final double width;

  DrawnLine(this.path, this.pointData, this.color, this.width);

  factory DrawnLine.fromJson(Map<String, dynamic> json) => _$DrawnLineFromJson(json);

  Map<String, dynamic> toJson() => _$DrawnLineToJson(this);
}
