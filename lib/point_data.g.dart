// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'point_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PointData _$PointDataFromJson(Map<String, dynamic> json) {
  return PointData(
    (json['mmCoordinates'] as List)
        ?.map((e) => (e as num)?.toDouble())
        ?.toList(),
    (json['velocity'] as num)?.toDouble(),
    (json['pressure'] as num)?.toDouble(),
  );
}

Map<String, dynamic> _$PointDataToJson(PointData instance) => <String, dynamic>{
      'mmCoordinates': instance.mmCoordinates,
      'velocity': instance.velocity,
      'pressure': instance.pressure,
    };
