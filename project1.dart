import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final notificationPlugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initializationSettings = InitializationSettings(
    android: androidSettings,
  );
  await notificationPlugin.initialize(initializationSettings);

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeNotifier(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          title: 'Todo List',
          theme: themeNotifier.isDark 
              ? ThemeData.dark()
              : ThemeData.light(useMaterial3: true),
          darkTheme: ThemeData.dark(useMaterial3: true),
          home: const MainScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<TodoItem> _todos = [];
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(initializationSettings);
  }

  void _addTodo(TodoItem newTodo) {
    setState(() {
      _todos.add(newTodo);
    });
    _scheduleNotification(newTodo);
  }

  Future<void> _scheduleNotification(TodoItem todo) async {
    final androidDetails = const AndroidNotificationDetails(
      'channel_id',
      'Todo Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      todo.id,
      'Напоминание: ${todo.title}',
      todo.description,
      tz.TZDateTime.from(todo.time, tz.local),
      notificationDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  void _deleteTodo(int id) {
    setState(() {
      _todos.removeWhere((todo) => todo.id == id);
    });
    _notificationsPlugin.cancel(id);
  }

  void _editTodo(TodoItem editedTodo) {
    setState(() {
      final index = _todos.indexWhere((todo) => todo.id == editedTodo.id);
      _todos[index] = editedTodo;
    });
    _scheduleNotification(editedTodo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои задачи'),
      ),
      body: AnimatedList(
        key: GlobalKey<AnimatedListState>(),
        initialItemCount: _todos.length,
        itemBuilder: (context, index, animation) {
          return _buildTodoItem(_todos[index], animation, context);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddTodoScreen(context),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () {},
            ),
            Consumer<ThemeNotifier>(
              builder: (context, themeNotifier, child) => IconButton(
                icon: Icon(themeNotifier.isDark 
                    ? Icons.light_mode 
                    : Icons.dark_mode),
                onPressed: themeNotifier.toggleTheme,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodoItem(TodoItem todo, Animation<double> animation, BuildContext context) {
    return SizeTransition(
      sizeFactor: animation,
      child: Card(
        color: todo.color,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: ListTile(
          title: Text(todo.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(todo.description),
              Text(DateFormat('dd.MM.yyyy HH:mm').format(todo.time)),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _navigateToEditTodoScreen(context, todo),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _deleteTodo(todo.id),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToAddTodoScreen(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddTodoScreen()),
    );
    if (result != null) {
      _addTodo(result);
    }
  }

  Future<void> _navigateToEditTodoScreen(BuildContext context, TodoItem todo) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTodoScreen(todoToEdit: todo),
      ),
    );
    if (result != null) {
      _editTodo(result);
    }
  }
}

class AddTodoScreen extends StatefulWidget {
  final TodoItem? todoToEdit;

  const AddTodoScreen({super.key, this.todoToEdit});

  @override
  State<AddTodoScreen> createState() => _AddTodoScreenState();
}

class _AddTodoScreenState extends State<AddTodoScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _selectedTime;
  Color _selectedColor = Colors.blue.shade100;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.todoToEdit?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.todoToEdit?.description ?? '',
    );
    _selectedTime = widget.todoToEdit?.time ?? DateTime.now();
    _selectedColor = widget.todoToEdit?.color ?? Colors.blue.shade100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.todoToEdit == null ? 'Новая задача' : 'Редактировать'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Название задачи',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите название';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Описание задачи',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              ListTile(
                title: const Text('Дата и время'),
                subtitle: Text(DateFormat('dd.MM.yyyy HH:mm').format(_selectedTime)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedTime,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_selectedTime),
                    );
                    if (time != null) {
                      setState(() {
                        _selectedTime = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute);
                      });
                    }
                  }
                },
              ),
              const SizedBox(height: 20),
              const Text('Цвет задачи:'),
              Wrap(
                spacing: 10,
                children: [
                  _ColorChoice(
                    color: Colors.red.shade100,
                    selected: _selectedColor == Colors.red.shade100,
                    onTap: () => _updateColor(Colors.red.shade100),
                  ),
                  _ColorChoice(
                    color: Colors.blue.shade100,
                    selected: _selectedColor == Colors.blue.shade100,
                    onTap: () => _updateColor(Colors.blue.shade100),
                  ),
                  _ColorChoice(
                    color: Colors.green.shade100,
                    selected: _selectedColor == Colors.green.shade100,
                    onTap: () => _updateColor(Colors.green.shade100),
                  ),
                  _ColorChoice(
                    color: Colors.yellow.shade100,
                    selected: _selectedColor == Colors.yellow.shade100,
                    onTap: () => _updateColor(Colors.yellow.shade100),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: _saveTodo,
                child: const Text('Сохранить задачу'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateColor(Color color) {
    setState(() {
      _selectedColor = color;
    });
  }

  void _saveTodo() {
    if (_formKey.currentState!.validate()) {
      final newTodo = TodoItem(
        id: widget.todoToEdit?.id ?? DateTime.now().millisecondsSinceEpoch,
        title: _titleController.text,
        description: _descriptionController.text,
        time: _selectedTime,
        color: _selectedColor,
      );
      Navigator.pop(context, newTodo);
    }
  }
}

class _ColorChoice extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: Colors.black, width: 2)
              : null,
        ),
      ),
    );
  }
}

class TodoItem {
  final int id;
  final String title;
  final String description;
  final DateTime time;
  final Color color;

  TodoItem({
    required this.id,
    required this.title,
    required this.description,
    required this.time,
    required this.color,
  });
}

class ThemeNotifier extends ChangeNotifier {
  bool _isDark = false;

  bool get isDark => _isDark;

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }
}