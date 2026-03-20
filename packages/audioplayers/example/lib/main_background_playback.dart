import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter音乐播放器',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MusicPlayerScreen(),
    );
  }
}

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  // 音频播放器实例
  final AudioPlayer? _audioPlayer = null;
  static GlobalAudioScope get _global => AudioPlayer.global;
  
  // 播放列表 - assets中的音频文件路径
  final List<String> _playlist = [
    'laser.wav',
    'ambient_c_motion.mp3',
    'nasa_on_a_mission.mp3',
  ];
  
  // 当前播放索引
  int _currentIndex = 0;
  
  // 播放状态
  bool _isPlaying = false;
  
  // 当前播放进度
  Duration _currentDuration = Duration.zero;
  Duration _totalDuration = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    AudioContext audioContext = AudioContext(ohos: AudioContextOhos(stayAwake: true));
    _global.setAudioContext(audioContext);
    _setupAudioPlayer();
  }
  
  void _setupAudioPlayer() {
    // 监听播放完成事件 - 自动播放下首的关键
    _audioPlayer?.onPlayerComplete.listen((event) {
      _playNext();
    });
    
    // 监听播放进度
    _audioPlayer?.onPositionChanged.listen((position) {
      setState(() {
        _currentDuration = position;
      });
    });
    
    // 监听歌曲总时长
    _audioPlayer?.onDurationChanged.listen((duration) {
      setState(() {
        _totalDuration = duration;
      });
    });
    
    // 监听播放状态变化
    _audioPlayer?.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });
  }
  
  // 播放当前歌曲
  Future<void> _playCurrent() async {
    try {
      // 停止当前播放（如果有）
      await _audioPlayer?.stop();
      
      // 从assets播放音频
      await _audioPlayer?.play(AssetSource(_playlist[_currentIndex]));
      
      print('开始播放: ${_playlist[_currentIndex]}');
    } catch (e) {
      print('播放失败: $e');
      // 如果播放失败，尝试播放下首
      _playNext();
    }
  }
  
  // 播放下一首
  Future<void> _playNext() async {
    if (_playlist.isEmpty) return;
    
    setState(() {
      _currentIndex = (_currentIndex + 1) % _playlist.length;
    });
    
    await _playCurrent();
  }
  
  // 播放上一首
  Future<void> _playPrevious() async {
    if (_playlist.isEmpty) return;
    
    setState(() {
      _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    });
    
    await _playCurrent();
  }
  
  // 播放/暂停
  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer?.pause();
    } else {
      if (_currentDuration.inSeconds > 0) {
        // 从当前位置继续播放
        await _audioPlayer?.resume();
      } else {
        // 开始播放当前歌曲
        await _playCurrent();
      }
    }
  }
  
  // 跳转到指定位置
  Future<void> _seekTo(double value) async {
    final position = Duration(seconds: value.toInt());
    await _audioPlayer?.seek(position);
  }
  
  // 格式化时间显示
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
  
  // 获取歌曲名称（从路径中提取）
  String _getSongName(String path) {
    // 从路径中提取文件名，如 "song1.mp3"
    final fileName = path.split('/').last;
    // 移除扩展名
    return fileName.split('.').first;
  }
  
  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter音乐播放器'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 当前播放歌曲显示
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Icon(
                      Icons.music_note,
                      size: 60,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _getSongName(_playlist[_currentIndex]),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '歌曲 ${_currentIndex + 1}/${_playlist.length}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // 进度条
            Column(
              children: [
                Slider(
                  value: _currentDuration.inSeconds.toDouble(),
                  min: 0,
                  max: _totalDuration.inSeconds.toDouble(),
                  onChanged: (value) {
                    _seekTo(value);
                  },
                  onChangeEnd: (value) {
                    _seekTo(value);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_currentDuration)),
                    Text(_formatDuration(_totalDuration)),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 30),
            
            // 播放控制按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 40,
                  onPressed: _playPrevious,
                ),
                const SizedBox(width: 20),
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle : Icons.play_circle,
                    size: 60,
                  ),
                  onPressed: _togglePlayPause,
                ),
                const SizedBox(width: 20),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  iconSize: 40,
                  onPressed: _playNext,
                ),
              ],
            ),
            
            const SizedBox(height: 40),
            
            // 播放列表
            Expanded(
              child: ListView.builder(
                itemCount: _playlist.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _currentIndex == index 
                          ? Colors.blue 
                          : Colors.grey[300],
                      child: Icon(
                        _currentIndex == index ? Icons.music_note : Icons.music_off,
                        color: _currentIndex == index ? Colors.white : Colors.grey,
                      ),
                    ),
                    title: Text(
                      _getSongName(_playlist[index]),
                      style: TextStyle(
                        fontWeight: _currentIndex == index 
                            ? FontWeight.bold 
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text('歌曲 ${index + 1}'),
                    trailing: _currentIndex == index && _isPlaying
                        ? const Icon(Icons.equalizer, color: Colors.blue)
                        : null,
                    onTap: () {
                      if (_currentIndex != index) {
                        setState(() {
                          _currentIndex = index;
                        });
                        _playCurrent();
                      } else {
                        _togglePlayPause();
                      }
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