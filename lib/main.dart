import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/plot_search_screen.dart';
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
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
        plots = querySnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
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
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Name: ${plot['name'] ?? 'Unknown'}'),
              Text('Date of Birth: ${plot['birth'] ?? 'Unknown'}'),
              Text('Date of Death: ${plot['death'] ?? 'Unknown'}'),
              Text('Marker Description: ${plot['description'] ?? 'N/A'}'),
              Text('Latitude: ${plot['latitude'] ?? 'Unknown'}'),
              Text('Longitude: ${plot['longitude'] ?? 'Unknown'}'),
              plot['findAGraveLink'] != null
                  ? GestureDetector(
                      onTap: () async {
                        final url = plot['findAGraveLink'];
                        if (url != null && url.isNotEmpty && await canLaunch(url)) {
                          await launch(url);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not launch the link.')),
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
                    )
                  : Text('Find A Grave Link: N/A'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _focusOnPlot(LatLng plotLocation) {
    setState(() {
      _tabController.animateTo(0); // Switch to the map tab
      _mapController.move(plotLocation, 23.0); // Zoom in more closely
    });
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
                  await _auth.signInWithEmailAndPassword(
                      email: emailController.text,
                      password: passwordController.text);
                  Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Gunnell Cemetery"),
        actions: [
          IconButton(
            icon: Icon(Icons.login),
            onPressed: _showSignInDialog,
            tooltip: 'Sign In',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "Map"),
            Tab(text: "Plot Search"),
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
                if (_auth.currentUser != null) {
                  _addPlot(point);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Only authorized users can add plots.')),
                  );
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
              ),
              OverlayImageLayer(
                overlayImages: [
                  OverlayImage(
                    bounds: LatLngBounds(
                      LatLng(43.2445532, -83.5998052),
                      LatLng(43.24379970, -83.59774877),
                    ),
                    opacity: 1,
                    imageProvider: AssetImage('assets/qgis_map.png'),
                  ),
                ],
              ),
              MarkerLayer(
                markers: plots,
              ),
            ],
          ),
          OccupantsScreen(
            onPlotSelected: (plotLocation, plot) {
              _focusOnPlot(plotLocation);
              _showPlotDetails(plot);
            },
          ),
        ],
      ),
    );
  }

  void _addPlot(LatLng point) {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController nameController = TextEditingController();
        TextEditingController descriptionController = TextEditingController();
        TextEditingController siteController = TextEditingController();
        TextEditingController sectionController = TextEditingController();
        TextEditingController rowController = TextEditingController();
        TextEditingController plotController = TextEditingController();
        TextEditingController birthController = TextEditingController();
        TextEditingController deathController = TextEditingController();
        TextEditingController findAGraveLinkController = TextEditingController();

        return AlertDialog(
          title: Text('Add Plot'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Name of Occupant'),
                ),
                TextField(
                  controller: siteController,
                  decoration: InputDecoration(labelText: 'Site'),
                ),
                TextField(
                  controller: sectionController,
                  decoration: InputDecoration(labelText: 'Section'),
                ),
                TextField(
                  controller: rowController,
                  decoration: InputDecoration(labelText: 'Row'),
                ),
                TextField(
                  controller: plotController,
                  decoration: InputDecoration(labelText: 'Plot'),
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
                  controller: descriptionController,
                  decoration: InputDecoration(labelText: 'Marker Description'),
                ),
                TextField(
                  controller: findAGraveLinkController,
                  decoration: InputDecoration(labelText: 'FindAGrave Link'),
                ),
              ],
            ),
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
                final plotData = {
                  'name': nameController.text,
                  'site': siteController.text,
                  'section': sectionController.text,
                  'row': rowController.text,
                  'plot': plotController.text,
                  'birth': birthController.text,
                  'death': deathController.text,
                  'description': descriptionController.text,
                  'findAGraveLink': findAGraveLinkController.text,
                  'latitude': point.latitude,
                  'longitude': point.longitude,
                };

                try {
                  await FirebaseFirestore.instance.collection('plots').add(plotData);

                  setState(() {
                    plots.add(
                      Marker(
                        point: point,
                        width: 30.0,
                        height: 30.0,
                        child: GestureDetector(
                          onTap: () {
                            _showPlotDetails(plotData);
                          },
                          child: Icon(
                            Icons.location_on,
                            color: Colors.green,
                            size: 30.0,
                          ),
                        ),
                      ),
                    );
                  });
                  Navigator.of(context).pop();
                } catch (e) {
                  print('Error adding plot: $e');
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
