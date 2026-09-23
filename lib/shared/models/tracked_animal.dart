import 'package:equatable/equatable.dart';

/// A collared/tracked animal monitored for conflict risk.
class TrackedAnimal extends Equatable {
  const TrackedAnimal({
    required this.id,
    required this.code,
    required this.species,
    this.collarId,
  });

  final String id;
  final String code;
  final String species;
  final String? collarId;

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'species': species,
        'collarId': collarId,
      };

  factory TrackedAnimal.fromMap(Map<String, dynamic> map) => TrackedAnimal(
        id: map['id'] as String,
        code: map['code'] as String,
        species: map['species'] as String,
        collarId: map['collarId'] as String?,
      );

  @override
  List<Object?> get props => [id, code, species, collarId];
}
