import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(GeoReferencedApp());
}

class GeoReferencedApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: GeoReferencedHome(),
    );
  }
}

class GeoReferencedHome extends StatefulWidget {
  @override
  _GeoReferencedHomeState createState() => _GeoReferencedHomeState();
}

class _GeoReferencedHomeState extends State<GeoReferencedHome>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  List<Marker> plots = [];
  List<Map<String, dynamic>> searchResults = [];
  List<Map<String, dynamic>> plotsData = [];
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  TextEditingController _searchController = TextEditingController();
  User? currentUser;

  @override
  void initState() {
    super.initState();
    _loadPlotsFromFirestore();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _loadPlotsFromFirestore() async {
    try {
      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('plots').get();

      setState(() {
        plotsData = querySnapshot.docs
            .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
            .toList();
        searchResults = List.from(plotsData);
        plots = plotsData.map((data) {
          return Marker(
            point: LatLng(data['latitude'], data['longitude']),
            width: 30.0,
            height: 30.0,
            child: GestureDetector(
              onTap: () {
                _showPlotDetails(data);
              },
              child: Icon(
                Icons.location_on,
                color: Colors.green,
                size: 30.0,
              ),
            ),
          );
        }).toList();
      });
    } catch (e) {
      print('Error loading plots: $e');
    }
  }

  void _showPlotDetails(Map<String, dynamic> plot) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(plot['name'] ?? 'Plot Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Name: ${plot['name'] ?? 'Unknown'}'),
                Text('Date of Birth: ${plot['birth'] ?? 'Unknown'}'),
                Text('Date of Death: ${plot['death'] ?? 'Unknown'}'),
                if (plot['description'] != null)
                  Text('Description: ${plot['description']}'),
                if (plot['findAGraveLink'] != null)
                  GestureDetector(
                    onTap: () async {
                      final url = plot['findAGraveLink'];
                      if (await canLaunch(url)) {
                        await launch(url);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not launch link')),
                        );
                      }
                    },
                    child: Text(
                      'Find A Grave Link',
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            if (currentUser != null &&
                currentUser!.email == 'arbelatownship@hotmail.com') ...[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showEditPlotDialog(plot);
                },
                child: Text('Edit'),
              ),
              TextButton(
                onPressed: () async {
                  await _deletePlot(plot['id']);
                  Navigator.pop(context);
                },
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showEditPlotDialog(Map<String, dynamic> plot) {
    final nameController = TextEditingController(text: plot['name']);
    final descriptionController = TextEditingController(text: plot['description']);
    final birthController = TextEditingController(text: plot['birth']);
    final deathController = TextEditingController(text: plot['death']);
    final findAGraveLinkController = TextEditingController(text: plot['findAGraveLink']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Plot'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(labelText: 'Description'),
                ),
                TextField(
                  controller: birthController,
                  decoration: InputDecoration(labelText: 'Date of Birth'),
                ),
                TextField(
                  controller: deathController,
                  decoration: InputDecoration(labelText: 'Date of Death'),
                ),
                TextField(
                  controller: findAGraveLinkController,
                  decoration: InputDecoration(labelText: 'Find A Grave Link'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final updatedData = {
                  'name': nameController.text,
                  'description': descriptionController.text,
                  'birth': birthController.text,
                  'death': deathController.text,
                  'findAGraveLink': findAGraveLinkController.text,
                };
                await FirebaseFirestore.instance
                    .collection('plots')
                    .doc(plot['id'])
                    .update(updatedData);
                _loadPlotsFromFirestore();
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePlot(String plotId) async {
    try {
      await FirebaseFirestore.instance.collection('plots').doc(plotId).delete();
      _loadPlotsFromFirestore();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plot deleted successfully')),
      );
    } catch (e) {
      print('Error deleting plot: $e');
    }
  }

  void _searchPlots(String query) {
    setState(() {
      if (query.isEmpty) {
        searchResults = List.from(plotsData);
      } else {
        searchResults = plotsData
            .where((plot) =>
                plot['name'] != null &&
                plot['name'].toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Gunnell Cemetery"),
        actions: [
          IconButton(
            icon: Icon(Icons.login),
            onPressed: _showSignInDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "Map"),
            Tab(text: "Search"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(43.244072, -83.598718),
              initialZoom: 20.0,
              onLongPress: (tapPosition, point) {
                _addPlot(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
              ),
              OverlayImageLayer(
                overlayImages: [
                  OverlayImage(
                    bounds: LatLngBounds(
                      LatLng(43.2445532, -83.5998052),
                      LatLng(43.24379970, -83.59774877),
                    ),
                    opacity: 1.0,
                    imageProvider: AssetImage('assets/qgis_map.png'),
                  ),
                ],
              ),
              MarkerLayer(
                markers: plots,
              ),
            ],
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: _searchPlots,
                  decoration: InputDecoration(
                    labelText: 'Search Occupants',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: searchResults.length,
                  itemBuilder: (context, index) {
                    final plot = searchResults[index];
                    return ListTile(
                      title: Text(plot['name'] ?? 'Unknown'),
                      subtitle:
                          Text('Section: ${plot['section'] ?? 'N/A'}'),
                      onTap: () {
                        final plotLocation =
                            LatLng(plot['latitude'], plot['longitude']);
                        _mapController.move(plotLocation, 23.0);
                        _showPlotDetails(plot);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addPlot(LatLng point) {
    if (currentUser == null || currentUser!.email != 'arbelatownship@hotmail.com') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must be logged in as the sexton to add a plot.')),
      );
      return;
    }

    TextEditingController nameController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();
    TextEditingController birthController = TextEditingController();
    TextEditingController deathController = TextEditingController();
    TextEditingController findAGraveLinkController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Plot'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Name of Occupant'),
                ),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(labelText: 'Description'),
                ),
                TextField(
                  controller: birthController,
                  decoration: InputDecoration(labelText: 'Date of Birth'),
                ),
                TextField(
                  controller: deathController,
                  decoration: InputDecoration(labelText: 'Date of Death'),
                ),
                TextField(
                  controller: findAGraveLinkController,
                  decoration: InputDecoration(labelText: 'Find A Grave Link'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final plotData = {
                  'name': nameController.text,
                  'description': descriptionController.text,
                  'birth': birthController.text,
                  'death': deathController.text,
                  'findAGraveLink': findAGraveLinkController.text,
                  'latitude': point.latitude,
                  'longitude': point.longitude,
                };

                try {
                  await FirebaseFirestore.instance.collection('plots').add(plotData);
                  _loadPlotsFromFirestore();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Plot added successfully')),
                  );
                } catch (e) {
                  print('Error adding plot: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add plot')),
                  );
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showSignInDialog() {
    TextEditingController emailController = TextEditingController();
    TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Sign In'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  UserCredential userCredential = await _auth.signInWithEmailAndPassword(
                    email: emailController.text,
                    password: passwordController.text,
                  );
                  setState(() {
                    currentUser = userCredential.user;
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Signed in as ${currentUser!.email}')),
                  );
                } catch (e) {
                  print('Error signing in: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to sign in. Please try again.')),
                  );
                }
              },
              child: Text('Sign In'),
            ),
          ],
        );
      },
    );
  }
}
