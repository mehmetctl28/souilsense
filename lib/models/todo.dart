class Todo {
  final String id;
  final String userId;
  final String title;
  final bool isCompleted;
  final bool isAuto;
  final String? plantId;
  final String category; // Sulama, Gübreleme, Budama, Genel
  final String priority; // Düşük, Normal, Yüksek
  final int dueTimestamp; // Gerçek Unix timestamp (ms)
  final int? completedAt; // Görevin tamamlandığı gerçek zaman (ms)
  final String description;

  Todo({
    required this.id,
    required this.userId,
    required this.title,
    this.isCompleted = false,
    this.isAuto = false,
    this.plantId,
    this.category = 'Genel',
    this.priority = 'Normal',
    required this.dueTimestamp,
    this.completedAt,
    this.description = '',
  });

  DateTime get dueDateTime => DateTime.fromMillisecondsSinceEpoch(dueTimestamp);

  String get formattedDueDate {
    final dt = dueDateTime;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diffDays = target.difference(today).inDays;

    final dayStr = dt.day.toString().padLeft(2, '0');
    final monthStr = dt.month.toString().padLeft(2, '0');
    final dateLabel = "$dayStr.$monthStr.${dt.year}";

    if (diffDays == 0) return "Bugün ($dateLabel)";
    if (diffDays == 1) return "Yarın ($dateLabel)";
    if (diffDays == -1) return "Dün ($dateLabel)";
    return dateLabel;
  }

  factory Todo.fromMap(String id, Map<dynamic, dynamic> map) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    int parsedDue = nowMs;

    if (map['dueTimestamp'] is num) {
      parsedDue = (map['dueTimestamp'] as num).toInt();
    } else if (map['dueDate'] is String) {
      final raw = map['dueDate'].toString();
      if (raw == 'Yarın') {
        parsedDue = DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch;
      } else if (raw == 'Bu Hafta') {
        parsedDue = DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch;
      }
    }

    return Todo(
      id: id,
      userId: (map['userId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      isCompleted: map['isCompleted'] == true,
      isAuto: map['isAuto'] == true,
      plantId: map['plantId']?.toString(),
      category: (map['category'] ?? (map['isAuto'] == true ? 'Sulama' : 'Genel')).toString(),
      priority: (map['priority'] ?? (map['isAuto'] == true ? 'Yüksek' : 'Normal')).toString(),
      dueTimestamp: parsedDue,
      completedAt: map['completedAt'] is num ? (map['completedAt'] as num).toInt() : null,
      description: (map['description'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'isCompleted': isCompleted,
      'isAuto': isAuto,
      'plantId': plantId,
      'category': category,
      'priority': priority,
      'dueTimestamp': dueTimestamp,
      if (completedAt != null) 'completedAt': completedAt,
      'description': description,
    };
  }
}