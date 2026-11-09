class Todo {
  final String id;
  final String userId;
  final String title;
  final bool isCompleted;
  final bool isAuto;
  final String? plantId;
  final String category; // Sulama, Gübreleme, Budama, Genel
  final String priority; // Düşük, Normal, Yüksek
  final String dueDate; // Bugün, Yarın, Bu Hafta
  final String description; // Otomatik görev nedeni veya ek açıklama

  Todo({
    required this.id,
    required this.userId,
    required this.title,
    this.isCompleted = false,
    this.isAuto = false,
    this.plantId,
    this.category = 'Genel',
    this.priority = 'Normal',
    this.dueDate = 'Bugün',
    this.description = '',
  });

  factory Todo.fromMap(String id, Map<dynamic, dynamic> map) {
    return Todo(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      isAuto: map['isAuto'] ?? false,
      plantId: map['plantId'],
      category: map['category'] ?? (map['isAuto'] == true ? 'Sulama' : 'Genel'),
      priority: map['priority'] ?? (map['isAuto'] == true ? 'Yüksek' : 'Normal'),
      dueDate: map['dueDate'] ?? 'Bugün',
      description: map['description'] ?? '',
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
      'dueDate': dueDate,
      'description': description,
    };
  }
}