class Destination {
  final String id;
  final String tripId;
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
      id: json['_id'] as String,
      tripId: json['tripId'] as String,
      country: json['country'] as String,
      arrivalDate: json['arrivalDate'] as String?,
      departureDate: json['departureDate'] as String?,
      notes: json['notes'] as String?,
    );
  }
}
