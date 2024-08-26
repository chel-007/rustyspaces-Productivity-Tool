import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../auth_service.dart';
import 'package:another_flushbar/flushbar.dart';


class TimeTracker extends StatefulWidget {
  final String spaceName;

  TimeTracker({required this.spaceName});

  @override
  _TimeTrackerState createState() => _TimeTrackerState();
}

class _TimeTrackerState extends State<TimeTracker> {
  Duration _elapsedTime = Duration.zero;
  late Stopwatch _stopwatch;
  late Timer _timer;
  String? _activityName;
  bool _isTracking = false;
  bool _isActivityNameSet = false;
  List<Map<String, dynamic>> _activityHistory = [];
  Future<List<Map<String, dynamic>>>? _fetchFuture;
  final TextEditingController _activityController = TextEditingController();
  String? _sessionId;

  final Map<String, String> _headers = {"Content-Type": "application/json"};

@override
void initState() {
  super.initState();
  _stopwatch = Stopwatch();
  _timer = Timer.periodic(Duration(seconds: 1), _updateTime);

      Future.delayed(Duration(milliseconds: 100), () {
      
      _fetchFuture = _fetchAllTimeTrackingSessions();
    });

}

  Future<void> _startTimer() async {
    String formattedTime = DateFormat('yyyy-MM-ddTHH:mm:ss').format(DateTime.now());
    _showToast(context, 'Starting tracking for ${_activityName?? "Unnamed Activity"}');
    final response = await http.post(
      Uri.parse('/track/start?space_name=${widget.spaceName}'),
      headers: _headers,
      body: jsonEncode({
        "activity_name": _activityName ?? "Unnamed Activity",
        "start_time": formattedTime,
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      _sessionId = jsonResponse['id'];
      print(_sessionId);
      setState(() {
        _isTracking = true;
      });
      _stopwatch.start();
    } else {
      _showToast(context, 'Failed to start time tracking. Please refresh and try again');
      print('Failed to start time tracking: ${response.body}');
    }
  }

Future<List<Map<String, dynamic>>> _fetchAllTimeTrackingSessions() async {
  final response = await http.get(
    Uri.parse('/track/time_tracking?space_name=${widget.spaceName}'),
    headers: _headers,
  );

  if (response.statusCode == 200) {
    final List<dynamic> jsonResponse = jsonDecode(response.body);

    final sessions = jsonResponse.map((entry) {
      final activityName = entry['activity_name'] ?? 'Unknown Activity';
      final duration = entry['duration'] ?? 0; // Default to 0 if null
      final id = entry['id'] as String; // Ensure ID is treated as a string

      // Convert duration from seconds to formatted string (HH:MM:SS)
      final elapsedTime = _formatDuration(duration);

      return {
        'id': id,
        'activity_name': activityName,
        'duration': duration,
        'user_id': entry['user_id'],
        'description': '$activityName - $elapsedTime',
      };
    }).toList();

    // Update activity history
    _updateActivityHistory(sessions);

    return sessions;
  } else {
    _showToast(context, 'Failed to fetch time tracking. Please refresh');
    print('Failed to fetch time tracking sessions: ${response.body}');
    return []; // Return an empty list in case of failure
  }
}

// function to format duration
String _formatDuration(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} hours';
  } else if (minutes > 0) {
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} min';
  } else {
    return '$seconds sec';
  }
}

void _updateActivityHistory(List<Map<String, dynamic>> sessions) {
  setState(() {
    _activityHistory = sessions; // Update the activity history with the fetched sessions
  });
}





