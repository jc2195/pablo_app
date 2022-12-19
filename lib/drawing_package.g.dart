// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drawing_package.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DrawingPackage _$DrawingPackageFromJson(Map<String, dynamic> json) {
  return DrawingPackage(
    (json['lines'] as List)
        ?.map((e) =>
            e == null ? null : DrawnLine.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    const ColorSerializer().fromJson(json['selectedColor'] as int),
    (json['selectedWidth'] as num)?.toDouble(),
    json['committedLines'] as int,
    (json['changeEvents'] as List)
        ?.map((e) =>
            e == null ? null : ChangeEvent.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    json['changeEventIndex'] as int,
    (json['streamCache'] as List)?.map((e) => e as String)?.toList(),
    (json['customColorPalette'] as List)
        ?.map((e) => const ColorSerializer().fromJson(e as int))
        ?.toList(),
    json['autoSaveEnabled'] as bool,
    (json['mmCanvasHeight'] as num)?.toDouble(),
    (json['mmCanvasWidth'] as num)?.toDouble(),
  );
}

Map<String, dynamic> _$DrawingPackageToJson(DrawingPackage instance) =>
    <String, dynamic>{
      'lines': instance.lines,
      'selectedColor': const ColorSerializer().toJson(instance.selectedColor),
      'selectedWidth': instance.selectedWidth,
      'committedLines': instance.committedLines,
      'changeEvents': instance.changeEvents,
      'changeEventIndex': instance.changeEventIndex,
      'streamCache': instance.streamCache,
      'autoSaveEnabled': instance.autoSaveEnabled,
      'mmCanvasHeight': instance.mmCanvasHeight,
      'mmCanvasWidth': instance.mmCanvasWidth,
      'customColorPalette': instance.customColorPalette
          ?.map(const ColorSerializer().toJson)
          ?.toList(),
    };
