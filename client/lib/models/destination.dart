class Destination {
  final int id;
  final int tripId;
  final String country;
  final String? arrivalDate;
  final String? departureDate;
  final String? notes;

  const Destination({
    required this.id,
    required this.tripId,
    required this.country,
    this.arrivalDate,
    this.departureDate,
    this.notes,
  });

  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      id: json['id'] as int,
      tripId: json['tripId'] as int,
      country: json['country'] as String,
      arrivalDate: json['arrivalDate'] as String?,
      departureDate: json['departureDate'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

