import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tagselector/components/download_progress_sheet.dart';
import 'package:tagselector/pages/daily_ranking_page.dart';
import 'package:tagselector/pages/image_follow_page.dart';
import 'package:tagselector/pages/image_index_page.dart';
import 'package:tagselector/pages/user_page.dart';
import 'package:tagselector/service/app_user_session.dart';
import 'package:tagselector/service/artwork_download_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PixivHelperApp());
}

class PixivHelperApp extends StatelessWidget {
  const PixivHelperApp({super.key});

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFE5E7EB);
    const selectedBg = Color(0xFFF3F8FF);
    const selectedBorder = Color(0xFFD6E8FF);
    const selectedFg = Color(0xFF3B82F6);
    const normalFg = Color(0xFF334155);
    const inkFg = Color(0xFF243B53);

    return MaterialApp(
      title: 'Pixiv Helper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2563EB),
          secondary: inkFg,
          surface: Colors.white,
          outline: borderColor,
          outlineVariant: borderColor,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF526176)),
        appBarTheme: const AppBarTheme(
          foregroundColor: inkFg,
          iconTheme: IconThemeData(color: Color(0xFF526176)),
          actionsIconTheme: IconThemeData(color: Color(0xFF526176)),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: inkFg,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: inkFg,
          ),
          titleMedium: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: inkFg,
          ),
          bodyLarge: TextStyle(fontSize: 14, color: Color(0xFF334155)),
          bodyMedium: TextStyle(fontSize: 13, color: Color(0xFF526176)),
          labelLarge: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: inkFg,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2563EB)),
          ),
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: Color(0xFFF8FAFC),
          selectedColor: selectedBg,
          side: BorderSide(color: borderColor),
          shape: StadiumBorder(),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: normalFg,
          ),
          secondaryLabelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selectedFg,
          ),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return selectedBg;
              }
              return Colors.white;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return selectedFg;
              }
              return normalFg;
            }),
            iconColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return selectedFg;
              }
              return const Color(0xFF64748B);
            }),
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const BorderSide(color: selectedBorder);
              }
              return const BorderSide(color: borderColor);
            }),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            foregroundColor: const WidgetStatePropertyAll(Color(0xFF526176)),
            overlayColor: WidgetStatePropertyAll(
              const Color(0xFF3B82F6).withValues(alpha: 0.08),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            foregroundColor: const WidgetStatePropertyAll(Color(0xFF2563EB)),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return const Color(0xFFE2E8F0);
              }
              return const Color(0xFFEFF6FF);
            }),
            side: const WidgetStatePropertyAll(
              BorderSide(color: Color(0xFFBFDBFE)),
            ),
            iconColor: const WidgetStatePropertyAll(Color(0xFF3B82F6)),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        outlinedButtonTheme: const OutlinedButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(Color(0xFF3B82F6)),
            side: WidgetStatePropertyAll(
              BorderSide(color: Color(0xFFD6E8FF)),
            ),
          ),
        ),
        textButtonTheme: const TextButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(Color(0xFF3B82F6)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: selectedBg,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: selectedFg, size: 23);
            }
            return const IconThemeData(color: Color(0xFF64748B), size: 22);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: selectedFg,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              );
            }
            return const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }),
        ),
      ),
      home: const _AppEntry(),
    );
  }
}

class _AppEntry extends StatelessWidget {
  const _AppEntry();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppUserSession.instance,
      builder: (context, _) {
        final session = AppUserSession.instance;
        if (!session.initialized && !session.initializing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            AppUserSession.instance.initialize();
          });
        }
        if (!session.initialized || session.initializing) {
          return const _AppLoadingPage();
        }
        if (session.initializationError != null &&
            !session.isAuthenticated &&
            session.users.isEmpty) {
          return _AppStartupErrorPage(message: session.initializationError!);
        }
        if (!AppUserSession.instance.isAuthenticated) {
          return const _SessionLoginPage();
        }
        return const _AppShell();
      },
    );
  }
}

class _AppLoadingPage extends StatelessWidget {
  const _AppLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在连接后端...'),
          ],
        ),
      ),
    );
  }
}

class _AppStartupErrorPage extends StatelessWidget {
  final String message;

