class Todo {
  final String id;
  final String userId;
  final String title;
  final bool isCompleted;
  final bool isAuto; // Robot ikonlu otomatik görev mi?
  final String? plantId;

  Todo({
    required this.id,
    required this.userId,
    required this.title,
    this.isCompleted = false,
    this.isAuto = false,
    this.plantId,
  });

  factory Todo.fromMap(String id, Map<dynamic, dynamic> map) {
    return Todo(
      id: id,
      userId: map['userId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      isCompleted: map['isCompleted'] == true,
      isAuto: map['isAuto'] == true,
      plantId: map['plantId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'isCompleted': isCompleted,
      'isAuto': isAuto,
      'plantId': plantId,
    };
  }
}