// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drawn_line.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DrawnLine _$DrawnLineFromJson(Map<String, dynamic> json) {
  return DrawnLine(
    (json['path'] as List)
        ?.map((e) => const PointSerializer().fromJson(e as Map))
        ?.toList(),
    (json['pointData'] as List)
        ?.map((e) =>
            e == null ? null : PointData.fromJson(e as Map<String, dynamic>))
        ?.toList(),
    const ColorSerializer().fromJson(json['color'] as int),
    (json['width'] as num)?.toDouble(),
  );
}

Map<String, dynamic> _$DrawnLineToJson(DrawnLine instance) => <String, dynamic>{
      'path': instance.path?.map(const PointSerializer().toJson)?.toList(),
      'pointData': instance.pointData,
      'color': const ColorSerializer().toJson(instance.color),
      'width': instance.width,
    };
