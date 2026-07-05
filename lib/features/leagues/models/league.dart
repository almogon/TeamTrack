class League {
  const League({
    required this.id,
    required this.name,
    required this.city,
    required this.zipCode,
    required this.season,
    required this.status,
    this.createdBy,
    this.validatedBy,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String city;
  final String zipCode;
  final String season;
  final String status; // pending | active | finished
  final String? createdBy;
  final String? validatedBy;
  final DateTime createdAt;

  bool get isPending => status == 'pending';
  bool get isActive => status == 'active';
  bool get isFinished => status == 'finished';

  factory League.fromJson(Map<String, dynamic> json) => League(
        id: json['id'] as String,
        name: json['name'] as String,
        city: json['city'] as String,
        zipCode: json['zip_code'] as String,
        season: json['season'] as String,
        status: json['status'] as String? ?? 'pending',
        createdBy: json['created_by'] as String?,
        validatedBy: json['validated_by'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
