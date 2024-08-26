import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'components/sticky_notes.dart';
import 'components/music_player.dart';
import 'components/time_tracker.dart';
import 'components/starry_background.dart';

class SpacePage extends StatefulWidget {
  final String spaceName;

  const SpacePage({required this.spaceName});

  @override
  _SpacePageState createState() => _SpacePageState();
}

class _SpacePageState extends State<SpacePage> {
  List<String> otherSpaces = [];
  String? selectedSpace;

  @override
  void initState() {
    super.initState();
    _initComponents();
  }

  void _initComponents() async {
    await Future.delayed(Duration(milliseconds: 100), () {
      // Fetch the other spaces after components have had time to initialize
      fetchOtherSpaces();
    });
    setState(() {
      selectedSpace = widget.spaceName;
    });
  }

  Future<void> fetchOtherSpaces() async {
    try {
      final response = await http.get(Uri.parse('/others'));

      if (response.statusCode == 200) {
        final List<String> fetchedSpaces = List<String>.from(jsonDecode(response.body));

        setState(() {
          otherSpaces = fetchedSpaces;
        });
      } else {
        // error
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    // Stop the music when the page is disposed
    final musicPlayerState = context.findAncestorStateOfType<MusicPlayerState>();
    musicPlayerState?.stopAndRemoveCurrentAudio();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            color: Colors.black, // Set the background to black
          ),
          StarryEffect(),
          // Current Space Container and Dropdown beside the Cancel Button
          Positioned(
            top: 30,
            left: 20, // Position it towards the far left
            child: Row(
              children: [
                // Current Space Container
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.spaceName,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 20),
                // Dropdown Button for Other Spaces
                DropdownButton<String>(
                  value: selectedSpace,
                  dropdownColor: Colors.grey[800],
                  iconEnabledColor: Colors.grey.withOpacity(0.8),
                  iconSize: 35, // Make the icon a bit larger
                  underline: SizedBox(), // Remove the default underline
                  items: otherSpaces.isNotEmpty
                      ? otherSpaces.map((String space) {
                          return DropdownMenuItem<String>(
                            value: space,
                            child: Text(
                              space,
                              style: TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList()
                      : [
                          DropdownMenuItem<String>(
                            value: '',
                            child: Text(
                              "No other spaces available",
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                        ],
                  onChanged: (String? newValue) {
                    if (newValue != null && newValue.isNotEmpty) {
                      setState(() {
                        selectedSpace = newValue;
                      });
                    }
                  },
                  hint: Text(
                    "Other Spaces",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          // Centered Cancel Button at the top
          Positioned(
            top: 30,
            left: 0,
            right: 0,
            child: Center(
              child: IconButton(
                icon: Icon(Icons.cancel, color: Colors.grey.withOpacity(0.9), size: 45),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),
          // Sticky Notes Section in the center left
          Positioned(
            left: 20,
            top: 150, // Adjusted top position
            child: Container(
              width: MediaQuery.of(context).size.width * 0.5, // 50% of the screen width
              child: Column(
                children: [
                  StickyNotesSection(spaceName: widget.spaceName),
                ],
              ),
            ),
          ),
          // Time Tracker at the top right
          Positioned(
            top: 150,
            right: 20,
            child: Container(
              child: TimeTracker(spaceName: widget.spaceName),
            ),
          ),
          // Music Player fixed at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.red.withOpacity(0.2), // background color for debugging
              child: MusicPlayer(),
            ),
          ),
        ],
      ),
    );
  }
}
