import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../app_theme.dart';
import '../models/todo.dart';
import '../services/todo_service.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen>
    with WidgetsBindingObserver {
  final TodoService _todoService = TodoService();
  final TextEditingController _todoController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  FlutterLocalNotificationsPlugin? _notificationsPlugin;
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
      _initializeNotifications();
      _checkPassedReminders();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _todoController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !kIsWeb) {
      _checkPassedReminders();
    }
  }

  void _initializeNotifications() async {
    tz.initializeTimeZones();
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings android =
        AndroidInitializationSettings('app_icon');
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _notificationsPlugin!.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  Future<void> _checkPassedReminders() async {
    final todos = await _todoService.getAllTodos();
    final now = DateTime.now();
    for (var todo in todos) {
      if (todo.reminderTime != null &&
          todo.reminderTime!.isBefore(now) &&
          !todo.isCompleted) {
        await _todoService.updateTodo(
            todo.copyWith(isCompleted: true, updatedAt: now));
        await _notificationsPlugin?.cancel(todo.id.hashCode);
      }
    }
  }

  Future<void> _addTodo() async {
    final content = _todoController.text.trim();
    if (content.isEmpty) return;

    DateTime? reminderTime;
    if (!kIsWeb) {
      reminderTime = await _selectDateTime(context);
    }

    final now = DateTime.now();
    final newTodo = Todo(
      id: '',
      content: content,
      createdAt: now,
      updatedAt: now,
      reminderTime: reminderTime,
    );
    final addedTodo = await _todoService.addTodo(newTodo);
    _todoController.clear();
    if (reminderTime != null && !kIsWeb) {
      _scheduleNotification(addedTodo);
    }
  }

  void _scheduleNotification(Todo todo) async {
    if (_notificationsPlugin == null) return;
    if (todo.reminderTime != null &&
        todo.reminderTime!.isAfter(DateTime.now())) {
      await _notificationsPlugin!.zonedSchedule(
        todo.id.hashCode,
        'Todo Reminder',
        todo.content,
        tz.TZDateTime.from(todo.reminderTime!, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'todo_reminders',
            'Todo Reminders',
            channelDescription: 'Todo reminder notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  void _updateTodo(Todo todo) async {
    final updated = todo.copyWith(updatedAt: DateTime.now());
    await _todoService.updateTodo(updated);
    if (!kIsWeb) {
      await _notificationsPlugin?.cancel(todo.id.hashCode);
      if (updated.reminderTime != null &&
          updated.reminderTime!.isAfter(DateTime.now()) &&
          !updated.isCompleted) {
        _scheduleNotification(updated);
      }
    }
  }

  void _deleteTodo(String id) async {
    await _todoService.deleteTodo(id);
    await _notificationsPlugin?.cancel(id.hashCode);
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? AppTheme.darkSubtext : const Color(0xFF666688);
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor:
            isDark ? AppTheme.darkCard : AppTheme.lightSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Task',
            style: TextStyle(
                color: isDark ? AppTheme.darkText : AppTheme.lightText,
                fontWeight: FontWeight.w700)),
        content: Text('This task will be permanently deleted.',
            style: TextStyle(color: sub)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: sub))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
    return result ?? false;
  }

  Future<DateTime?> _selectDateTime(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme(
            brightness: isDark ? Brightness.dark : Brightness.light,
            primary: AppTheme.indigo,
            onPrimary: Colors.white,
            secondary: AppTheme.violet,
            onSecondary: Colors.white,
            error: Colors.red,
            onError: Colors.white,
            surface: isDark ? AppTheme.darkCard : AppTheme.lightSurface,
            onSurface: isDark ? AppTheme.darkText : AppTheme.lightText,
          ),
        ),
        child: child!,
      ),
    );
    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        return DateTime(pickedDate.year, pickedDate.month, pickedDate.day,
            pickedTime.hour, pickedTime.minute);
      }
    }
    return null;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBg : AppTheme.lightBg;
    final textColor = isDark ? AppTheme.darkText : AppTheme.lightText;
    final sub = isDark ? AppTheme.darkSubtext : const Color(0xFF9999AA);
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final surface = isDark ? AppTheme.darkCard : AppTheme.lightSurface;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ── Input bar ──
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Icon(Icons.add_task_rounded,
                    color: AppTheme.indigo, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _todoController,
                    focusNode: _inputFocus,
                    style: TextStyle(color: textColor, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Add a new task…',
                      hintStyle: TextStyle(color: sub, fontSize: 15),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addTodo(),
                    textInputAction: TextInputAction.done,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _addTodo,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.indigo,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_upward_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // ── Header + filter ──
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text('Tasks',
                    style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: () =>
                      setState(() => _showCompleted = !_showCompleted),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _showCompleted
                          ? AppTheme.indigo.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _showCompleted ? AppTheme.indigo : border,
                      ),
                    ),
                    child: Text(
                      _showCompleted ? 'All' : 'Active',
                      style: TextStyle(
                          color:
                              _showCompleted ? AppTheme.indigo : sub,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Todo list ──
          Expanded(
            child: StreamBuilder<List<Todo>>(
              stream: _todoService.getTodos(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.indigo));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState(isDark, sub);
                }

                final todos = snapshot.data!
                    .where(
                        (t) => _showCompleted ? true : !t.isCompleted)
                    .toList();

                if (todos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.indigo.withOpacity(0.1),
                          ),
                          child: const Icon(
                              Icons.check_circle_outline_rounded,
                              color: AppTheme.indigo,
                              size: 36),
                        ),
                        const SizedBox(height: 16),
                        Text('All tasks done!',
                            style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('Tap "All" to see completed tasks',
                            style: TextStyle(color: sub, fontSize: 14)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: todos.length,
                  itemBuilder: (context, i) => _buildTodoCard(
                    todos[i],
                    isDark: isDark,
                    textColor: textColor,
                    sub: sub,
                    border: border,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Todo card ────────────────────────────────────────────────────────────

  Widget _buildTodoCard(
    Todo todo, {
    required bool isDark,
    required Color textColor,
    required Color sub,
    required Color border,
  }) {
    final reminderPassed = todo.reminderTime != null &&
        todo.reminderTime!.isBefore(DateTime.now());
    final card = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final accent = todo.isCompleted ? sub : AppTheme.indigo;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key(todo.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _confirmDelete(context),
        onDismissed: (_) => _deleteTodo(todo.id),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline_rounded,
              color: Colors.redAccent, size: 24),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: todo.isCompleted ? card.withOpacity(0.6) : card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: todo.isCompleted
                  ? border
                  : Color.alphaBlend(
                      AppTheme.indigo.withOpacity(0.2), border),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // ── Accent bar (matches notes style) ──
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),

                // ── Checkbox ──
                Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: GestureDetector(
                    onTap: () => _updateTodo(todo.copyWith(
                        isCompleted: !todo.isCompleted,
                        updatedAt: DateTime.now())),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: todo.isCompleted
                            ? AppTheme.indigo
                            : Colors.transparent,
                        border: Border.all(
                          color: todo.isCompleted
                              ? AppTheme.indigo
                              : border,
                          width: 2,
                        ),
                      ),
                      child: todo.isCompleted
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 16)
                          : null,
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // ── Content ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          todo.content,
                          style: TextStyle(
                            color: todo.isCompleted ? sub : textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            decoration: todo.isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            decorationColor: sub,
                          ),
                        ),
                        if (todo.reminderTime != null) ...[
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                reminderPassed
                                    ? Icons.alarm_off_rounded
                                    : Icons.alarm_rounded,
                                size: 12,
                                color: reminderPassed
                                    ? Colors.redAccent
                                    : AppTheme.indigo,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('MMM d · h:mm a')
                                    .format(todo.reminderTime!),
                                style: TextStyle(
                                  color: reminderPassed
                                      ? Colors.redAccent
                                      : AppTheme.indigo,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (reminderPassed)
                                Text(' · Passed',
                                    style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 12)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Actions ──
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!todo.isCompleted && !kIsWeb)
                      IconButton(
                        icon: Icon(
                          todo.reminderTime != null
                              ? Icons.alarm_rounded
                              : Icons.alarm_add_rounded,
                          color: todo.reminderTime != null
                              ? AppTheme.indigo
                              : sub,
                          size: 20,
                        ),
                        onPressed: () async {
                          final t = await _selectDateTime(context);
                          if (t != null) {
                            _updateTodo(todo.copyWith(
                                reminderTime: t,
                                updatedAt: DateTime.now()));
                          }
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                      ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded,
                          color: sub, size: 20),
                      onPressed: () async {
                        final ok = await _confirmDelete(context);
                        if (ok) _deleteTodo(todo.id);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 36, minHeight: 36),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────

  Widget _buildEmptyState(bool isDark, Color sub) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.indigo.withOpacity(0.1),
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                color: AppTheme.indigo, size: 40),
          ),
          const SizedBox(height: 20),
          Text('No tasks yet',
              style: TextStyle(
                  color: isDark ? AppTheme.darkText : AppTheme.lightText,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Add a task above to get started',
              style: TextStyle(color: sub, fontSize: 15)),
        ],
      ),
    );
  }
}