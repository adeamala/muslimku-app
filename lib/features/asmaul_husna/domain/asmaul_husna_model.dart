class AsmaulHusnaModel {
  final int id;
  final String arab;
  final String latin;
  final String indo;

  AsmaulHusnaModel({
    required this.id,
    required this.arab,
    required this.latin,
    required this.indo,
  });

  factory AsmaulHusnaModel.fromJson(Map<String, dynamic> json) {
    return AsmaulHusnaModel(
      id: (json['id'] ?? 0) as int,
      arab: (json['arab'] ?? '') as String,
      latin: (json['latin'] ?? '') as String,
      indo: (json['indo'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'arab': arab, 'latin': latin, 'indo': indo};
  }
}