  const _AppStartupErrorPage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '启动失败',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '应用启动时未能连接后端服务。',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFB42318),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      AppUserSession.instance.initialize(force: true);
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _selectedIndex = 0;

  final _pages = const [
    ImageListPage(),
    FollowingPage(),
    DailyRankingPage(),
    UserPage(),
  ];

  final _navItems = const [
    _NavItem(icon: Icons.image_outlined, label: '图库'),
    _NavItem(icon: Icons.favorite_border_rounded, label: '关注'),
    _NavItem(icon: Icons.auto_graph_rounded, label: '日榜'),
    _NavItem(icon: Icons.person_outline_rounded, label: '用户'),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final phone = width < 720;
    final compact = width < 1000;

    return Scaffold(
      drawer: compact && !phone
          ? Drawer(
              backgroundColor: Colors.white,
              child: _NavigationPane(
                items: _navItems,
                selectedIndex: _selectedIndex,
                compact: false,
                onSelect: (index) {
                  setState(() => _selectedIndex = index);
                  Navigator.of(context).pop();
                },
              ),
            )
          : null,
      appBar: compact && !phone
          ? AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: Text(_navItems[_selectedIndex].label),
              actions: const [
                _DownloadProgressButton(compact: false),
                SizedBox(width: 8),
              ],
            )
          : null,
      floatingActionButton: phone || !compact
          ? Padding(
              padding: EdgeInsets.only(bottom: phone ? 74 : 0),
              child: const _DownloadProgressButton(compact: true),
            )
          : null,
      bottomNavigationBar: phone
          ? _MobileBottomNav(
              selectedIndex: _selectedIndex,
              items: _navItems,
              onSelect: (index) {
                setState(() => _selectedIndex = index);
              },
            )
          : null,
      body: SafeArea(
        top: phone,
        left: false,
        right: false,
        bottom: false,
        child: Row(
          children: [
            if (!compact)
              Container(
                width: 108,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    right: BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                ),
                child: _NavigationPane(
                  items: _navItems,
                  selectedIndex: _selectedIndex,
                  compact: true,
                  onSelect: (index) => setState(() => _selectedIndex = index),
                ),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(phone ? 0 : (compact ? 8 : 12)),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: KeyedSubtree(
                    key: ValueKey(_selectedIndex),
                    child: _pages[_selectedIndex],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionLoginPage extends StatefulWidget {
  const _SessionLoginPage();

  @override
  State<_SessionLoginPage> createState() => _SessionLoginPageState();
}

class _SessionLoginPageState extends State<_SessionLoginPage> {
  final AppUserSession _session = AppUserSession.instance;
  final TextEditingController _sessionController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _sessionController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = _sessionController.text.trim();
    if (session.isEmpty) {
      setState(() {
        _error = '请输入有效 session';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _session.loginWithSession(
        session: session,
        name: _nameController.text.trim(),
      );
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session 登录',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '这里不提供用户名密码登录。请输入有效的 Pixiv session，验证通过后才会进入应用。',
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '显示名称（可选）',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sessionController,
                    minLines: 5,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Pixiv session / PHPSESSID',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFB42318),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: const Icon(Icons.login_rounded),
                    label: Text(_submitting ? '验证中...' : '登录'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadProgressButton extends StatelessWidget {
  final bool compact;

  const _DownloadProgressButton({required this.compact});

  @override
  Widget build(BuildContext context) {
    final manager = ArtworkDownloadManager.instance;
    return AnimatedBuilder(
      animation: manager,
      builder: (context, _) {
        final activeCount = manager.activeTaskCount;
        final totalCount = manager.tasks.length;
        final hasTasks = totalCount > 0;
        final foreground =
            activeCount > 0 ? const Color(0xFF0A84FF) : const Color(0xFF526176);

        final button = Material(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(999),
          elevation: compact ? 4 : 0,
          shadowColor: Colors.black.withValues(alpha: 0.16),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => showDownloadProgressSheet(context),
            child: SizedBox(
              width: compact ? 46 : 42,
              height: compact ? 46 : 42,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    activeCount > 0
                        ? Icons.downloading_rounded
                        : Icons.file_download_done_rounded,
                    color: foreground,
                    size: compact ? 24 : 22,
                  ),
                  if (activeCount > 0)
                    Positioned.fill(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(foreground),
                        backgroundColor: const Color(0xFFEAF4FF),
                      ),
                    ),
                  if (hasTasks)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 17),
                        height: 17,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: activeCount > 0
                              ? const Color(0xFF0A84FF)
                              : const Color(0xFF64748B),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          activeCount > 0 ? '$activeCount' : '$totalCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );

        if (compact) {
          return button;
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: button,
        );
      },
    );
  }
}

class _MobileBottomNav extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _MobileBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(5, 4, 5, 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE8EDF4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  child: _MobileNavItem(
                    item: items[index],
                    selected: index == selectedIndex,
                    onTap: () => onSelect(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _MobileNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF0A84FF) : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF4FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: selected ? 21 : 20, color: color),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationPane extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final bool compact;
  final ValueChanged<int> onSelect;

  const _NavigationPane({
    required this.items,
    required this.selectedIndex,
    required this.compact,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 14),
        child: Column(
          children: [
            Container(
              width: compact ? 52 : double.infinity,
              height: 52,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: SvgPicture.asset('assets/pixiv.svg'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final selected = index == selectedIndex;
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onSelect(index),
                    child: Ink(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 8 : 12,
                        vertical: compact ? 10 : 12,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFF3F8FF)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFD6E8FF)
                              : Colors.transparent,
                        ),
                      ),
                      child: compact
                          ? Column(
                              children: [
                                Icon(
                                  item.icon,
                                  size: 20,
                                  color: selected
                                      ? const Color(0xFF3B82F6)
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? const Color(0xFF3B82F6)
                                        : const Color(0xFF243B53),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Icon(
                                  item.icon,
                                  size: 20,
                                  color: selected
                                      ? const Color(0xFF3B82F6)
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? const Color(0xFF3B82F6)
                                        : const Color(0xFF243B53),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.label,
  });
}
