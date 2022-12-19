// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'change_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChangeEvent _$ChangeEventFromJson(Map<String, dynamic> json) {
  return ChangeEvent(
    json['eventData'] as String,
    json['eventPosition'] as int,
  );
}

Map<String, dynamic> _$ChangeEventToJson(ChangeEvent instance) =>
    <String, dynamic>{
      'eventData': instance.eventData,
      'eventPosition': instance.eventPosition,
    };
