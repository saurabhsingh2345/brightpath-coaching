import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/brand.dart';
import 'core/theme.dart';
import 'core/token_store.dart';
import 'services/api_service.dart';
import 'services/chat_socket.dart';
import 'state/auth_state.dart';
import 'state/chat_state.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/student/student_shell.dart';

void main() {
  runApp(const BrightPathApp());
}

class BrightPathApp extends StatefulWidget {
  const BrightPathApp({super.key});

  @override
  State<BrightPathApp> createState() => _BrightPathAppState();
}

class _BrightPathAppState extends State<BrightPathApp> {
  late final TokenStore _tokens;
  late final ApiClient _client;
  late final ApiService _api;
  late final AuthState _auth;
  late final ChatSocket _socket;
  late final ChatState _chat;

  @override
  void initState() {
    super.initState();
    _tokens = TokenStore();
    _client = ApiClient(_tokens);
    _api = ApiService(_client);
    _auth = AuthState(tokens: _tokens, client: _client, api: _api);
    _socket = ChatSocket(_tokens);
    _chat = ChatState(api: _api, socket: _socket);

    // Chat only runs while someone is signed in.
    _auth.addListener(_onAuthChanged);
    _auth.bootstrap();
  }

  bool _chatRunning = false;

  void _onAuthChanged() {
    final signedIn = _auth.status == AuthStatus.authenticated;
    if (signedIn && !_chatRunning) {
      _chatRunning = true;
      _chat.start();
    } else if (!signedIn && _chatRunning) {
      _chatRunning = false;
      _chat.stop();
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _chat.dispose();
    _socket.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TokenStore>.value(value: _tokens),
        Provider<ApiClient>.value(value: _client),
        Provider<ApiService>.value(value: _api),
        ChangeNotifierProvider<AuthState>.value(value: _auth),
        Provider<ChatSocket>.value(value: _socket),
        ChangeNotifierProvider<ChatState>.value(value: _chat),
      ],
      child: MaterialApp(
        title: Brand.fullName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        darkTheme: buildTheme(brightness: Brightness.dark),
        themeMode: ThemeMode.system,
        home: const _RoleRouter(),
      ),
    );
  }
}

/// Chooses the interface from the authenticated user's role - one APK, two
/// completely different experiences.
class _RoleRouter extends StatelessWidget {
  const _RoleRouter();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    final child = switch (auth.status) {
      AuthStatus.initializing => const SplashScreen(),
      AuthStatus.unauthenticated => const LoginScreen(),
      AuthStatus.authenticated =>
        auth.isAdmin ? const AdminShell() : const StudentShell(),
    };

    // Cross-fade so switching role / signing out never hard-cuts.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: KeyedSubtree(
        key: ValueKey('${auth.status}-${auth.user?.id}'),
        child: child,
      ),
    );
  }
}
