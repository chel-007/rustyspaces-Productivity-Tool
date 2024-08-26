import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'tri_checkbox.dart';
import 'package:another_flushbar/flushbar.dart';

class StickyNotesSection extends StatefulWidget {
  final String spaceName;

  StickyNotesSection({required this.spaceName});

  @override
  _StickyNotesSectionState createState() => _StickyNotesSectionState();
}

class _StickyNotesSectionState extends State<StickyNotesSection> {
  late ScrollController _horizontalScrollController;
  final Map<String, ScrollController> _verticalScrollControllers = {};

  List<StickyNote> stickyNotes = [];
  bool isLoading = true;

  //   int displayedIndex = 0;
  // final double fixedWidth = 600; 

  //late TextEditingController _controller;
  final Map<String, List<TextEditingController>> _controllers = {};

  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  void _initScrollControllerForNoteIfNeeded(StickyNote note) {
  if (!_verticalScrollControllers.containsKey(note.id)) {
    _verticalScrollControllers[note.id] = ScrollController();
  }
}

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
    //_verticalScrollController = ScrollController();
    _fetchStickyNotes();
    // _controllers = List<TextEditingController>;
  }

  Future<void> _fetchStickyNotes() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('/notes/notes?space_name=${widget.spaceName}'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        print('response body: $response');
        
        setState(() {
          print('Parsed sticky notes: $stickyNotes');
          stickyNotes = body.map((note) => StickyNote.fromJson(note)).toList();
          print('Parsed sticky notes: $stickyNotes');
        });
      } else {
        throw Exception('Failed to load sticky notes');
      }
    } catch (e) {
      _showToast(context, 'Failed to load sticky notes');
      //print('Error fetching sticky notes: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _createStickyNote() async {
    try {
      _showToast(context, 'Creating sticky note...');
      final response = await http.post(
        Uri.parse('/notes/create?space_name=${widget.spaceName}'),
        headers: _headers,
        body: jsonEncode({
          'title': 'Header',
          'color': 'FFEB3B',
          'text_color': '000000',
          'lines': ['New Sticky Note'],
        }),
      );

      if (response.statusCode == 200) {
        //print(response.body);
        _showToast(context, 'Sticky note created');
        final newNote = StickyNote.fromJson(jsonDecode(response.body));

        setState(() {
          stickyNotes.add(newNote);
        });
      } else {
        _showToast(context, 'Failed to create sticky note, please refresh try again');
        throw Exception('Failed to create sticky note');
      }
    } catch (e) {
      _showToast(context, 'Error creating sticky note: $e');
      print('Error creating sticky note: $e');
    }
  }

Future<void> _updateStickyNote(StickyNote note) async {
  try {
    _showToast(context, 'Updating sticky note. Please wait');
    final response = await http.put(
      Uri.parse('/notes/update?space_name=${widget.spaceName}'),
      headers: _headers,
      body: jsonEncode({
        'id': note.id,
        'color': note.color,
        'text_color': note.textColor,
        'lines': note.lines, // Ensure this is a list of strings
        'tags': note.tags,
      }),
    );

    if (response.statusCode == 200) {
      _showToast(context, 'Sticky note Updated');
      final updatedNote = StickyNote.fromJson(jsonDecode(response.body));
      setState(() {
        // Update the sticky note in your list
        final index = stickyNotes.indexWhere((n) => n.id == updatedNote.id);
        if (index != -1) {
          stickyNotes[index] = updatedNote;
        }
      });
    } else {
      _showToast(context, 'Failed to update sticky note, please refresh try again');
      throw Exception('Failed to update sticky note');
    }
  } catch (e) {
    _showToast(context, 'Error updating sticky note: $e');
    print('Error updating sticky note: $e');
  }
}

Future<void> _updateStickyNoteHeader(String noteId, String newTitle) async {
  try {
    _showToast(context, 'Updating sticky note header. Please wait');
    final response = await http.post(
      Uri.parse('/notes/header?space_name=${widget.spaceName}'),
      headers: _headers,
      body: jsonEncode({
        'id': noteId,
        'title': newTitle,
      }),
    );

    if (response.statusCode == 200) {
      _showToast(context, 'Sticky note header updated');
      final updatedNote = StickyNote.fromJson(jsonDecode(response.body));

      print(updatedNote);
      setState(() {
        // Find and update the note in the list
        final index = stickyNotes.indexWhere((n) => n.id == updatedNote.id);
        if (index != -1) {
          stickyNotes[index] = updatedNote;
        }
      });
    } else {
      _showToast(context, 'Failed to update sticky note header, please try again');
      throw Exception('Failed to update sticky note header');
    }
  } catch (e) {
    _showToast(context, 'Error updating sticky note header: $e');
    print('Error updating sticky note header: $e');
  }
}


  Future<void> _deleteStickyNote(String noteId) async {
    try {
      final response = await http.delete(Uri.parse('/notes/$noteId'));

      if (response.statusCode == 200) {
        _showToast(context, 'Sticky note deleted');
        setState(() {
          stickyNotes.removeWhere((note) => note.id == noteId);
        });
      } else {
        throw Exception('Failed to delete sticky note');
      }
    } catch (e) {
      print('Error deleting sticky note: $e');
    }
  }

void _addLineToStickyNote(StickyNote note) {
  note.lines.add('New Line|000000|false');

  setState(() {
    // Add a blank line with default color and unchecked state
  });

  _initScrollControllerForNoteIfNeeded(note);

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final ScrollController controller = _verticalScrollControllers[note.id]!;

    controller.animateTo(
      controller.position.maxScrollExtent,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  });
}

