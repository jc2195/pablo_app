import 'package:json_annotation/json_annotation.dart';

part 'point_data.g.dart';

@JsonSerializable()
class PointData {
  final List<double> mmCoordinates;
  final double velocity;
  final double pressure;

  PointData(this.mmCoordinates, this.velocity, this.pressure);

  factory PointData.fromJson(Map<String, dynamic> json) => _$PointDataFromJson(json);

  Map<String, dynamic> toJson() => _$PointDataToJson(this);
}