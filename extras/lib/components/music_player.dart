import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'dart:html' as html;
import 'package:marquee/marquee.dart';
import 'scrolling_test.dart';


class MusicPlayer extends StatefulWidget {
  @override
  MusicPlayerState createState() => MusicPlayerState();
}

class MusicPlayerState extends State<MusicPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer(); // Audio player instance
  bool _isPlaying = false; // Track if music is playing
  bool _isFetching = false; // Track if music is being fetched
  html.AudioElement? _currentAudioElement;
  String? _currentSongName;

  @override
  void initState() {
    super.initState();
    _playRandomMusic(); // Auto-play on page load
  }

  // Function to play random music
  Future<void> _playRandomMusic() async {
    try {
      // Set fetching state
      setState(() {
        _isFetching = true;
        _currentSongName = 'Fetching music...';
      });

      // Stop and remove the current audio before playing new one
      stopAndRemoveCurrentAudio();

      final response = await http.get(Uri.parse('/music/play'));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final blob = html.Blob([bytes], 'audio/mpeg');
        final url = html.Url.createObjectUrl(blob);

        final audio = html.AudioElement(url)
          ..autoplay = true
          ..controls = false; // Hide controls

        audio.play(); // Play audio programmatically

        setState(() {
          _isPlaying = true; // Update state to show pause button
          _isFetching = false; // Stop fetching state
          _currentAudioElement = audio; // Track the current audio element
        });

        // Handle when the audio ends
        audio.onEnded.listen((event) {
          setState(() {
            _isPlaying = false;
          });
        });

        // Remove the audio element when done to avoid memory leaks
        audio.onEnded.listen((_) {
          audio.remove();
          _currentAudioElement = null; // Clear reference after removal
        });

        print('Playing music from bytes');

        // Delay before fetching metadata
        Future.delayed(Duration(seconds: 3), () async {
          try {
            final metadataResponse = await http.get(Uri.parse('/music/metadata'));
            if (metadataResponse.statusCode == 200) {
              setState(() {
                _currentSongName = metadataResponse.body + ' playing';
              });
            } else {
              print('Failed to load song metadata');
            }
          } catch (e) {
            print('Error fetching metadata: $e');
          }
        });
      } else {
        throw Exception('Failed to load music');
      }
    } catch (e) {
      print('Error playing music: $e');
      setState(() {
        _isFetching = false; // Stop fetching state in case of error
        _currentSongName = 'Failed to load music';
      });
    }
  }

  void stopAndRemoveCurrentAudio() {
    if (_currentAudioElement != null) {
      _currentAudioElement!.pause(); // Stop the audio
      _currentAudioElement!.remove(); // Remove the audio element from DOM
      _currentAudioElement = null; // Clear the reference
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[900],
      padding: EdgeInsets.all(10),
      child: Row(
        children: [
          // Song name scrolling text in a confined box
          Container(
            width: 250, // Width of the scrolling box
            child: ScrollingText(
              text: _currentSongName ?? 'No song playing',
              style: TextStyle(color: Colors.white),
            ),
          ),
          // Spacer to ensure the icons are centered
          Spacer(flex: 1),
          // Icon buttons
          Row(
            mainAxisSize: MainAxisSize.min, // Ensure this row is only as wide as its children
            children: [
              IconButton(
                icon: Icon(Icons.skip_previous),
                color: Colors.white,
                onPressed: () {},
              ),
              GestureDetector(
                onTap: _isPlaying ? null : _playRandomMusic,
                child: _isFetching
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : IconButton(
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        color: _isPlaying || _isFetching ? Colors.grey : Colors.white,
                        onPressed: _isPlaying || _isFetching ? null : _playRandomMusic,
                      ),
              ),

              IconButton(
                icon: Icon(Icons.skip_next),
                color: Colors.white,
                onPressed: () {
                  stopAndRemoveCurrentAudio();
                  _playRandomMusic();
                },
              ),
            ],
          ),
          // Spacer to push the icons to the center
          Spacer(flex: 2),
        ],
      ),
    );
  }


  @override
  void dispose() {
    stopAndRemoveCurrentAudio(); // Stop and remove audio when widget is disposed
    _audioPlayer.dispose(); // Dispose the audio player
    super.dispose();
  }
}
