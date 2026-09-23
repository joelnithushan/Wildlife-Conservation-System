import 'package:equatable/equatable.dart';

/// A protected area / national park. Anchors most other records via `parkId`.
class Park extends Equatable {
  const Park({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  factory Park.fromMap(Map<String, dynamic> map) => Park(
        id: map['id'] as String,
        name: map['name'] as String,
      );

  @override
  List<Object?> get props => [id, name];
}
