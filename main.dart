import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF635BFF),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        fontFamily: 'Arial',
      ),
      home: const TodoHomePage(),
    );
  }
}

class TodoTask {
  final String id;
  String title;
  bool completed;
  final DateTime createdAt;

  TodoTask({
    required this.id,
    required this.title,
    this.completed = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'completed': completed,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TodoTask.fromJson(Map<String, dynamic> json) {
    return TodoTask(
      id: json['id'] as String,
      title: json['title'] as String,
      completed: json['completed'] as bool? ?? false,
      createdAt: DateTime.tryParse(
            json['createdAt'] as String? ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

enum TaskFilter { all, active, completed }

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  final List<TodoTask> tasks = [];
  final TextEditingController taskController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  TaskFilter currentFilter = TaskFilter.all;
  String searchQuery = '';
  bool loading = true;

  int get completedCount => tasks.where((task) => task.completed).length;

  int get activeCount => tasks.where((task) => !task.completed).length;

  List<TodoTask> get visibleTasks {
    final result = tasks.where((task) {
      final matchesFilter = switch (currentFilter) {
        TaskFilter.all => true,
        TaskFilter.active => !task.completed,
        TaskFilter.completed => task.completed,
      };

      return matchesFilter &&
          task.title.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    result.sort((a, b) {
      if (a.completed != b.completed) {
        return a.completed ? 1 : -1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    return result;
  }

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  Future<void> loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTasks = prefs.getString('taskflow_tasks');

      if (savedTasks != null) {
        final decoded = jsonDecode(savedTasks) as List<dynamic>;

        tasks.addAll(
          decoded.map(
            (item) => TodoTask.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          ),
        );
      }
    } catch (_) {
      tasks.clear();
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> saveTasks() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'taskflow_tasks',
      jsonEncode(tasks.map((task) => task.toJson()).toList()),
    );
  }

  Future<void> addTask() async {
    final title = taskController.text.trim();

    if (title.isEmpty) {
      showMessage('Please enter a task first.');
      return;
    }

    setState(() {
      tasks.add(
        TodoTask(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: title,
        ),
      );

      taskController.clear();
      currentFilter = TaskFilter.all;
      searchQuery = '';
      searchController.clear();
    });

    await saveTasks();

    if (mounted) {
      showMessage('Task added successfully.');
    }
  }

  Future<void> toggleTask(TodoTask task, bool value) async {
    setState(() {
      task.completed = value;
    });

    await saveTasks();
  }

  Future<void> deleteTask(TodoTask task) async {
    setState(() {
      tasks.removeWhere((item) => item.id == task.id);
    });

    await saveTasks();

    if (mounted) {
      showMessage('Task deleted.');
    }
  }

  Future<void> editTask(TodoTask task) async {
    final controller = TextEditingController(text: task.title);

    try {
      final updatedTitle = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Edit task'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 120,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'Enter task name',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                Navigator.of(dialogContext).pop(value.trim());
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(
                    controller.text.trim(),
                  );
                },
                child: const Text('Save changes'),
              ),
            ],
          );
        },
      );

      if (!mounted ||
          updatedTitle == null ||
          updatedTitle.trim().isEmpty) {
        return;
      }

      setState(() {
        task.title = updatedTitle.trim();
      });

      await saveTasks();

      if (mounted) {
        showMessage('Task updated successfully.');
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> clearCompleted() async {
    if (completedCount == 0) {
      showMessage('There are no completed tasks to clear.');
      return;
    }

    setState(() {
      tasks.removeWhere((task) => task.completed);
    });

    await saveTasks();

    if (mounted) {
      showMessage('Completed tasks cleared.');
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void dispose() {
    taskController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        tasks.isEmpty ? 0.0 : completedCount / tasks.length;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(
                            22,
                            12,
                            22,
                            28,
                          ),
                          children: [
                            _buildWelcome(),
                            const SizedBox(height: 22),
                            _buildStatistics(progress),
                            const SizedBox(height: 26),
                            _buildTaskInput(),
                            const SizedBox(height: 24),
                            _buildSearch(),
                            const SizedBox(height: 20),
                            _buildFilters(),
                            const SizedBox(height: 18),
                            _buildTaskHeading(),
                            const SizedBox(height: 12),
                            _buildTaskList(),
                            if (completedCount > 0) ...[
                              const SizedBox(height: 18),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: clearCompleted,
                                  icon: const Icon(
                                    Icons.delete_sweep_outlined,
                                  ),
                                  label: const Text('Clear completed'),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 18,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE9EAF2),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF635BFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TaskFlow',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Your personal task manager',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EFFF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'MY TASKS',
              style: TextStyle(
                color: Color(0xFF635BFF),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Stay organized.',
          style: TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Small steps every day lead to big results.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildStatistics(double progress) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF635BFF),
            Color(0xFF877DFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR PROGRESS',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$completedCount of ${tasks.length} tasks completed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white30,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              _statItem(
                Icons.pending_actions,
                '$activeCount active',
              ),
              const SizedBox(width: 20),
              _statItem(
                Icons.task_alt,
                '$completedCount completed',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white70,
          size: 17,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskInput() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE9EAF2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add a new task',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: taskController,
                  maxLength: 120,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => addTask(),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'What needs to get done?',
                    prefixIcon: const Icon(Icons.edit_note),
                    filled: true,
                    fillColor: const Color(0xFFF8F8FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: addTask,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF635BFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add, size: 20),
                      SizedBox(width: 4),
                      Text('Add'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: searchController,
      onChanged: (value) {
        setState(() {
          searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search your tasks...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFE9EAF2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFE9EAF2),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterButton('All', TaskFilter.all, tasks.length),
          const SizedBox(width: 8),
          _filterButton('Active', TaskFilter.active, activeCount),
          const SizedBox(width: 8),
          _filterButton(
            'Completed',
            TaskFilter.completed,
            completedCount,
          ),
        ],
      ),
    );
  }

  Widget _filterButton(
    String label,
    TaskFilter filter,
    int count,
  ) {
    final selected = currentFilter == filter;

    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      onSelected: (_) {
        setState(() {
          currentFilter = filter;
        });
      },
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white24
                  : const Color(0xFFEDEEF5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
      selectedColor: const Color(0xFF635BFF),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: selected
            ? const Color(0xFF635BFF)
            : const Color(0xFFE9EAF2),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildTaskHeading() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Your tasks',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          '${visibleTasks.length} ${visibleTasks.length == 1 ? 'item' : 'items'}',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskList() {
    final items = visibleTasks;

    if (items.isEmpty) {
      final hasTasks = tasks.isNotEmpty;

      return Container(
        padding: const EdgeInsets.symmetric(
          vertical: 38,
          horizontal: 20,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE9EAF2),
          ),
        ),
        child: Column(
          children: [
            Icon(
              hasTasks
                  ? Icons.search_off_rounded
                  : Icons.inbox_outlined,
              size: 52,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              hasTasks ? 'No matching tasks' : 'Your list is empty',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasTasks
                  ? 'Try another search or filter.'
                  : 'Add your first task to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: items.map(_buildTaskCard).toList(),
    );
  }

  Widget _buildTaskCard(TodoTask task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE9EAF2),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: task.completed,
            activeColor: const Color(0xFF635BFF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            onChanged: (value) {
              toggleTask(task, value ?? false);
            },
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: task.completed
                        ? TextDecoration.lineThrough
                        : null,
                    color: task.completed
                        ? Colors.grey
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  task.completed ? 'Completed' : 'In progress',
                  style: TextStyle(
                    fontSize: 12,
                    color: task.completed
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit task',
            onPressed: () => editTask(task),
            icon: const Icon(
              Icons.edit_outlined,
              size: 20,
            ),
            color: Colors.blueGrey,
          ),
          IconButton(
            tooltip: 'Delete task',
            onPressed: () => deleteTask(task),
            icon: const Icon(
              Icons.delete_outline,
              size: 21,
            ),
            color: Colors.redAccent,
          ),
        ],
      ),
    );
  }
}