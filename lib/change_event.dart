import 'package:json_annotation/json_annotation.dart';

part 'change_event.g.dart';

@JsonSerializable()
class ChangeEvent {
  final String eventData;
  final int eventPosition;

  ChangeEvent(this.eventData, this.eventPosition);

  factory ChangeEvent.fromJson(Map<String, dynamic> json) => _$ChangeEventFromJson(json);

  Map<String, dynamic> toJson() => _$ChangeEventToJson(this);
}