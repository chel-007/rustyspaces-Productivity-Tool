import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:another_flushbar/flushbar.dart';
import 'space_page.dart';
import 'dart:convert';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  bool isAuthenticated = false;
  Map<String, bool> _isHovered = {};
  List<String> spaces = [];

  @override
  void initState() {
    super.initState();

    // Initialize the animation controller and animation
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _authenticateUser();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _authenticateUser() async {
    _showToast(context, 'Authenticating User');
    String? userId = await AuthService.silentAuth();
    if (userId != null) {
      _showToast(context, 'User Authenticated');
      setState(() {
        isAuthenticated = true;
      });
      _fetchSpaces(userId);
    }
  }

void _fetchSpaces(String userId) async {
  try {
    final response = await http.get(Uri.parse('/spaces'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        spaces = List<String>.from(data[userId] ?? []);
      });
    } else {
      _showToast(context, 'Failed to fetch spaces. Please try again');
      print('Failed to fetch spaces');
    }
  } catch (e) {

    _showToast(context, 'Error fetching spaces. Please try again: $e');
    print('Error fetching spaces: $e');
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(110.0),  // Total height including padding
        child: Padding(
          padding: const EdgeInsets.all(20.0),  // Padding around the AppBar
          child: AppBar(
            title: Text(
              'RustySpaces',
              style: GoogleFonts.robotoSlab(  // Change to your preferred font
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            centerTitle: true,  // Center the title
            backgroundColor: Colors.black,  // Block color
            shape: RoundedRectangleBorder(       // Add an outline
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(36),
                bottom: Radius.circular(36),
              ),
            ),
            elevation: 55,  // Shadow effect for the AppBar
            toolbarHeight: 65,  // Height of the AppBar
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(3.0),
              child: Container(
                color: Colors.orange,  // Outline color
                height: 3.0,
                width: 200,
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: isAuthenticated
            ? spaces.isEmpty
                ? _buildNoSpaces()
                : _buildSpacesUI()
            : CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildNoSpaces() {
  return Stack(
    alignment: Alignment.center,
    children: [
      ScaleTransition(
        scale: _animation,
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF4C5A70).withOpacity(0.5),
            // .withOpacity(0.8),
          ),
        ),
      ),
      ScaleTransition(
        scale: _animation,
        child: Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF727f94).withOpacity(0.5),
          ),
        ),
      ),
      ScaleTransition(
        scale: _animation,
        child: ElevatedButton(
          onPressed: _createSpace,
          child: Icon(Icons.add, size: 30, color: Colors.orange),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent, // No background color
            shadowColor: Colors.transparent, // No shadow
            shape: CircleBorder(),
            padding: EdgeInsets.all(30),
          ),
        ),
      ),
    ],
   );
  }

Widget _buildSpacesUI() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCreateButton(),
        SizedBox(height: 50), // Optional spacing between the button and the list
        Flexible(
          child: ListView.builder(
            shrinkWrap: true, // Makes the list take up only as much space as needed
            itemCount: spaces.length,
            itemBuilder: (context, index) {
              return _buildSpaceItem(spaces[index]);
            },
          ),
        ),
      ],
    ),
  );
}

Widget _buildCreateButton() {
  return Stack(
    alignment: Alignment.center,
    children: [
      ScaleTransition(
        scale: _animation,
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF4C5A70).withOpacity(0.5),
            // .withOpacity(0.8),
          ),
        ),
      ),
      ScaleTransition(
        scale: _animation,
        child: Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF727f94).withOpacity(0.5),
          ),
        ),
      ),
      ScaleTransition(
        scale: _animation,
        child: ElevatedButton(
          onPressed: _createSpace,
          child: Icon(Icons.add, size: 30, color: Colors.orange),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent, // No background color
            shadowColor: Colors.transparent, // No shadow
            shape: CircleBorder(),
            padding: EdgeInsets.all(30),
          ),
        ),
      ),
    ],
  );
}


  Widget _buildSpaceItem(String spaceName) {
    return Center(
      child: GestureDetector(
        onTap: () => _goToSpace(spaceName),
        child: MouseRegion(
          onEnter: (event) {
            setState(() {
              _isHovered[spaceName] = true;
            });
          },
          onExit: (event) {
            setState(() {
              _isHovered[spaceName] = false;
            });
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            margin: EdgeInsets.symmetric(vertical: 10),
            padding: EdgeInsets.all(20),
            width: MediaQuery.of(context).size.width * 0.7,  // Control the width (70% of the screen width)
            constraints: BoxConstraints(maxWidth: 400),  // Max width constraint
            decoration: BoxDecoration(
              color: (_isHovered[spaceName] ?? false) ? Colors.grey[800] : Colors.grey[600],  // Hover effect
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: Offset(0, 3),  // Shadow positioning
                ),
              ],
            ),
            child: Text(
              spaceName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

void _showToast(BuildContext context, String message) {
  Flushbar(
    message: message,
    duration: Duration(seconds: 2),
    backgroundColor: Colors.black87,
    flushbarPosition: FlushbarPosition.TOP,
    margin: EdgeInsets.all(8),
    borderRadius: BorderRadius.circular(8),
    icon: Icon(
      Icons.info_outline,
      size: 28.0,
      color: Colors.blue[300],
    ),
  ).show(context);
}


void _createSpace() async {
  String spaceName = '';
  
  // Show dialog to input space name
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Create Space'),
        content: TextField(
          decoration: InputDecoration(hintText: "Enter space name"),
          onChanged: (value) {
            spaceName = value;  // Update space name as user types
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();  // Close the dialog
            },
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (spaceName.isNotEmpty) {
                // Send request to create a new space
                
                try {
                  final response = await http.post(
                    Uri.parse('/spaces'),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode(spaceName),
                  );
                    //print('Status code: ${response.statusCode}');
                    final responseBody = jsonDecode(response.body);

                    // Print detailed response information
                    print('Status code: ${response.statusCode}');
                    print('Response body: $responseBody');

                 if (response.statusCode == 200) {
                    // Successful creation, reload spaces
                     Navigator.of(context).pop();

                    print("i got here too");
                        String? userId = await AuthService.silentAuth();
                            if (userId != null) {
                      setState(() {
                        _fetchSpaces(userId);
                      });              
                  }

                   
                 }
                  else {
                  // Handle error
                  _showToast(context, 'Space creation Failed. Please try again');
                     print('Failed to create space');
                 }
                } catch (e) {
                  _showToast(context, 'Error creating space: $e');
                  print('Error creating space: $e');
                }
              }
            },
            child: Text('Create'),
          ),
        ],
      );
    },
  );
}


  void _goToSpace(String spaceName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpacePage(spaceName: spaceName),
      ),
    );
  }
}

// can u break down this error to the minimal?, what EXACTLY is prepared statement, also in the context of my rust, cargo diesel with postgres supabase project and ofcoure my routes and sending quesries to the database, why does this error sometimes causes my app to not be fecthing data anymore until i kill server and start again:

// Error: prepared statement "__diesel_stmt_0" already exists
