import 'package:flutter/material.dart';
import 'instruments_screen.dart';
import 'keyboards_screen.dart';
import 'sounds_screen.dart';

class AppSetupScreen extends StatefulWidget {
  final int initialIndex;

  const AppSetupScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<AppSetupScreen> createState() => _AppSetupScreenState();
}

class _AppSetupScreenState extends State<AppSetupScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup'),
        actions: _buildActions(),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.palette), text: 'Instruments'),
            Tab(icon: Icon(Icons.keyboard), text: 'Keyboards'),
            Tab(icon: Icon(Icons.volume_up), text: 'Sounds'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          InstrumentsScreen(isEmbedded: true),
          KeyboardsScreen(isEmbedded: true),
          SoundsScreen(isEmbedded: true),
        ],
      ),
    );
  }

  List<Widget> _buildActions() {
    switch (_tabController.index) {
      case 0:
        return [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Instrument',
            onPressed: () => InstrumentsScreen.createNew(context),
          ),
          IconButton(
            icon: const Icon(Icons.library_music),
            tooltip: 'Search Library',
            onPressed: () => InstrumentsScreen.openLibrary(context),
          ),
        ];
      case 1:
        return [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Keyboard',
            onPressed: () => KeyboardsScreen.createNew(context),
          ),
        ];
      case 2:
        return [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Sound Set',
            onPressed: () => SoundsScreen.createNew(context),
          ),
        ];
      default:
        return [];
    }
  }
}
