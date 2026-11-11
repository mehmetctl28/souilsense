import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/todo_provider.dart';
import '../models/todo.dart';
import '../constants/colors.dart';

class TodoList extends StatefulWidget {
  const TodoList({super.key});

  @override
  State<TodoList> createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String _selectedCategory = 'Sulama';
  String _selectedPriority = 'Normal';
  DateTime _selectedDate = DateTime.now();
  int _selectedTabIndex = 0; // 0: Aktif, 1: Otomatik Geçmiş, 2: Manuel Geçmiş

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    _focusNode.unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  void _addNewTask(TodoProvider provider) {
    if (_controller.text.trim().isNotEmpty) {
      provider.addTodo(
        _controller.text.trim(),
        category: _selectedCategory,
        priority: _selectedPriority,
        dueDate: _selectedDate,
      );
      _controller.clear();
      setState(() => _selectedDate = DateTime.now());
    }
    _focusNode.unfocus();
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Yüksek':
        return AppColors.statusCritical;
      case 'Düşük':
        return Colors.blueGrey;
      default:
        return AppColors.primary;
    }
  }

  String _formatShortDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return "$d.$m.${dt.year}";
  }

  @override
  Widget build(BuildContext context) {
    final todoProvider = Provider.of<TodoProvider>(context);
    final allTodos = todoProvider.todos;
    final activeList = todoProvider.activeTodos;
    final autoHistoryList = todoProvider.completedAutoTodos;
    final manualHistoryList = todoProvider.completedManualTodos;

    final completedCount = autoHistoryList.length + manualHistoryList.length;
    final double progress = allTodos.isEmpty ? 0.0 : completedCount / allTodos.length;
    final int progressPercent = (progress * 100).toInt();

    List<Todo> displayedTodos;
    if (_selectedTabIndex == 0) {
      displayedTodos = activeList;
    } else if (_selectedTabIndex == 1) {
      displayedTodos = autoHistoryList;
    } else {
      displayedTodos = manualHistoryList;
    }

    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Bakım Planı ve Görevler",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
            ),
            Text(
              "%$progressPercent Tamamlandı",
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.withOpacity(0.2),
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),

        // YENİ GÖREV EKLEME KARTI + GERÇEK TAKVİM SEÇİCİ
        Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 12, 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Row(
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
                        hintText: "Yeni bakım görevi ekle...",
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildMiniDropdown(
                      value: _selectedCategory,
                      items: const ['Sulama', 'Gübreleme', 'Budama', 'Saksı Değişimi', 'Genel'],
                      textColor: textColor,
                      onChanged: (v) => setState(() => _selectedCategory = v!),
                    ),
                    const SizedBox(width: 8),
                    _buildMiniDropdown(
                      value: _selectedPriority,
                      items: const ['Düşük', 'Normal', 'Yüksek'],
                      textColor: textColor,
                      onChanged: (v) => setState(() => _selectedPriority = v!),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _pickDueDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              _formatShortDate(_selectedDate),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 5.1: AKTİF GÖREVLER / OTOMATİK GEÇMİŞ / MANUEL GEÇMİŞ AYRIMI
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTabChip(
                label: "Aktif (${activeList.length})",
                selected: _selectedTabIndex == 0,
                onTap: () => setState(() => _selectedTabIndex = 0),
                cardColor: cardColor,
                textColor: textColor,
              ),
              const SizedBox(width: 8),
              _buildTabChip(
                label: "Otomatik Geçmiş (${autoHistoryList.length})",
                selected: _selectedTabIndex == 1,
                onTap: () => setState(() => _selectedTabIndex = 1),
                cardColor: cardColor,
                textColor: textColor,
              ),
              const SizedBox(width: 8),
              _buildTabChip(
                label: "Manuel Geçmiş (${manualHistoryList.length})",
                selected: _selectedTabIndex == 2,
                onTap: () => setState(() => _selectedTabIndex = 2),
                cardColor: cardColor,
                textColor: textColor,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        if (displayedTodos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                _selectedTabIndex == 0
                    ? "Bekleyen aktif bakım görevin yok."
                    : (_selectedTabIndex == 1
                        ? "Henüz tamamlanmış otomatik sensör görevi yok."
                        : "Henüz tamamlanmış manuel görev yok."),
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          )
        else
          ...displayedTodos.map((todo) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: todo.isCompleted,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (_) => todoProvider.toggleTodo(todo.id, todo.isCompleted),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (todo.isAuto)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(Icons.sensors, size: 16, color: AppColors.statusCritical),
                              ),
                            Expanded(
                              child: Text(
                                todo.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: todo.isCompleted ? Colors.grey : textColor,
                                  decoration: todo.isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (todo.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            todo.description,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildBadge(
                              todo.isAuto ? "Otomatik" : "Manuel",
                              todo.isAuto
                                  ? Colors.deepOrange.withOpacity(0.12)
                                  : Colors.blue.withOpacity(0.12),
                              todo.isAuto ? Colors.deepOrange : Colors.blue,
                            ),
                            _buildBadge(
                              todo.category,
                              AppColors.primary.withOpacity(0.12),
                              AppColors.primary,
                            ),
                            _buildBadge(
                              todo.priority,
                              _priorityColor(todo.priority).withOpacity(0.12),
                              _priorityColor(todo.priority),
                            ),
                            _buildBadge(
                              todo.formattedDueDate,
                              Colors.grey.withOpacity(0.12),
                              Colors.grey,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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

  Widget _buildMiniDropdown({
    required String value,
    required List<String> items,
    required Color textColor,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
          style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w600),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTabChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color cardColor,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : textColor.withOpacity(0.75),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}