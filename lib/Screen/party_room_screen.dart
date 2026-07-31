import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

// TODO: Replace with your own Agora App ID from console.agora.io
const String agoraAppId = "508ffabe8f984a6f897794fbccc4cec9";

class PartyRoomScreen extends StatefulWidget {
  final String roomId;
  const PartyRoomScreen({super.key, required this.roomId});

  @override
  State<PartyRoomScreen> createState() => _PartyRoomScreenState();
}

class _PartyRoomScreenState extends State<PartyRoomScreen> {
  static const int totalSeats = 8;

  User? get user => FirebaseAuth.instance.currentUser;
  late RtcEngine _engine;
  bool _engineReady = false;
  bool _isMicOn = false;
  int? _mySeatIndex;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    await [Permission.microphone].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: agoraAppId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    await _engine.setClientRole(role: ClientRoleType.clientRoleAudience);
    await _engine.enableAudio();
    await _engine.muteLocalAudioStream(true);

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint("Joined Agora channel: ${widget.roomId}");
        },
        onError: (err, msg) {
          debugPrint("Agora error: $err $msg");
        },
      ),
    );

    await _engine.joinChannel(
      // TEMP TOKEN: generated for roomId/channel = widget.roomId
      // Valid for 24 hours from generation time. Must regenerate daily
      // from Agora Console (Generate Temp Token) using the SAME channel name,
      // then paste the new value here.
      token:
          "007eJxTYDA58ik/851bvuatSiaPIEUJnf7/s39P4kx4Oalsody1hJMKDKYGFmlpiUmpFmmWFiaJZmkWlubmliZpScnJySbJqcmWvbHZWQ2BjAwrp+QzMTEwgiGIL8LgY5iUlFpiVObtE1aWlZtameVTmMXAwARXwcJgaGBgCAAcJifI",
      channelId: widget.roomId,
      uid: 0, // 0 = let Agora auto-assign a uid
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleAudience,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    setState(() => _engineReady = true);

    // If we already have a seat reserved (e.g. host), enable mic seat state
    _checkExistingSeat();
  }

  Future<void> _checkExistingSeat() async {
    final uid = user?.uid;
    if (uid == null) return;
    final seats = await FirebaseFirestore.instance
        .collection('party_rooms')
        .doc(widget.roomId)
        .collection('seats')
        .get();

    for (final doc in seats.docs) {
      if (doc.data()['uid'] == uid) {
        setState(() => _mySeatIndex = int.parse(doc.id));
        await _becomeSpeaker();
        break;
      }
    }
  }

  Future<void> _becomeSpeaker() async {
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.muteLocalAudioStream(false);
    setState(() => _isMicOn = true);
  }

  Future<void> _becomeAudience() async {
    await _engine.setClientRole(role: ClientRoleType.clientRoleAudience);
    await _engine.muteLocalAudioStream(true);
    setState(() => _isMicOn = false);
  }

  Future<void> _toggleMySeatMute() async {
    final newMuted = _isMicOn;
    await _engine.muteLocalAudioStream(newMuted);
    setState(() => _isMicOn = !newMuted);

    if (_mySeatIndex != null) {
      await FirebaseFirestore.instance
          .collection('party_rooms')
          .doc(widget.roomId)
          .collection('seats')
          .doc(_mySeatIndex.toString())
          .update({'isMuted': newMuted});
    }
  }

  Future<void> _joinSeat(int index, Map<String, dynamic>? existingData) async {
    final uid = user?.uid;
    if (uid == null || !_engineReady) return;

    // Seat already occupied by someone else
    if (existingData != null && existingData['uid'] != null && existingData['uid'] != uid) {
      return;
    }

    // Tapping own occupied seat -> toggle mute
    if (existingData != null && existingData['uid'] == uid) {
      await _toggleMySeatMute();
      return;
    }

    // Leave old seat first if seated elsewhere
    if (_mySeatIndex != null) {
      await _leaveSeat(_mySeatIndex!);
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};

    await FirebaseFirestore.instance
        .collection('party_rooms')
        .doc(widget.roomId)
        .collection('seats')
        .doc(index.toString())
        .set({
      'uid': uid,
      'name': userData['name'] ?? "User",
      'avatar': userData['avatar'] ?? "🧑",
      'isMuted': false,
    });

    setState(() => _mySeatIndex = index);
    await _becomeSpeaker();
  }

  Future<void> _leaveSeat(int index) async {
    await FirebaseFirestore.instance
        .collection('party_rooms')
        .doc(widget.roomId)
        .collection('seats')
        .doc(index.toString())
        .delete();

    setState(() => _mySeatIndex = null);
    await _becomeAudience();
  }

  Future<void> _leaveRoom() async {
    if (_mySeatIndex != null) {
      await _leaveSeat(_mySeatIndex!);
    }
    await _engine.leaveChannel();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  Widget _seatWidget(int index, Map<String, dynamic>? data) {
    final isOccupied = data != null && data['uid'] != null;
    final isMe = isOccupied && data['uid'] == user?.uid;
    final isMuted = data?['isMuted'] == true;

    return GestureDetector(
      onTap: () => _joinSeat(index, data),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isOccupied
                      ? const LinearGradient(colors: [Color(0xFFFF5F6D), Color(0xFFFFC371)])
                      : null,
                  color: isOccupied ? null : Colors.white10,
                  border: isMe ? Border.all(color: Colors.amberAccent, width: 2.5) : null,
                ),
                child: Center(
                  child: isOccupied
                      ? Text(data['avatar'] ?? "🧑", style: const TextStyle(fontSize: 26))
                      : const Icon(Icons.add, color: Colors.white38, size: 26),
                ),
              ),
              if (isOccupied)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0B1E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Icon(
                      isMuted ? Icons.mic_off : Icons.mic,
                      color: isMuted ? Colors.redAccent : Colors.greenAccent,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isOccupied ? (data['name'] ?? "User") : "Seat ${index + 1}",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: isOccupied ? Colors.white : Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('party_rooms').doc(widget.roomId).snapshots(),
          builder: (context, roomSnap) {
            final roomData = roomSnap.data?.data() as Map<String, dynamic>? ?? {};

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 20, 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: _leaveRoom,
                      ),
                      Expanded(
                        child: Text(
                          roomData['title'] ?? "Party Room",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (!_engineReady)
                        const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('party_rooms')
                        .doc(widget.roomId)
                        .collection('seats')
                        .snapshots(),
                    builder: (context, seatSnap) {
                      final Map<int, Map<String, dynamic>> seatMap = {};
                      if (seatSnap.hasData) {
                        for (final doc in seatSnap.data!.docs) {
                          seatMap[int.parse(doc.id)] = doc.data() as Map<String, dynamic>;
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        child: GridView.builder(
                          itemCount: totalSeats,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 20,
                            childAspectRatio: 0.8,
                          ),
                          itemBuilder: (context, index) => _seatWidget(index, seatMap[index]),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    border: const Border(top: BorderSide(color: Colors.white10)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: _mySeatIndex != null ? _toggleMySeatMute : null,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _mySeatIndex == null
                                ? Colors.white10
                                : (_isMicOn ? Colors.greenAccent.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2)),
                          ),
                          child: Icon(
                            _mySeatIndex == null
                                ? Icons.mic_off
                                : (_isMicOn ? Icons.mic : Icons.mic_off),
                            color: _mySeatIndex == null
                                ? Colors.white38
                                : (_isMicOn ? Colors.greenAccent : Colors.redAccent),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _leaveRoom,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFF512F), Color(0xFFDD2476)]),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text("Leave", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}