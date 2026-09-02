import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../state/chat_state.dart';
import '../chat/chat_list_screen.dart';
import 'admin_dashboard_screen.dart';
import 'students_screen.dart';
import 'attendance_screen.dart';
import 'more_screen.dart';

/// Bottom-nav container for the admin side. Chat earns a permanent slot;
/// Fees lives under "More" (and the dashboard links straight into it).
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<ChatState>().unreadTotal;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          AdminDashboardScreen(),
          StudentsScreen(),
          AttendanceScreen(),
          ChatListScreen(),
          MoreScreen(),
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
              icon: Icon(Icons.space_dashboard_outlined, size: 23),
              selectedIcon: Icon(Icons.space_dashboard_rounded, size: 23),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.people_alt_outlined, size: 23),
              selectedIcon: Icon(Icons.people_alt_rounded, size: 23),
              label: 'Students',
            ),
            const NavigationDestination(
              icon: Icon(Icons.fact_check_outlined, size: 23),
              selectedIcon: Icon(Icons.fact_check_rounded, size: 23),
              label: 'Attendance',
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
              icon: Icon(Icons.grid_view_outlined, size: 23),
              selectedIcon: Icon(Icons.grid_view_rounded, size: 23),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}

/// Small red count on a nav icon. Hidden entirely at zero so the bar stays
/// calm when there is nothing to read.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4,
          right: -7,
          child: Container(
            constraints: const BoxConstraints(minWidth: 17),
            height: 17,
            padding: const EdgeInsets.symmetric(horizontal: 4.5),
            decoration: BoxDecoration(
              color: StatusColors.absent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Theme.of(context).navigationBarTheme.backgroundColor ??
                    scheme.surface,
                width: 1.6,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
