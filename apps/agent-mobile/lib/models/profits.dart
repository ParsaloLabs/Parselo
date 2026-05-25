class Profits {
  final int totalProfits;
  final Map<String, int> dailyProfits;

  const Profits({required this.totalProfits, required this.dailyProfits});

  factory Profits.fromJson(Map<String, dynamic> j) {
    final raw = j['dailyProfits'] as Map<String, dynamic>? ?? const {};
    return Profits(
      totalProfits: (j['totalProfits'] as num?)?.toInt() ?? 0,
      dailyProfits: raw.map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }

  static const empty = Profits(totalProfits: 0, dailyProfits: {});
}

class JobsAndProfits {
  final List<dynamic> assigned;
  final List<dynamic> available;
  final Profits profits;

  const JobsAndProfits({
    required this.assigned,
    required this.available,
    required this.profits,
  });
}
