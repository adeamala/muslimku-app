class DoaModel {
  final int id;
  final String arab;
  final String indo;
  final String judul;
  final String source;

  DoaModel({
    required this.id,
    required this.arab,
    required this.indo,
    required this.judul,
    required this.source,
  });

  factory DoaModel.fromJson(Map<String, dynamic> json) {
    return DoaModel(
      id: _asInt(json['id']),
      // doa/acak and doa/semua send the text as "doa" and the meaning as "artinya".
      arab: (json['arab'] ?? json['doa'] ?? '') as String,
      indo: (json['indo'] ?? json['artinya'] ?? '') as String,
      judul: (json['judul'] ?? '') as String,
      source: (json['source'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'arab': arab,
      'indo': indo,
      'judul': judul,
      'source': source,
    };
  }
}

/// MyQuran sends numbers as int or string (and sometimes an empty string).
int _asInt(Object? value) =>
    value is int ? value : int.tryParse('${value ?? ''}') ?? 0;