Future<void> _completeActivity(String sessionId) async {
  try {
  
    final localEndTime = DateTime.now();
final backendTimeOffset = Duration(hours: 1);
final adjustedEndTime = localEndTime.add(backendTimeOffset);



final endTimeInSeconds = adjustedEndTime.millisecondsSinceEpoch ~/ 1000;

print(adjustedEndTime);
print(endTimeInSeconds);

_showToast(context, 'Saving time track for ${_activityName?? "Unnamed Activity"}');
    final response = await http.post(
      Uri.parse('/track/complete?session_id=$sessionId&end_time=$endTimeInSeconds'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      print('Failed to complete activity: ${response.body}');
    }
  } catch (e) {
    print('Error completing activity: $e');
  }
}




Future<void> _deleteActivity(String id) async {
  _showToast(context, 'Deleting time track for ${_activityName?? "Unnamed Activity"}');
  final response = await http.delete(
    Uri.parse('/track/delete?session_id=$id'),
    headers: _headers,
  );

  if (response.statusCode == 200) {
    _showToast(context, 'Deleted ${_activityName?? "Unnamed Activity"}');
    setState(() {
      _activityHistory.removeWhere((entry) => entry['id'] == id);
    });
  } else {
    print('Failed to delete activity: ${response.body}');
  }
}


  void _handleEnterActivityName() {
    setState(() {
      _activityName = _activityController.text;
      _isActivityNameSet = true;
    });
    _startTimer();
  }

  void _updateTime(Timer timer) {
    if (_stopwatch.isRunning) {
      setState(() {
        _elapsedTime = _stopwatch.elapsed;
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _activityController.dispose();
    super.dispose();
  }

  void _showToast(BuildContext context, String message) {
  Flushbar(
    message: message,
    duration: Duration(seconds: 2),
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
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 350, // Fixed width for the time tracker
          height: 300,
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Time Tracker',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Text(
                '${_elapsedTime.inHours.toString().padLeft(2, '0')}:${(_elapsedTime.inMinutes % 60).toString().padLeft(2, '0')}:${(_elapsedTime.inSeconds % 60).toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              if (!_isActivityNameSet)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _activityController,
                        decoration: InputDecoration(
                          hintText: 'Enter activity name',
                          fillColor: Colors.white,
                          filled: true,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _handleEnterActivityName,
                      child: Text('Enter'),
                    ),
                  ],
                ),
              if (_isActivityNameSet)
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _isTracking ? null : _startTimer,
                      child: Text('Start'),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isTracking ? _stopTimer : null,
                      child: Text('Stop'),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _resetTimer,
                      child: Text('Reset'),
                    ),
                  ],
                ),
            ],
          ),
        ),
        SizedBox(width: 20), // Space between the two containers

        // Activity History Container with Fixed Width
      Container(
        width: 250,
        height: 300,
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity History',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 5),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchFuture,
              builder: (context, snapshot) {
                // print('Snapshot connection state: ${snapshot.connectionState}');
                // print('Snapshot data: ${snapshot.data}');
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  // print('Error: ${snapshot.error}');
                  return Center(child: Text('Error loading activity history'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No activity history available'));
                } else {
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final entry = snapshot.data![index];
                      return ListTile(
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                        title: Text(
                          '${entry['description']}',
                          style: TextStyle(color: Colors.black),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.black),
                          onPressed: () => _deleteActivity(entry['id']),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    ),
      ],
    );
  }

void _stopTimer() async {
  if (_stopwatch.isRunning) {
    try {
      final sessions = await _fetchAllTimeTrackingSessions();
      final userId = await AuthService.silentAuth();

      if (userId == null) {
        print('User not authenticated');
        return;
      }
        final sessionToComplete = sessions.firstWhere(
        (session) => (session['duration'] == null || session['duration'] == 0) && session['user_id'] == userId,
        orElse: () => {},
        );

        if (sessionToComplete.isEmpty) {
        print('No session found to complete');
        return;
        }

      final sessionId = sessionToComplete['id'];

      await _completeActivity(sessionId);

            setState(() {
        _fetchFuture = _fetchAllTimeTrackingSessions();
      });


      _isTracking = false;
      _activityName = null;
      _isActivityNameSet = false;
      _activityController.clear();
      _stopwatch.stop();
    } catch (e) {
      _showToast(context, 'Error stopping timer. Please try again');
      print('Error stopping timer: $e');
    }
  }
}




  void _resetTimer() {
    _stopwatch.reset();
    setState(() {
      _elapsedTime = Duration.zero;
    });
  }
}
