import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/floor.dart';
import '../models/place.dart';
import '../models/user.dart';
import 'login_screen.dart';
import 'table_order_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _base = 'http://217.154.223.125:3000';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('W4CASH'),
        backgroundColor: const Color(0xFF3A6FFF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF0F4FF),
      body: const _RestaurantTab(),
    );
  }
}

// ── Restaurant tab ────────────────────────────────────────────────────────────

class _RestaurantTab extends StatefulWidget {
  const _RestaurantTab();

  @override
  State<_RestaurantTab> createState() => _RestaurantTabState();
}

class _RestaurantTabState extends State<_RestaurantTab>
    with SingleTickerProviderStateMixin {
  static const String _floorsUrl = 'http://217.154.223.125:3000/floors';

  List<Floor>? _floors;
  String? _error;
  TabController? _floorTabController;

  @override
  void initState() {
    super.initState();
    _fetchFloors();
  }

  @override
  void dispose() {
    _floorTabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchFloors() async {
    try {
      final response = await http.get(Uri.parse(_floorsUrl));
      if (response.statusCode != 200) {
        setState(() => _error = 'HTTP ${response.statusCode}');
        return;
      }
      //final body = json.decode(response.body);

final List<dynamic> data = json.decode(response.body)['_embedded']['floorList'] as List<dynamic>;
    final floors = data
        .map((e) => Floor.fromJson(e as Map<String, dynamic>))
        .toList();

    //  final List<dynamic> raw =
    //      (body is Map && body.containsKey('floorList')) ? body['_embedded']['floorList'] : body;
    //  final floors =
    //      raw.map((e) => Floor.fromJson(e as Map<String, dynamic>)).toList();
      setState(() {
        _floors = floors;
        _floorTabController?.dispose();
        _floorTabController = TabController(
            length: floors.length, vsync: this);
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text('Could not load floors: $_error'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() { _error = null; _floors = null; });
                _fetchFloors();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_floors == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_floors!.isEmpty) {
      return const Center(child: Text('No floors found.'));
    }

    return Column(
      children: [
        Container(
          color: const Color(0xFF3A6FFF),
          child: TabBar(
            controller: _floorTabController,
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: _floors!
                .map((f) => Tab(text: f.name))
                .toList(),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _floorTabController,
            children: _floors!
                .map((f) => _FloorContent(floor: f))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _FloorContent extends StatefulWidget {
  final Floor floor;
  const _FloorContent({required this.floor});

  @override
  State<_FloorContent> createState() => _FloorContentState();
}

class _FloorContentState extends State<_FloorContent> {
  static const String _placesUrl = 'http://217.154.223.125:3000/places';

  List<Place>? _places;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPlaces();
  }

  Future<void> _fetchPlaces() async {
    try {
      final response = await http.get(
          Uri.parse('$_placesUrl/${widget.floor.id}'));
      if (response.statusCode != 200) {
        setState(() => _error = 'HTTP ${response.statusCode}');
        return;
      }

      final List<dynamic> data = json.decode(response.body)['_embedded']['placeList'] as List<dynamic>;
    final places = data
        .map((e) => Place.fromJson(e as Map<String, dynamic>))
        .toList();
      setState(() => _places = places);
      
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 10),
            Text('Could not load tables: $_error'),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                setState(() { _error = null; _places = null; });
                _fetchPlaces();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_places == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_places!.isEmpty) {
      return const Center(child: Text('No tables on this floor.'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 160,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
        ),
        itemCount: _places!.length,
        itemBuilder: (context, index) {
          final place = _places![index];
          return _TableButton(place: place);
        },
      ),
    );
  }
}

class _TableButton extends StatelessWidget {
  final Place place;
  const _TableButton({required this.place});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A237E),
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF3A6FFF), width: 1.5),
        ),
        padding: const EdgeInsets.all(12),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TableOrderScreen(place: place),
          ),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.table_restaurant,
              size: 36, color: Color(0xFF3A6FFF)),
          const SizedBox(height: 8),
          Text(
            place.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Profile tab (original home content) ──────────────────────────────────────
/*
class _ProfileTab extends StatelessWidget {
  final User user;
  const _ProfileTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3A6FFF), Color(0xFF1A237E)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white24,
                    radius: 30,
                    child: Text(
                      user.name[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 28,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, ${user.name}!',
                          style: const TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${user.name}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Profile Details',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E)),
            ),
            const SizedBox(height: 12),

            // Detail card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _DetailRow(
                        icon: Icons.badge_outlined,
                        label: 'User ID',
                        value: '#${user.id}'),
                    const Divider(),
                    _DetailRow(
                        icon: Icons.person_outline,
                        label: 'Full Name',
                        value: user.name),
                    const Divider(),
                    _DetailRow(
                        icon: Icons.alternate_email,
                        label: 'Username',
                        value: '@${user.name}'),
                    const Divider(),
                    _DetailRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: ""/*user.email*/),
                    const Divider(),
                    _DetailRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: ""/*user.phone*/),
                    const Divider(),
                    _DetailRow(
                        icon: Icons.language_outlined,
                        label: 'Website',
                        value: ""/*user.website*/),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}*/

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF3A6FFF), size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                  color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
