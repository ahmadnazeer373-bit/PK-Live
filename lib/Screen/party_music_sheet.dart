import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Party-room music controller.
///
/// The selected file stays on the controller's device. Agora Audio Mixing
/// publishes that local audio to the room, so every remote participant hears
/// the same music stream without uploading the song to Firebase/Cloudinary.
Future<void> openPartyMusicSheet({
  required BuildContext context,
  required RtcEngine engine,
  required String roomId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _PartyMusicSheet(
      engine: engine,
      roomId: roomId,
    ),
  );
}

class _PartyMusicSheet extends StatefulWidget {
  final RtcEngine engine;
  final String roomId;

  const _PartyMusicSheet({
    required this.engine,
    required this.roomId,
  });

  @override
  State<_PartyMusicSheet> createState() => _PartyMusicSheetState();
}

class _PartyMusicSheetState extends State<_PartyMusicSheet> {
  User? get _user => FirebaseAuth.instance.currentUser;

  late Directory _musicDirectory;
  List<FileSystemEntity> _songs = [];
  bool _loading = true;
  bool _busy = false;
  String? _playingPath;
  bool _isPaused = false;
  bool _controllerLocked = false;
  int _volume = 100;

  DocumentReference get _musicDoc => FirebaseFirestore.instance
      .collection('party_rooms')
      .doc(widget.roomId)
      .collection('music')
      .doc('player');

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _musicDirectory = Directory('${appDir.path}/party_music');
      if (!await _musicDirectory.exists()) {
        await _musicDirectory.create(recursive: true);
      }