void _showToast(BuildContext context, String message) {
  Flushbar(
    message: message,
    duration: Duration(seconds: 3),
    backgroundColor: Colors.grey[600] ?? Colors.grey,
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


  @override
  void dispose() {
    _horizontalScrollController.dispose();
    //_verticalScrollController.dispose();
      _verticalScrollControllers.forEach((key, controller) {
    controller.dispose();
  });
    //_controller.dispose();
        _controllers.forEach((_, controllers) {
      controllers.forEach((controller) => controller.dispose());
    });
    super.dispose();
  }

    // Initialize controllers when a sticky note is created
  void _initControllersForNote(StickyNote note) {
    if (!_controllers.containsKey(note.id)) {
      _controllers[note.id] = note.lines.map((line) {
        final lineText = line.split('|')[0];
        return TextEditingController(text: lineText);
      }).toList();
    }
  }

  @override
Widget build(BuildContext context) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        alignment: Alignment.centerLeft,
        margin: EdgeInsets.only(left: 10, right: 20),
        child: FloatingActionButton(
          onPressed: _createStickyNote,
          child: Icon(Icons.add),
        ),
      ),
      if (isLoading)
        Center(child: CircularProgressIndicator()),
      if (!isLoading && stickyNotes.isEmpty)
        Opacity(
          opacity: 0.5,
          child: Container(
            width: 250,
            height: 300,
            color: Colors.grey[300],
            margin: EdgeInsets.only(top: 10),
            padding: EdgeInsets.all(10),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bedtime, size: 40, color: Colors.grey[600]),
                  SizedBox(height: 10),
                  Text(
                    'No Notes Yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ),
      // Wrap in a container with fixed width
      Container(
        width: MediaQuery.of(context).size.width * 0.4, // Set fixed width to 40% of screen width
        child: SingleChildScrollView(
          controller: _horizontalScrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: stickyNotes.asMap().entries.map((entry) {
              int index = entry.key;
              StickyNote note = entry.value;
              _initControllersForNote(note); // Initialize controllers
              double angle = (index - 1) * 0;

              return Transform.rotate(
                angle: angle,
                child: Container(
                  width: 250,
                  height: 300,
                  color: Color(int.parse('0xff${note.color}')),
                  margin: EdgeInsets.only(top: 10, right: 10),
                  padding: EdgeInsets.all(10),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(int.parse('0xff${note.textColor}')),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          SizedBox(height: 5),
                          Expanded(
                            child: ListView.builder(
                              controller: _verticalScrollControllers[note.id],
                              scrollDirection: Axis.vertical,
                              itemCount: note.lines.length,
                              itemBuilder: (context, lineIndex) {
                                final parts = note.lines[lineIndex].split('|');
                                final lineText = parts[0];
                                final lineColor = parts[1];
                                final isChecked = parts[2] == 'true';

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _controllers[note.id]?[lineIndex],
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          hintText: 'Enter text here...',
                                        ),
                                        maxLines: 1, // Limit to a single line
                                        textAlign: TextAlign.left,
                                        style: TextStyle(
                                          fontSize: 14.0, // Smaller text size
                                          color: Color(int.parse('0xff$lineColor')),
                                        ),
                                        onChanged: (newText) {
                                          setState(() {
                                            note.lines[lineIndex] = '$newText|$lineColor|$isChecked';
                                          });
                                        },
                                      ),
                                    ),
                                    TwoStateCheckbox(
                                      initialValue: isChecked,
                                      onChanged: (bool? value) {
                                        setState(() {
                                          note.lines[lineIndex] = '$lineText|$lineColor|$value';
                                        });
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.add),
                                  onPressed: () => _addLineToStickyNote(note),
                                ),
                                IconButton(
                                  icon: Icon(Icons.save),
                                  onPressed: () => _updateStickyNote(note),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Positioned(
  top: 0,
  right: 0,
  child: PopupMenuButton<String>(
    onSelected: (value) {
      if (value == 'Edit Header') {
        _editHeader(note);
      } else if (value == 'Delete Note') {
        _deleteStickyNote(note.id);
      }
    },
    itemBuilder: (BuildContext context) {
      return {'Edit Header', 'Delete Note'}.map((String choice) {
        return PopupMenuItem<String>(
          value: choice,
          child: Text(choice),
        );
      }).toList();
    },
    child: Icon(Icons.more_vert),
  ),
),

                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    ],
  );
}


void _editHeader(StickyNote note) async {
  TextEditingController _headerController = TextEditingController(text: note.title);

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Edit Header'),
        content: TextField(
          controller: _headerController,
          decoration: InputDecoration(hintText: 'Enter new header'),
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
              Navigator.of(context).pop();
              String newTitle = _headerController.text;
              if (newTitle.isNotEmpty) {
                await _updateStickyNoteHeader(note.id, newTitle);
              }
            },
            child: Text('Save'),
          ),
        ],
      );
    },
  );
}

}



class StickyNote {
  final String id;
  final String title;
  final String color;
  final String textColor;
  final List<String> lines;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String>? tags;

  StickyNote({
    required this.id,
    required this.title,
    required this.color,
    required this.textColor,
    required this.lines,
    required this.createdAt,
    this.updatedAt,
    this.tags,
  });

  factory StickyNote.fromJson(Map<String, dynamic> json) {
    return StickyNote(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      color: json['color'] ?? 'FFFFFF',
      textColor: json['text_color'] ?? '000000',
      lines: List<String>.from(
        json['lines']?.map((line) => _applyDefaultColor(line, json['text_color'])) ?? [],
      ),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
    );
  }

  static String _applyDefaultColor(String line, String? defaultColor) {
    final parts = line.split('|');
    if (parts.length < 2 || parts[1].isEmpty) {
      return '${parts[0]}|$defaultColor|${parts.length > 2 ? parts[2] : 'false'}';
    }
    return line;
  }

}
