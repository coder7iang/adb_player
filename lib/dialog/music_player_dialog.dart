import 'package:audioplayers/audioplayers.dart';
import 'package:adb_player/dialog/smart_dialog_utils.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MusicPlayerDialog extends StatefulWidget {
  const MusicPlayerDialog({Key? key}) : super(key: key);

  @override
  State<MusicPlayerDialog> createState() => _MusicPlayerDialogState();
}

class _MusicPlayerDialogState extends State<MusicPlayerDialog> {
  static const String _defaultAssetPath =
      "file/it's 6pm but I miss u already (0.8x).mp3";
  static const String _defaultAssetName =
      "it's 6pm but I miss u already (0.8x).mp3";

  final AudioPlayer _player = AudioPlayer();
  String? _filePath;
  String _fileName = '';
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  PlayerState _state = PlayerState.stopped;
  double _volume = 1.0;
  bool _seeking = false;

  @override
  void initState() {
    super.initState();
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted && !_seeking) setState(() => _position = p);
    });
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _state = PlayerState.completed;
        });
      }
    });
    _loadDefault();
  }

  Future<void> _loadDefault() async {
    try {
      setState(() {
        _filePath = 'asset:$_defaultAssetPath';
        _fileName = _defaultAssetName;
      });
      // BytesSource 避免 Windows 上 AssetSource 固定 Temp 路径被占用
      final byteData = await rootBundle.load('assets/$_defaultAssetPath');
      await _player.play(
        BytesSource(
          byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
        ),
      );
    } catch (e) {
      SmartDialogUtils.showError('默认音乐加载失败: $e');
    }
  }

  @override
  void dispose() {
    final player = _player;
    // 先停再释放，降低 Windows 文件占用概率
    player.stop().whenComplete(() => player.dispose());
    super.dispose();
  }

  Future<void> _pickFile() async {
    const typeGroup = XTypeGroup(
      label: '音频',
      extensions: ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg', 'opus', 'wma'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    await _player.stop();
    setState(() {
      _filePath = file.path;
      _fileName = file.name;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    try {
      await _player.setSource(DeviceFileSource(file.path));
    } catch (e) {
      SmartDialogUtils.showError('加载失败: $e');
    }
  }

  Future<void> _togglePlay() async {
    if (_filePath == null) {
      await _pickFile();
      if (_filePath == null) return;
    }
    if (_state == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> _stop() async {
    await _player.stop();
    setState(() => _position = Duration.zero);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _state == PlayerState.playing;
    final hasFile = _filePath != null;
    final maxMs = _duration.inMilliseconds.clamp(1, 1 << 30).toDouble();
    final posMs = _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble();
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 420, maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.music_note, color: Color(0xFF8E44AD)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '音乐播放器',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.audiotrack, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasFile ? _fileName : '尚未选择文件',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasFile ? Colors.black87 : Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('选择'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Slider(
                value: posMs.clamp(0, maxMs).toDouble(),
                min: 0,
                max: maxMs,
                onChangeStart: (_) => _seeking = true,
                onChanged: hasFile
                    ? (v) => setState(() {
                          _position = Duration(milliseconds: v.toInt());
                        })
                    : null,
                onChangeEnd: hasFile
                    ? (v) async {
                        await _player.seek(Duration(milliseconds: v.toInt()));
                        _seeking = false;
                      }
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Text(_fmt(_position),
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const Spacer(),
                    Text(_fmt(_duration),
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 28,
                    tooltip: '后退 10 秒',
                    onPressed: hasFile
                        ? () async {
                            final t = _position - const Duration(seconds: 10);
                            await _player.seek(t < Duration.zero ? Duration.zero : t);
                          }
                        : null,
                    icon: const Icon(Icons.replay_10),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF8E44AD),
                    ),
                    child: IconButton(
                      iconSize: 36,
                      color: Colors.white,
                      tooltip: isPlaying ? '暂停' : '播放',
                      onPressed: _togglePlay,
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    iconSize: 28,
                    tooltip: '前进 10 秒',
                    onPressed: hasFile
                        ? () async {
                            final t = _position + const Duration(seconds: 10);
                            await _player
                                .seek(t > _duration ? _duration : t);
                          }
                        : null,
                    icon: const Icon(Icons.forward_10),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    iconSize: 24,
                    tooltip: '停止',
                    onPressed: hasFile ? _stop : null,
                    icon: const Icon(Icons.stop),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.volume_down, size: 20, color: Colors.grey),
                  Expanded(
                    child: Slider(
                      value: _volume,
                      min: 0,
                      max: 1,
                      onChanged: (v) async {
                        setState(() => _volume = v);
                        await _player.setVolume(v);
                      },
                    ),
                  ),
                  const Icon(Icons.volume_up, size: 20, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
