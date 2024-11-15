import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class OccupantsScreen extends StatefulWidget {
  final Function(LatLng, Map<String, dynamic>) onPlotSelected;

  OccupantsScreen({required this.onPlotSelected});

  @override
  _OccupantsScreenState createState() => _OccupantsScreenState();
}

class _OccupantsScreenState extends State<OccupantsScreen> {
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search Occupants'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Search by Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('plots').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final plots = snapshot.data?.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name']?.toString().toLowerCase() ?? '';
                    return name.contains(searchQuery);
                  }).toList() ?? [];

                  return ListView.builder(
                    itemCount: plots.length,
                    itemBuilder: (context, index) {
                      final plot = plots[index].data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(plot['name'] ?? 'Unknown Name'),
                        subtitle: Text('Plot Status: ${plot['plotStatus'] ?? 'Unknown'}'),
                        onTap: () {
                          final latitude = plot['latitude'];
                          final longitude = plot['longitude'];
                          if (latitude != null && longitude != null) {
                            widget.onPlotSelected(LatLng(latitude, longitude), plot);
                          }
                        },
                      );
                    },
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