      final entities = await _musicDirectory.list().toList();
      entities.removeWhere((e) => e is! File);
      entities.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));

      if (mounted) {
        setState(() {
          _songs = entities;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('Playlist load nahi ho saki: $e');
      }
    }
  }

  String _displayName(FileSystemEntity entity) {
    final path = entity.path;
    final slash = path.lastIndexOf(Platform.pathSeparator);
    return slash >= 0 ? path.substring(slash + 1) : path;
  }

  Future<void> _importSongs() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;

      setState(() => _busy = true);
      int imported = 0;

      for (final picked in result.files) {
        final sourcePath = picked.path;
        if (sourcePath == null || sourcePath.isEmpty) continue;

        final source = File(sourcePath);
        if (!await source.exists()) continue;

        final safeName = picked.name
            .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
            .trim();
        if (safeName.isEmpty) continue;

        var target = File('${_musicDirectory.path}/$safeName');
        if (await target.exists()) {
          final dot = safeName.lastIndexOf('.');
          final base = dot > 0 ? safeName.substring(0, dot) : safeName;
          final ext = dot > 0 ? safeName.substring(dot) : '';
          target = File(
            '${_musicDirectory.path}/${base}_${DateTime.now().millisecondsSinceEpoch}$ext',
          );
        }

        await source.copy(target.path);
        imported++;
      }

      await _loadSongs();
      if (mounted && imported > 0) {
        _showMessage('$imported song playlist mein add ho gaye');
      }
    } catch (e) {
      _showError('Song import nahi ho saka: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _claimController() async {
    final uid = _user?.uid;
    if (uid == null) return false;

    try {
      final claimed = await FirebaseFirestore.instance.runTransaction<bool>((tx) async {
        final snap = await tx.get(_musicDoc);
        final data = snap.data() as Map<String, dynamic>? ?? {};
        final currentUid = data['controllerUid'] as String?;
        final playing = data['playing'] == true;

        if (playing && currentUid != null && currentUid != uid) {
          return false;
        }

        tx.set(_musicDoc, {
          'controllerUid': uid,
          'playing': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return true;
      });

      if (claimed && mounted) setState(() => _controllerLocked = true);
      return claimed;
    } catch (e) {
      _showError('Music control lock nahi mil saka: $e');
      return false;
    }
  }

  Future<void> _startSong(File file) async {
    if (_busy) return;
    final uid = _user?.uid;
    if (uid == null) return;

    setState(() => _busy = true);
    try {
      final claimed = await _claimController();
      if (!claimed) {
        _showError('Room mein koi aur admin/host music chala raha hai. Pehle usay stop karna hoga.');
        return;
      }

      // In LiveBroadcasting mode an audience member cannot publish. Temporarily
      // promote a non-seated controller, while keeping its mic muted.
      final seats = await FirebaseFirestore.instance
          .collection('party_rooms')
          .doc(widget.roomId)
          .collection('seats')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      final wasSeated = seats.docs.isNotEmpty;

      await widget.engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await widget.engine.muteLocalAudioStream(true);

      // loopback=false => local + remote users hear the music.
      // cycle=1 => play the selected song once.
      await widget.engine.startAudioMixing(
        filePath: file.path,
        loopback: false,
        cycle: 1,
        startPos: 0,
      );
      await widget.engine.adjustAudioMixingPlayoutVolume(_volume);
      await widget.engine.adjustAudioMixingPublishVolume(_volume);

      await _musicDoc.set({
        'controllerUid': uid,
        'trackName': _displayName(file),
        'playing': true,
        'paused': false,
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'wasSeated': wasSeated,
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _playingPath = file.path;
          _isPaused = false;
          _controllerLocked = true;
        });
      }
    } catch (e) {
      await _releaseController();
      _showError('Song play nahi ho saka: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pauseOrResume() async {
    if (_playingPath == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (_isPaused) {
        await widget.engine.resumeAudioMixing();
        await _musicDoc.set({
          'playing': true,
          'paused': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await widget.engine.pauseAudioMixing();
        await _musicDoc.set({
          'playing': true,
          'paused': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (mounted) setState(() => _isPaused = !_isPaused);
    } catch (e) {
      _showError('Music state change nahi ho saka: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopMusic() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.engine.stopAudioMixing();
      await _musicDoc.set({
        'controllerUid': null,
        'trackName': null,
        'playing': false,
        'paused': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _playingPath = null;
          _isPaused = false;
          _controllerLocked = false;
        });
      }
    } catch (e) {
      _showError('Music stop nahi ho saki: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSong(File file) async {
    if (_playingPath == file.path) {
      _showError('Jo song abhi play ho raha hai usay pehle stop karein.');
      return;
    }
    try {
      await file.delete();
      await _loadSongs();
    } catch (e) {
      _showError('Song delete nahi ho saka: $e');
    }
  }

  Future<void> _releaseController() async {
    try {
      await _musicDoc.set({
        'controllerUid': null,
        'playing': false,
        'paused': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
    if (mounted) setState(() => _controllerLocked = false);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.78),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF241E42), Color(0xFF17142B)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFE082), Color(0xFFFFA000)],
                    ),
                  ),
                  child: const Icon(Icons.library_music_rounded, color: Colors.black87),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Room Music', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                      SizedBox(height: 3),
                      Text('Host/Admin music control', style: TextStyle(color: Colors.white54, fontSize: 11.5)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : _importSongs,
                  tooltip: 'Import songs',
                  icon: const Icon(Icons.add_circle_outline, color: Colors.amberAccent),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<DocumentSnapshot>(
              stream: _musicDoc.snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                final track = data['trackName'] as String?;
                final playing = data['playing'] == true;
                final paused = data['paused'] == true;
                if (track == null || !playing) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(paused ? Icons.pause_circle_outline : Icons.music_note_rounded, color: Colors.amberAccent, size: 19),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          track,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _songs.isEmpty ? 'Playlist empty hai' : '${_songs.length} song${_songs.length == 1 ? '' : 's'} imported',
                    style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                  ),
                ),
                if (_playingPath != null) ...[
                  IconButton(
                    onPressed: _busy ? null : _pauseOrResume,
                    icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: _busy ? null : _stopMusic,
                    icon: const Icon(Icons.stop_rounded, color: Colors.redAccent),
                  ),
                ],
              ],
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.volume_down_rounded, color: Colors.white54, size: 18),
                Expanded(
                  child: Slider(
                    value: _volume.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    activeColor: Colors.amberAccent,
                    inactiveColor: Colors.white12,
                    onChanged: _playingPath == null ? null : (value) {
                      setState(() => _volume = value.round());
                      widget.engine.adjustAudioMixingPlayoutVolume(_volume);
                      widget.engine.adjustAudioMixingPublishVolume(_volume);
                    },
                  ),
                ),
                const Icon(Icons.volume_up_rounded, color: Colors.white54, size: 18),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
                  : _songs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.library_music_outlined, color: Colors.white24, size: 48),
                              const SizedBox(height: 10),
                              const Text('Apne mobile se songs import karein', style: TextStyle(color: Colors.white54)),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _busy ? null : _importSongs,
                                icon: const Icon(Icons.add),
                                label: const Text('Import Songs'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amberAccent,
                                  foregroundColor: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _songs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 5),
                          itemBuilder: (context, index) {
                            final file = _songs[index] as File;
                            final isPlaying = _playingPath == file.path;
                            return Container(
                              decoration: BoxDecoration(
                                color: isPlaying ? Colors.amber.withOpacity(0.10) : Colors.white.withOpacity(0.035),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: isPlaying ? Colors.amber.withOpacity(0.25) : Colors.white.withOpacity(0.06),
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 19,
                                  backgroundColor: isPlaying ? Colors.amberAccent : Colors.white.withOpacity(0.07),
                                  child: Icon(
                                    isPlaying ? Icons.equalizer_rounded : Icons.music_note_rounded,
                                    color: isPlaying ? Colors.black87 : Colors.white54,
                                    size: 19,
                                  ),
                                ),
                                title: Text(
                                  _displayName(file),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: _busy || isPlaying ? null : () => _startSong(file),
                                      icon: Icon(
                                        Icons.play_circle_fill_rounded,
                                        color: isPlaying ? Colors.amberAccent : Colors.white70,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _busy || isPlaying ? null : () => _deleteSong(file),
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 20),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
