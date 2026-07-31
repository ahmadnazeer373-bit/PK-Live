import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

// TODO: Replace with your own Agora App ID from console.agora.io
const String agoraAppId = "508ffabe8f984a6f897794fbccc4cec9";

// ASSUMPTIONS (adjust if your Firestore schema differs):
// - party_rooms/{roomId} doc has 'hostUid', 'hostName', 'hostAvatar' fields
//   (set these when the room is created). If missing, the host slot shows
//   a generic placeholder.
// - Subcollections used: seats/{seatIndex}, messages/{auto-id}, audience/{uid}

class PartyRoomScreen extends StatefulWidget {
  final String roomId;
  const PartyRoomScreen({super.key, required this.roomId});

  @override
  State<PartyRoomScreen> createState() => _PartyRoomScreenState();
}

class _PartyRoomScreenState extends State<PartyRoomScreen> {
  static const int totalSeats = 12;

  User? get user => FirebaseAuth.instance.currentUser;
  late RtcEngine _engine;
  bool _engineReady = false;
  bool _isMicOn = false;
  int? _mySeatIndex;

  final TextEditingController _messageController = TextEditingController();

  CollectionReference get _roomRef =>
      FirebaseFirestore.instance.collection('party_rooms').doc(widget.roomId).collection('seats');

  DocumentReference get _roomDoc => FirebaseFirestore.instance.collection('party_rooms').doc(widget.roomId);

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
      uid: 0,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleAudience,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    setState(() => _engineReady = true);

