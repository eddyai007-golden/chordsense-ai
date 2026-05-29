import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const ChordSenseApp());
}

class ChordSenseApp extends StatelessWidget {
  const ChordSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChordSense AI',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _record = AudioRecorder();
  
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _audioPath;
  Uint8List? _webAudioBytes;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _record.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.audio,
      withData: true,
    );

    if (result != null) {
      setState(() {
        if (kIsWeb) {
          _webAudioBytes = result.files.single.bytes;
          _audioPath = result.files.single.name;
          _audioPlayer.setSourceBytes(_webAudioBytes!);
        } else {
          _audioPath = result.files.single.path;
          _audioPlayer.setSourceDeviceFile(_audioPath!);
        }
      });
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (await _record.hasPermission()) {
        if (_isRecording) {
          final path = await _record.stop();
          setState(() {
            _isRecording = false;
            _audioPath = path;
          });
          if (path != null && !kIsWeb) {
             _audioPlayer.setSourceDeviceFile(path);
          }
        } else {
          Directory tempDir = await getTemporaryDirectory();
          String path = '${tempDir.path}/recorded_audio.m4a';
          await _record.start(const RecordConfig(), path: path);
          setState(() {
            _isRecording = true;
          });
        }
      }
    } catch (e) {
      _showError('Recording error: $e');
    }
  }

  Future<void> _analyzeAudio() async {
    if (_audioPath == null && _webAudioBytes == null) {
      _showError('Please upload or record an audio file first.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String baseUrl = kIsWeb ? 'http://127.0.0.1:8000' : (Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000');
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze/file'));
      
      if (kIsWeb && _webAudioBytes != null) {
         request.files.add(http.MultipartFile.fromBytes('file', _webAudioBytes!, filename: _audioPath ?? 'audio.mp3'));
      } else {
         request.files.add(await http.MultipartFile.fromPath('file', _audioPath!));
      }
      
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonResult = jsonDecode(responseData);
        
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultsScreen(
              results: jsonResult, 
              audioPath: _audioPath,
              webBytes: _webAudioBytes,
            ),
          ),
        );
      } else {
        _showError('Failed to analyze audio');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChordSense AI', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: _isLoading 
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.deepPurpleAccent),
                  SizedBox(height: 20),
                  Text("Analyzing chords and rhythm...")
                ]
              )
            : SingleChildScrollView(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.music_note, size: 100, color: Colors.deepPurpleAccent),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: _pickAudioFile,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Audio File'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.1))
                      ),
                      child: Column(
                        children: [
                          Text(_audioPath != null ? "Audio Ready" : "No Audio Selected", style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.fast_rewind),
                                onPressed: () async {
                                  var pos = await _audioPlayer.getCurrentPosition();
                                  if (pos != null) {
                                    _audioPlayer.seek(pos - const Duration(seconds: 5));
                                  }
                                },
                              ),
                              IconButton(
                                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                                iconSize: 40,
                                onPressed: () {
                                  if (_isPlaying) {
                                    _audioPlayer.pause();
                                  } else {
                                    _audioPlayer.resume();
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.stop),
                                onPressed: () {
                                  _audioPlayer.stop();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.fast_forward),
                                onPressed: () async {
                                  var pos = await _audioPlayer.getCurrentPosition();
                                  if (pos != null) {
                                    _audioPlayer.seek(pos + const Duration(seconds: 5));
                                  }
                                },
                              ),
                              const SizedBox(width: 10),
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isRecording ? Colors.red.withOpacity(0.2) : Colors.transparent,
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.mic, color: _isRecording ? Colors.red : Colors.white),
                                  onPressed: kIsWeb ? () => _showError("Recording not supported on Web preview") : _toggleRecording,
                                  tooltip: 'Record Audio',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: _analyzeAudio,
                      icon: const Icon(Icons.analytics),
                      label: const Text('Analyze Audio'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurpleAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ],
                ),
            ),
      ),
    );
  }
}

class ResultsScreen extends StatefulWidget {
  final Map<String, dynamic> results;
  final String? audioPath;
  final Uint8List? webBytes;

  const ResultsScreen({super.key, required this.results, this.audioPath, this.webBytes});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _scrollController = ScrollController();
  Duration _currentPosition = Duration.zero;
  bool _isPlaying = false;
  int _activeChordIndex = -1;

  @override
  void initState() {
    super.initState();
    _setupAudio();
  }

  void _updateActiveChord(Duration pos) {
    List chords = widget.results['chords'] ?? [];
    double currentSecs = pos.inMilliseconds / 1000.0;
    int newIndex = -1;
    for (int i = 0; i < chords.length; i++) {
      double start = (chords[i]['start_time'] as num).toDouble();
      double end = (chords[i]['end_time'] as num).toDouble();
      if (currentSecs >= start && currentSecs < end) {
        newIndex = i;
        break;
      }
    }
    
    if (newIndex != _activeChordIndex && newIndex != -1) {
      setState(() {
        _activeChordIndex = newIndex;
      });
      if (_scrollController.hasClients) {
        double viewportWidth = _scrollController.position.viewportDimension;
        double offset = (newIndex * 160.0) - (viewportWidth / 2) + 80.0;
        if (offset < 0) offset = 0;
        if (offset > _scrollController.position.maxScrollExtent) {
          offset = _scrollController.position.maxScrollExtent;
        }
        
        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else if (newIndex == -1 && _activeChordIndex != -1) {
       setState(() {
         _activeChordIndex = -1;
       });
    }
  }

  void _setupAudio() async {
    if (kIsWeb && widget.webBytes != null) {
      await _audioPlayer.setSourceBytes(widget.webBytes!);
    } else if (widget.audioPath != null) {
      await _audioPlayer.setSourceDeviceFile(widget.audioPath!);
    }
    
    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() {
          _currentPosition = pos;
        });
        _updateActiveChord(pos);
      }
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List chords = widget.results['chords'] ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Analysis Results')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.black26,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.fast_rewind),
                  onPressed: () {
                     _audioPlayer.seek(_currentPosition - const Duration(seconds: 5));
                  },
                ),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  iconSize: 40,
                  onPressed: () {
                    if (_isPlaying) {
                      _audioPlayer.pause();
                    } else {
                      _audioPlayer.resume();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.fast_forward),
                  onPressed: () {
                     _audioPlayer.seek(_currentPosition + const Duration(seconds: 5));
                  },
                ),
                const SizedBox(width: 20),
                Text(
                  "${_currentPosition.inMinutes}:${(_currentPosition.inSeconds % 60).toString().padLeft(2, '0')}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                )
              ],
            ),
          ),
          
          Expanded(
            child: Center(
              child: SizedBox(
                height: 200,
                child: ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: chords.length,
                  itemBuilder: (context, index) {
                    var c = chords[index];
                    double start = (c['start_time'] as num).toDouble();
                    double end = (c['end_time'] as num).toDouble();
                    bool isActive = index == _activeChordIndex;
                    
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 150,
                      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green.withOpacity(0.2) : Colors.black12,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isActive ? Colors.green : Colors.green.withOpacity(0.3),
                          width: isActive ? 3 : 1,
                        )
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.music_note, color: isActive ? Colors.greenAccent : Colors.green),
                          const SizedBox(height: 15),
                          Text(
                            c['chord'], 
                            style: TextStyle(
                              fontSize: isActive ? 36 : 24, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.green
                            )
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${start.toStringAsFixed(1)}s - ${end.toStringAsFixed(1)}s', 
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.white54, 
                              fontSize: 14
                            )
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
