import 'package:intl/intl.dart';

class ProjectLead {
  final String id;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String rawTranscript;
  final String buildingType;
  final String architectName;
  final String phoneNumber;
  final String companyName;
  final String notes;
  final String address;
  final bool isManual;

  ProjectLead({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.rawTranscript = '',
    this.buildingType = '',
    this.architectName = '',
    this.phoneNumber = '',
    this.companyName = '',
    this.notes = '',
    this.address = '',
    this.isManual = false,
  });

  String get formattedDate =>
      DateFormat('MMM dd, yyyy – HH:mm').format(timestamp);

  String get shortDate => DateFormat('dd/MM/yy HH:mm').format(timestamp);

  String get coordsString =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  String get title {
    if (buildingType.isNotEmpty) return buildingType;
    if (architectName.isNotEmpty) return architectName;
    if (companyName.isNotEmpty) return companyName;
    if (address.isNotEmpty) return address;
    return 'Lead – $shortDate';
  }

  String get subtitle {
    final parts = <String>[];
    if (architectName.isNotEmpty) parts.add(architectName);
    if (companyName.isNotEmpty) parts.add(companyName);
    if (phoneNumber.isNotEmpty) parts.add(phoneNumber);
    if (parts.isEmpty) parts.add(coordsString);
    return parts.join(' · ');
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
        'rawTranscript': rawTranscript,
        'buildingType': buildingType,
        'architectName': architectName,
        'phoneNumber': phoneNumber,
        'companyName': companyName,
        'notes': notes,
        'address': address,
        'isManual': isManual ? 1 : 0,
      };

  factory ProjectLead.fromMap(Map<String, dynamic> map) => ProjectLead(
        id: map['id'],
        latitude: map['latitude'],
        longitude: map['longitude'],
        timestamp: DateTime.parse(map['timestamp']),
        rawTranscript: map['rawTranscript'] ?? '',
        buildingType: map['buildingType'] ?? '',
        architectName: map['architectName'] ?? '',
        phoneNumber: map['phoneNumber'] ?? '',
        companyName: map['companyName'] ?? '',
        notes: map['notes'] ?? '',
        address: map['address'] ?? '',
        isManual: (map['isManual'] ?? 0) == 1,
      );

  ProjectLead copyWith({
    String? id,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    String? rawTranscript,
    String? buildingType,
    String? architectName,
    String? phoneNumber,
    String? companyName,
    String? notes,
    String? address,
    bool? isManual,
  }) =>
      ProjectLead(
        id: id ?? this.id,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        timestamp: timestamp ?? this.timestamp,
        rawTranscript: rawTranscript ?? this.rawTranscript,
        buildingType: buildingType ?? this.buildingType,
        architectName: architectName ?? this.architectName,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        companyName: companyName ?? this.companyName,
        notes: notes ?? this.notes,
        address: address ?? this.address,
        isManual: isManual ?? this.isManual,
      );

  // CSV row: id, date, lat, lng, buildingType, architect, phone, company, notes, address, raw
  List<String> toCsvRow() => [
        id,
        formattedDate,
        latitude.toStringAsFixed(8),
        longitude.toStringAsFixed(8),
        buildingType,
        architectName,
        phoneNumber,
        companyName,
        notes,
        address,
        rawTranscript,
        isManual ? 'Manual' : 'Voice',
      ];

  static List<String> csvHeaders() => [
        'ID',
        'Date/Time',
        'Latitude',
        'Longitude',
        'Building Type',
        'Architect / Contact Name',
        'Phone Number',
        'Company',
        'Notes',
        'Address',
        'Raw Transcript',
        'Entry Method',
      ];
}
