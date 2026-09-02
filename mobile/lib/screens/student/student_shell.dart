import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/chat_state.dart';
import '../admin/admin_shell.dart' show UnreadBadge;
import '../chat/chat_list_screen.dart';
import '../shared/materials_screen.dart';
import '../shared/timetable_screen.dart';
import 'student_dashboard_screen.dart';
import 'student_more_screen.dart';

/// Bottom-nav container for the student side. Announcements moved under "Me"
/// (the dashboard already surfaces the recent ones) to make room for Chat.
class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<ChatState>().unreadTotal;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          StudentDashboardScreen(),
          ChatListScreen(),
          _Titled(
            title: 'Timetable',
            child: TimetableScreen(mine: true, showAppBar: false),
          ),
          _Titled(
            title: 'Study material',
            child: MaterialsScreen(mine: true, showAppBar: false),
          ),
          StudentMoreScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined, size: 23),
              selectedIcon: Icon(Icons.home_rounded, size: 23),
              label: 'Home',
            ),
            NavigationDestination(
              icon: UnreadBadge(
                count: unread,
                child: const Icon(Icons.forum_outlined, size: 23),
              ),
              selectedIcon: UnreadBadge(
                count: unread,
                child: const Icon(Icons.forum_rounded, size: 23),
              ),
              label: 'Chat',
            ),
            const NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined, size: 23),
              selectedIcon: Icon(Icons.calendar_month_rounded, size: 23),
              label: 'Timetable',
            ),
            const NavigationDestination(
              icon: Icon(Icons.folder_outlined, size: 23),
              selectedIcon: Icon(Icons.folder_rounded, size: 23),
              label: 'Material',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, size: 23),
              selectedIcon: Icon(Icons.person_rounded, size: 23),
              label: 'Me',
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps an app-bar-less screen so each tab still gets a title.
class _Titled extends StatelessWidget {
  const _Titled({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}
