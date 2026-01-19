import 'package:flutter/material.dart';
import '../providers/todo_provider.dart';
import '../models/todo.dart';

class TodoListView extends StatelessWidget {
  final TodoProvider todoProvider;

  const TodoListView({super.key, required this.todoProvider});

  @override
  Widget build(BuildContext context) {
    final todos = todoProvider.todos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (todos.isEmpty) Padding(padding: const EdgeInsets.all(8.0), child: Text('Henüz görev yok', style: Theme.of(context).textTheme.bodyMedium)),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: todos.length,
          separatorBuilder: (_,__)=>const SizedBox(height:8),
          itemBuilder: (context, index){
            final t = todos[index];
            return Dismissible(
              key: ValueKey(t.id),
              background: Container(color: Colors.green, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left:20), child: const Icon(Icons.check, color: Colors.white)),
              secondaryBackground: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right:20), child: const Icon(Icons.delete, color: Colors.white)),
              onDismissed: (dir){
                if (dir == DismissDirection.startToEnd) {
                  todoProvider.toggleTodo(t.id);
                } else {
                  todoProvider.removeTodo(t.id);
                }
              },
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Checkbox(value: t.completed, onChanged: (_)=>todoProvider.toggleTodo(t.id)),
                  title: Text(t.task, style: TextStyle(decoration: t.completed?TextDecoration.lineThrough:null)),
                  trailing: IconButton(icon: const Icon(Icons.more_vert), onPressed: (){}),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
