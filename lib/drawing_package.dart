import 'dart:ui';
import 'package:json_annotation/json_annotation.dart';
import 'change_event.dart';
import 'drawn_line.dart';
import 'color_serializer.dart';

part 'drawing_package.g.dart';

@JsonSerializable()
class DrawingPackage {
  final List<DrawnLine> lines;

  @ColorSerializer()
  final Color selectedColor;

  final double selectedWidth;
  final int committedLines;
  final List<ChangeEvent> changeEvents;
  final int changeEventIndex;
  final List<String> streamCache;
  final bool autoSaveEnabled;
  final double mmCanvasHeight;
  final double mmCanvasWidth;

  @ColorSerializer()
  final List<Color> customColorPalette;

  DrawingPackage(
      this.lines,
      this.selectedColor,
      this.selectedWidth,
      this.committedLines,
      this.changeEvents,
      this.changeEventIndex,
      this.streamCache,
      this.customColorPalette,
      this.autoSaveEnabled,
      this.mmCanvasHeight,
      this.mmCanvasWidth,
      );

  factory DrawingPackage.fromJson(Map<String, dynamic> json) => _$DrawingPackageFromJson(json);

  Map<String, dynamic> toJson() => _$DrawingPackageToJson(this);
}