    final seated = await _checkExistingSeat();
    if (!seated) await _joinAsAudience();
  }

  Future<bool> _checkExistingSeat() async {
    final uid = user?.uid;
    if (uid == null) return false;
    final seats = await _roomRef.get();

    for (final doc in seats.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['uid'] == uid) {
        setState(() => _mySeatIndex = int.parse(doc.id));
        await _becomeSpeaker();
        return true;
      }
    }
    return false;
  }

  // ---------------- Audience presence ----------------

  Future<void> _joinAsAudience() async {
    final uid = user?.uid;
    if (uid == null) return;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};

    await _roomDoc.collection('audience').doc(uid).set({
      'uid': uid,
      'name': userData['name'] ?? "User",
      'avatar': userData['avatar'] ?? "🧑",
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _leaveAudience() async {
    final uid = user?.uid;
    if (uid == null) return;
    await _roomDoc.collection('audience').doc(uid).delete();
  }

  // ---------------- Seat / mic control ----------------

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
      await _roomRef.doc(_mySeatIndex.toString()).update({'isMuted': newMuted});
    }
  }

  Future<void> _joinSeat(int index, Map<String, dynamic>? existingData) async {
    final uid = user?.uid;
    if (uid == null || !_engineReady) return;

    if (existingData != null && existingData['uid'] != null && existingData['uid'] != uid) {
      return;
    }
    if (existingData != null && existingData['uid'] == uid) {
      await _toggleMySeatMute();
      return;
    }

    if (_mySeatIndex != null) {
      await _leaveSeat(_mySeatIndex!, rejoinAudience: false);
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};

    await _roomRef.doc(index.toString()).set({
      'uid': uid,
      'name': userData['name'] ?? "User",
      'avatar': userData['avatar'] ?? "🧑",
      'isMuted': false,
    });

    await _leaveAudience();
    setState(() => _mySeatIndex = index);
    await _becomeSpeaker();
  }

  Future<void> _leaveSeat(int index, {bool rejoinAudience = true}) async {
    await _roomRef.doc(index.toString()).delete();
    setState(() => _mySeatIndex = null);
    await _becomeAudience();
    if (rejoinAudience) await _joinAsAudience();
  }

  Future<void> _leaveRoom() async {
    if (_mySeatIndex != null) {
      await _leaveSeat(_mySeatIndex!, rejoinAudience: false);
    }
    await _leaveAudience();
    await _engine.leaveChannel();
    if (mounted) Navigator.pop(context);
  }

  // ---------------- Chat ----------------

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final uid = user?.uid;
    if (text.isEmpty || uid == null) return;

    _messageController.clear();

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final name = userDoc.data()?['name'] ?? "User";

    await _roomDoc.collection('messages').add({
      'text': text,
      'senderUid': uid,
      'senderName': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() {
    _leaveAudience();
    _engine.leaveChannel();
    _engine.release();
    _messageController.dispose();
    super.dispose();
  }

  // ---------------- UI pieces ----------------

  Widget _hostSlot(Map<String, dynamic> roomData) {
    final hostName = roomData['hostName'] ?? "Host";
    final hostAvatar = roomData['hostAvatar'] ?? "👑";
    final hasHost = roomData['hostUid'] != null;

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
              ),
              child: CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFF1A1A2E),
                child: Text(hasHost ? hostAvatar : "👑", style: const TextStyle(fontSize: 30)),
              ),
            ),
            const Positioned(
              top: -10,
              right: -6,
              child: Text("👑", style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          hasHost ? hostName : "Waiting for host",
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _seatWidget(int index, Map<String, dynamic>? data) {
    final isOccupied = data != null && data['uid'] != null;
    final isMe = isOccupied && data!['uid'] == user?.uid;
    final isMuted = data?['isMuted'] == true;

    return GestureDetector(
      onTap: () => _joinSeat(index, data),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isOccupied
                      ? const LinearGradient(colors: [Color(0xFFFF5F6D), Color(0xFFFFC371)])
                      : null,
                  color: isOccupied ? null : Colors.white.withOpacity(0.05),
                  border: Border.all(
                    color: isMe ? Colors.amberAccent : Colors.white.withOpacity(0.12),
                    width: isMe ? 2.2 : 1,
                  ),
                ),
                child: Center(
                  child: isOccupied
                      ? Text(data!['avatar'] ?? "🧑", style: const TextStyle(fontSize: 22))
                      : const Icon(Icons.lock_outline, color: Colors.white24, size: 20),
                ),
              ),
              if (isOccupied)
                Positioned(
                  bottom: -2,
                  right: -2,
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
                      size: 10,
                    ),
                  ),
                ),
              Positioned(
                top: -4,
                left: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "${index + 2}",
                    style: const TextStyle(color: Colors.white54, fontSize: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isOccupied ? (data!['name'] ?? "User") : "Empty",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: isOccupied ? Colors.white70 : Colors.white24, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _audienceStrip() {
    return StreamBuilder<QuerySnapshot>(
      stream: _roomDoc.collection('audience').orderBy('joinedAt', descending: true).limit(20).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
        final docs = snapshot.data!.docs;

        return SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white10,
                  child: Text(data['avatar'] ?? "🧑", style: const TextStyle(fontSize: 15)),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _chatSection() {
    return Container(
      height: 190,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _roomDoc
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final docs = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: "${data['senderName'] ?? 'User'}: ",
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: data['text'] ?? "",
                              style: const TextStyle(color: Colors.white, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _mySeatIndex != null ? _toggleMySeatMute : null,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _mySeatIndex == null
                    ? Colors.white10
                    : (_isMicOn ? Colors.greenAccent.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2)),
              ),
              child: Icon(
                _mySeatIndex == null ? Icons.mic_off : (_isMicOn ? Icons.mic : Icons.mic_off),
                size: 20,
                color: _mySeatIndex == null
                    ? Colors.white38
                    : (_isMicOn ? Colors.greenAccent : Colors.redAccent),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: const InputDecoration(
                  hintText: "Say something...",
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.amberAccent, size: 20),
            onPressed: _sendMessage,
          ),
          IconButton(
            icon: const Icon(Icons.card_giftcard, color: Colors.pinkAccent, size: 20),
            onPressed: () {
              // TODO: wire this to your gifting screen once it's built.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Gifting flow abhi connect karna hai")),
              );
            },
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
          stream: _roomDoc.snapshots(),
          builder: (context, roomSnap) {
            final roomData = roomSnap.data?.data() as Map<String, dynamic>? ?? {};

            return Column(
              children: [
                // ---------- Top bar ----------
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 16, 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                        onPressed: _leaveRoom,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              roomData['title'] ?? "Party Room",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "ID: ${widget.roomId}",
                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      if (!_engineReady)
                        const Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.amberAccent, strokeWidth: 2),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                        onPressed: _leaveRoom,
                      ),
                    ],
                  ),
                ),

                // ---------- Host + Seats (scrollable, taake chhote screens par overflow na aaye) ----------
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: _hostSlot(roomData),
                        ),
                        const SizedBox(height: 10),
                        StreamBuilder<QuerySnapshot>(
                          stream: _roomRef.snapshots(),
                          builder: (context, seatSnap) {
                            final Map<int, Map<String, dynamic>> seatMap = {};
                            if (seatSnap.hasData) {
                              for (final doc in seatSnap.data!.docs) {
                                seatMap[int.parse(doc.id)] = doc.data() as Map<String, dynamic>;
                              }
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: totalSeats,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.78,
                                ),
                                itemBuilder: (context, index) => _seatWidget(index, seatMap[index]),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        _audienceStrip(),
                      ],
                    ),
                  ),
                ),

                // ---------- Chat / Comments ----------
                _chatSection(),

                // ---------- Bottom control bar ----------
                _bottomBar(),
              ],
            );
          },
        ),
      ),
    );
  }
}