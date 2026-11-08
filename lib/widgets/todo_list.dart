import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/todo_provider.dart';
import '../constants/colors.dart';

class TodoList extends StatefulWidget {
  const TodoList({super.key});

  @override
  State<TodoList> createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addNewTask(TodoProvider provider) {
    if (_controller.text.trim().isNotEmpty) {
      provider.addTodo(_controller.text.trim());
      _controller.clear();
    }
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final todoProvider = Provider.of<TodoProvider>(context);
    final todos = todoProvider.todos;

    final completedCount = todos.where((t) => t.isCompleted).length;
    final double progress = todos.isEmpty ? 0.0 : completedCount / todos.length;
    final int progressPercent = (progress * 100).toInt();

    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Bugünün Planı",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
            ),
            Text(
              "%$progressPercent Tamamlandı",
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Tamamlanan", style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.7))),
            Text(
              "%$progressPercent",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.withOpacity(0.2),
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 20),

        // YENİ GÖREV EKLEME KUTUSU (Otomatik klavye açılmasını önler)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.add_task, color: textColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: false,
                  onTapOutside: (_) => _focusNode.unfocus(),
                  style: TextStyle(color: textColor),
                  onSubmitted: (_) => _addNewTask(todoProvider),
                  decoration: const InputDecoration(
                    hintText: "Yeni görev ekle...",
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: AppColors.primary),
                onPressed: () => _addNewTask(todoProvider),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        ...todos.map((todo) {
          final displayTitle = todo.isAuto && !todo.title.startsWith('🚨')
              ? '🚨 ${todo.title}'
              : todo.title;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Checkbox(
                  value: todo.isCompleted,
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (_) => todoProvider.toggleTodo(todo.id, todo.isCompleted),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    displayTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: todo.isCompleted ? Colors.grey : textColor,
                      decoration: todo.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                    ),
                  ),
                ),
                if (todo.isAuto)
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(Icons.smart_toy_outlined, color: Colors.grey, size: 20),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                    onPressed: () => todoProvider.deleteTodo(todo.id),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}