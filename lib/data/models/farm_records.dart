class ExpenseRecord {
  final String id;
  final String farmId;
  final String category;
  final double amount;
  final DateTime date;
  final String description;
  final String? vendor;
  final String? receiptPath;

  ExpenseRecord({
    required this.id,
    required this.farmId,
    required this.category,
    required this.amount,
    required this.date,
    required this.description,
    this.vendor,
    this.receiptPath,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'farmId': farmId, 'category': category,
    'amount': amount, 'date': date.toIso8601String(),
    'description': description, 'vendor': vendor, 'receiptPath': receiptPath,
  };

  factory ExpenseRecord.fromMap(Map<String, dynamic> m) => ExpenseRecord(
    id: m['id'] ?? '', farmId: m['farmId'] ?? '', category: m['category'] ?? '',
    amount: (m['amount'] ?? 0).toDouble(),
    date: m['date'] != null ? DateTime.parse(m['date']) : DateTime.now(),
    description: m['description'] ?? '', vendor: m['vendor'], receiptPath: m['receiptPath'],
  );

  ExpenseRecord copyWith({String? category, double? amount, DateTime? date, String? description, String? vendor, String? receiptPath}) =>
      ExpenseRecord(id: id, farmId: farmId, category: category ?? this.category,
          amount: amount ?? this.amount, date: date ?? this.date,
          description: description ?? this.description, vendor: vendor ?? this.vendor,
          receiptPath: receiptPath ?? this.receiptPath);
}

class PesticideRecord {
  final String id;
  final String farmId;
  final String productName;
  final DateTime date;
  final String quantity;
  final String applicationArea;
  final String purpose;
  final String? crop;
  final String? notes;

  PesticideRecord({
    required this.id, required this.farmId, required this.productName,
    required this.date, required this.quantity, required this.applicationArea,
    required this.purpose, this.crop, this.notes,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'farmId': farmId, 'productName': productName,
    'date': date.toIso8601String(), 'quantity': quantity,
    'applicationArea': applicationArea, 'purpose': purpose,
    'crop': crop, 'notes': notes,
  };

  factory PesticideRecord.fromMap(Map<String, dynamic> m) => PesticideRecord(
    id: m['id'] ?? '', farmId: m['farmId'] ?? '', productName: m['productName'] ?? '',
    date: m['date'] != null ? DateTime.parse(m['date']) : DateTime.now(),
    quantity: m['quantity'] ?? '', applicationArea: m['applicationArea'] ?? '',
    purpose: m['purpose'] ?? '', crop: m['crop'], notes: m['notes'],
  );
}

class FertilizerRecord {
  final String id;
  final String farmId;
  final String product;
  final String type;
  final String quantity;
  final DateTime date;
  final String application;
  final String? crop;

  FertilizerRecord({
    required this.id, required this.farmId, required this.product,
    required this.type, required this.quantity, required this.date,
    required this.application, this.crop,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'farmId': farmId, 'product': product, 'type': type,
    'quantity': quantity, 'date': date.toIso8601String(),
    'application': application, 'crop': crop,
  };

  factory FertilizerRecord.fromMap(Map<String, dynamic> m) => FertilizerRecord(
    id: m['id'] ?? '', farmId: m['farmId'] ?? '', product: m['product'] ?? '',
    type: m['type'] ?? '', quantity: m['quantity'] ?? '',
    date: m['date'] != null ? DateTime.parse(m['date']) : DateTime.now(),
    application: m['application'] ?? '', crop: m['crop'],
  );
}

class DiseaseRecord {
  final String id;
  final String farmId;
  final DateTime detectedDate;
  final String? crop;
  final String problem;
  final String severity;
  final String? evidencePath;
  final String? treatment;
  final String status;
  final DateTime? resolutionDate;

  DiseaseRecord({
    required this.id, required this.farmId, required this.detectedDate,
    this.crop, required this.problem, required this.severity,
    this.evidencePath, this.treatment, this.status = 'open', this.resolutionDate,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'farmId': farmId, 'detectedDate': detectedDate.toIso8601String(),
    'crop': crop, 'problem': problem, 'severity': severity,
    'evidencePath': evidencePath, 'treatment': treatment,
    'status': status, 'resolutionDate': resolutionDate?.toIso8601String(),
  };

  factory DiseaseRecord.fromMap(Map<String, dynamic> m) => DiseaseRecord(
    id: m['id'] ?? '', farmId: m['farmId'] ?? '',
    detectedDate: m['detectedDate'] != null ? DateTime.parse(m['detectedDate']) : DateTime.now(),
    crop: m['crop'], problem: m['problem'] ?? '', severity: m['severity'] ?? 'low',
    evidencePath: m['evidencePath'], treatment: m['treatment'],
    status: m['status'] ?? 'open',
    resolutionDate: m['resolutionDate'] != null ? DateTime.parse(m['resolutionDate']) : null,
  );
}
