import 'package:flutter/material.dart';

import '../session.dart';
import '../theme.dart';
import 'cow_page.dart';
import 'dashboard_page.dart';
import 'herd_page.dart';
import 'menu_page.dart';
import 'scan_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key, required this.session});
  final FarmSession session;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _index = 0;
  String _herdFilter = 'all';

  @override
  void initState() {
    super.initState();
    widget.session.onTag = _openCode;
  }

  @override
  void dispose() {
    widget.session.onTag = null;
    super.dispose();
  }

  Future<void> _openCode(String code) async {
    final cow = await widget.session.openCode(code);
    if (!mounted || cow == null) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CowPage(session: widget.session, cow: cow)));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(session: widget.session, onOpenScan: () => setState(() => _index = 2)),
      HerdPage(key: ValueKey(_herdFilter), session: widget.session, filter: _herdFilter),
      ScanPage(session: widget.session),
      MenuPage(session: widget.session),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: Desk.card(context),
        indicatorColor: const Color(0x333EE0A0),
        onDestinationSelected: (index) => setState(() {
          _index = index;
          if (index == 1) _herdFilter = 'all';
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.pets_outlined), selectedIcon: Icon(Icons.pets), label: 'Herd'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'Menu'),
        ],
      ),
    );
  }
}
