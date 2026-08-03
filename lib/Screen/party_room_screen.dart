import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'send_gift_sheet.dart';
import 'chat_screen.dart';

// TODO: Replace with your own Agora App ID from console.agora.io
const String agoraAppId = "508ffabe8f984a6f897794fbccc4cec9";

// NOTE: The host does not get a reserved/fixed seat — everyone (including
// the host) just takes any open seat like a normal participant. Gifts can
// be sent to any currently seated user (tap their seat, or use the gift
// icon in the bottom bar to pick from everyone seated).

class PartyRoomScreen extends StatefulWidget {
  final String roomId;
  const PartyRoomScreen({super.key, required this.roomId});

  @override
  State<PartyRoomScreen> createState() => _PartyRoomScreenState();
}

class _PartyRoomScreenState extends State<PartyRoomScreen> {
  static const int totalSeats = 12;
  static const int maxAdmins = 8;

  User? get user => FirebaseAuth.instance.currentUser;
  late RtcEngine _engine;
  bool _engineReady = false;
  bool _isMicOn = false;
  int? _mySeatIndex;
  bool _isSwitchingSeat = false;

  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  StreamSubscription<DocumentSnapshot>? _kickListener;

  CollectionReference get _roomRef =>
      FirebaseFirestore.instance.collection('party_rooms').doc(widget.roomId).collection('seats');

  DocumentReference get _roomDoc => FirebaseFirestore.instance.collection('party_rooms').doc(widget.roomId);

  @override
  void initState() {
    super.initState();
    _checkBanAndEnter();
  }

  Future<void> _checkBanAndEnter() async {
    final uid = user?.uid;
    if (uid != null) {
      final banDoc = await _roomDoc.collection('banned').doc(uid).get();
      if (banDoc.exists) {
        final expiresAt = (banDoc.data()?['expiresAt'] as Timestamp?)?.toDate();
        if (expiresAt != null && expiresAt.isAfter(DateTime.now())) {
          final remaining = expiresAt.difference(DateTime.now());
          final hours = remaining.inHours;
          final mins = remaining.inMinutes % 60;
          if (mounted) {
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF1B1930),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text("Aap Banned Hain", style: TextStyle(color: Colors.white)),
                content: Text(
                  "Is room mein aap $hours ghante $mins minute baad dobara aa sakte hain.",
                  style: const TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("OK", style: TextStyle(color: Colors.amberAccent)),
                  ),
                ],
              ),
            );
            if (mounted) Navigator.pop(context);
          }
          return;
        } else {
          // Ban expired naturally — clean it up.
          await banDoc.reference.delete().catchError((_) {});
        }
      }
    }

    _initAgora();
    _listenForKick();
  }

  void _listenForKick() {
    final uid = user?.uid;
    if (uid == null) return;
    _kickListener = _roomDoc.collection('kicked').doc(uid).snapshots().listen((snap) {
      if (snap.exists) _handleKicked();
    });
  }

  Future<void> _handleKicked() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Aapko is room se nikal diya gaya hai")),
    );
    await _leaveRoom(kicked: true);
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

  Future<void> _syncMicFromRemote(bool shouldBeOn) async {
    if (_isMicOn == shouldBeOn) return;
    await _engine.muteLocalAudioStream(!shouldBeOn);
    if (mounted) setState(() => _isMicOn = shouldBeOn);
  }

  bool _isModerator(Map<String, dynamic> roomData) {
    final uid = user?.uid;
    if (uid == null) return false;
    if (roomData['hostUid'] == uid) return true;
    final admins = (roomData['admins'] as List?) ?? [];
    return admins.contains(uid);
  }

  bool _isHost(Map<String, dynamic> roomData) => user?.uid != null && roomData['hostUid'] == user?.uid;

  Future<void> _setSeatMute(int seatIndex, bool muted) async {
    await _roomRef.doc(seatIndex.toString()).update({'isMuted': muted});
  }

  Future<void> _kickUser(String targetUid, int seatIndex, String targetName) async {
    final myUid = user?.uid;
    await _roomRef.doc(seatIndex.toString()).delete();
    await _roomDoc.collection('audience').doc(targetUid).delete().catchError((_) {});
    await _roomDoc.collection('kicked').doc(targetUid).set({'kickedAt': FieldValue.serverTimestamp()});
    await _roomDoc.collection('banned').doc(targetUid).set({
      'name': targetName,
      'bannedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
      'bannedBy': myUid,
    });
  }

  Future<void> _unbanUser(String targetUid) async {
    await _roomDoc.collection('banned').doc(targetUid).delete();
  }

  void _openBannedUsersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF241E42), Color(0xFF17142B)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.block, color: Colors.redAccent.withOpacity(0.8), size: 18),
                  const SizedBox(width: 8),
                  const Text("Banned Users", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: StreamBuilder<QuerySnapshot>(
                  stream: _roomDoc.collection('banned').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator(color: Colors.amberAccent)),
                      );
                    }
                    final now = DateTime.now();
                    final docs = snapshot.data!.docs.where((d) {
                      final expiresAt = (d.get('expiresAt') as Timestamp?)?.toDate();
                      return expiresAt != null && expiresAt.isAfter(now);
                    }).toList();

                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text("Koi banned user nahi", style: TextStyle(color: Colors.white38)),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final expiresAt = (data['expiresAt'] as Timestamp).toDate();
                        final remaining = expiresAt.difference(now);
                        final hours = remaining.inHours;
                        final mins = remaining.inMinutes % 60;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: ListTile(
                            title: Text(data['name'] ?? "User", style: const TextStyle(color: Colors.white)),
                            subtitle: Text("${hours}h ${mins}m baaki", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                            trailing: TextButton(
                              onPressed: () => _unbanUser(docs[index].id),
                              child: const Text("Unban", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
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
        ),
      ),
    );
  }

  Future<void> _toggleAdmin(Map<String, dynamic> roomData, String targetUid) async {
    final admins = List<String>.from((roomData['admins'] as List?) ?? []);
    if (admins.contains(targetUid)) {
      admins.remove(targetUid);
    } else {
      if (admins.length >= maxAdmins) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Zyada se zyada $maxAdmins admins ban sakte hain")),
          );
        }
        return;
      }
      admins.add(targetUid);
    }
    await _roomDoc.update({'admins': admins});
  }

  /// Removes someone from their seat only (they go back to being audience,
  /// not kicked from the room and no ban applied) — used by "Stand Up".
  Future<void> _standUpUser(int seatIndex, String targetUid, String targetName, String targetAvatar) async {
    await _roomRef.doc(seatIndex.toString()).delete();
    await _roomDoc.collection('audience').doc(targetUid).set({
      'uid': targetUid,
      'name': targetName,
      'avatar': targetAvatar,
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _toggleChatBan(String targetUid, bool currentlyBanned) async {
    if (currentlyBanned) {
      await _roomDoc.collection('chatBanned').doc(targetUid).delete();
    } else {
      await _roomDoc.collection('chatBanned').doc(targetUid).set({'bannedAt': FieldValue.serverTimestamp()});
    }
  }

  // Same tier thresholds used for the Host Center level system — kept local
  // here to avoid a cross-file dependency. Update both places together if
  // these numbers change.
  static const List<int> _levelThresholds = [0, 5000, 15000, 40000, 100000, 250000, 600000];

  int _levelForCoins(int coins) {
    int level = 1;
    for (int i = _levelThresholds.length - 1; i >= 0; i--) {
      if (coins >= _levelThresholds[i]) {
        level = i + 1;
        break;
      }
    }
    return level;
  }

  Widget _miniBadge({required IconData icon, required Color iconColor, required String label, bool dim = false}) {
    return Opacity(
      opacity: dim ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [iconColor.withOpacity(0.16), Colors.white.withOpacity(0.03)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: iconColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 12),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _profileAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.35,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.22), color.withOpacity(0.06)],
                  ),
                  border: Border.all(color: color.withOpacity(0.35)),
                  boxShadow: enabled ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 8)] : [],
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openUserProfileSheet(int seatIndex, Map<String, dynamic> occupant, Map<String, dynamic> roomData) async {
    final targetUid = occupant['uid'] as String;
    final targetName = occupant['name'] as String? ?? "User";
    final targetAvatar = occupant['avatar'] as String? ?? "🧑";
    final isMuted = occupant['isMuted'] == true;
    final admins = (roomData['admins'] as List?) ?? [];
    final targetIsAdmin = admins.contains(targetUid);
    final iAmModerator = _isModerator(roomData);
    final iAmHost = _isHost(roomData);
    final isMe = targetUid == user?.uid;

    Map<String, dynamic> userData = {};
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(targetUid).get();
      userData = userDoc.data() ?? {};
    } catch (e) {
      debugPrint("Failed to load user profile for $targetUid: $e");
      // Fall back to whatever we already know from the seat data (name/avatar)
      // rather than blocking the sheet from opening at all.
    }

    // Only moderators ever see the chat-ban toggle, so only they need this
    // read — and if it's denied by security rules (or fails for any other
    // reason) it must never stop the profile sheet from opening.
    bool isChatBanned = false;
    if (iAmModerator) {
      try {
        final chatBanDoc = await _roomDoc.collection('chatBanned').doc(targetUid).get();
        isChatBanned = chatBanDoc.exists;
      } catch (e) {
        debugPrint("Failed to check chat-ban status for $targetUid: $e");
      }
    }

    final userID = userData['userID']?.toString() ?? "";
    final country = userData['country']?.toString() ?? "";
    final gender = userData['gender']?.toString() ?? "";
    final totalGifts = ((userData['totalGifts'] ?? 0) as num).toInt();
    final totalSent = ((userData['totalSent'] ?? 0) as num).toInt();
    final receivingLevel = _levelForCoins(totalGifts);
    final sendingLevel = _levelForCoins(totalSent);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF241E42), Color(0xFF17142B)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 16, spreadRadius: 1)],
              ),
              child: CircleAvatar(
                radius: 36,
                backgroundColor: Colors.white10,
                child: Text(targetAvatar, style: const TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              targetName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1))],
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (userID.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: userID));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("User ID copied"),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("ID: $userID", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            const SizedBox(width: 4),
                            const Icon(Icons.copy, color: Colors.white38, size: 12),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (country.isNotEmpty) ...[
                    Text(country, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    const SizedBox(width: 8),
                  ],
                  if (gender.isNotEmpty) ...[
                    _miniBadge(
                      icon: gender.toLowerCase() == "male" ? Icons.male : Icons.female,
                      iconColor: gender.toLowerCase() == "male" ? Colors.blueAccent : Colors.pinkAccent,
                      label: gender,
                    ),
                    const SizedBox(width: 6),
                  ],
                  _miniBadge(icon: Icons.trending_up, iconColor: Colors.orangeAccent, label: "S.Lv $sendingLevel"),
                  const SizedBox(width: 6),
                  _miniBadge(icon: Icons.favorite, iconColor: Colors.redAccent, label: "R.Lv $receivingLevel"),
                  const SizedBox(width: 6),
                  _miniBadge(icon: Icons.workspace_premium, iconColor: Colors.white38, label: "VIP --", dim: true),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.amberAccent.withOpacity(0.25), Colors.transparent],
                ),
              ),
            ),
            const SizedBox(height: 18),

            if (iAmModerator && !isMe) ...[
              Row(
                children: [
                  _profileAction(
                    icon: targetIsAdmin ? Icons.remove_moderator_outlined : Icons.add_moderator_outlined,
                    label: targetIsAdmin ? "Remove Admin" : "Admin",
                    color: Colors.greenAccent,
                    onTap: iAmHost
                        ? () {
                            Navigator.pop(context);
                            _toggleAdmin(roomData, targetUid);
                          }
                        : null,
                  ),
                  _profileAction(
                    icon: isMuted ? Icons.mic : Icons.mic_off,
                    label: isMuted ? "Unmute" : "Mute",
                    color: Colors.amberAccent,
                    onTap: () {
                      Navigator.pop(context);
                      _setSeatMute(seatIndex, !isMuted);
                    },
                  ),
                  _profileAction(
                    icon: isChatBanned ? Icons.chat_bubble_outline : Icons.comments_disabled_outlined,
                    label: "Ban Text",
                    color: isChatBanned ? Colors.greenAccent : Colors.orangeAccent,
                    onTap: () {
                      Navigator.pop(context);
                      _toggleChatBan(targetUid, isChatBanned);
                    },
                  ),
                  _profileAction(
                    icon: Icons.airline_seat_recline_normal,
                    label: "Stand Up",
                    color: Colors.blueAccent,
                    onTap: () {
                      Navigator.pop(context);
                      _standUpUser(seatIndex, targetUid, targetName, targetAvatar);
                    },
                  ),
                  _profileAction(
                    icon: Icons.logout,
                    label: "Kick Out",
                    color: Colors.redAccent,
                    onTap: () {
                      Navigator.pop(context);
                      _kickUser(targetUid, seatIndex, targetName);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            if (!isMe)
              Row(
                children: [
                  _profileAction(
                    icon: Icons.chat_bubble_outline,
                    label: "Chat",
                    color: Colors.lightBlueAccent,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            otherUserId: targetUid,
                            otherUserName: targetName,
                          ),
                        ),
                      );
                    },
                  ),
                  _profileAction(
                    icon: Icons.alternate_email,
                    label: "Reminder",
                    color: Colors.amberAccent,
                    onTap: () {
                      Navigator.pop(context);
                      _mentionUserInChat(targetName);
                    },
                  ),
                  _profileAction(
                    icon: Icons.card_giftcard,
                    label: "Send Gift",
                    color: Colors.pinkAccent,
                    onTap: () {
                      Navigator.pop(context);
                      showSendGiftSheet(context, targetUid, targetName);
                    },
                  ),
                ],
              ),
          ],
        ),
        ),
      ),
    );
  }

  void _onSeatTap(int index, Map<String, dynamic>? existingData, Map<String, dynamic> roomData) {
    final uid = user?.uid;
    final occupantUid = existingData?['uid'] as String?;

    // My own seat -> open Mute/Unmute + Stand Up popup.
    if (occupantUid != null && occupantUid == uid) {
      _openMySeatSheet(index, existingData!);
      return;
    }

    // Seat occupied by someone else -> open their profile popup.
    if (occupantUid != null && occupantUid != uid) {
      _openUserProfileSheet(index, existingData!, roomData);
      return;
    }

    // Empty seat -> existing join logic.
    _joinSeat(index, existingData);
  }

  Future<void> _openMySeatSheet(int seatIndex, Map<String, dynamic> myData) async {
    final isMuted = myData['isMuted'] == true;
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF241E42), Color(0xFF17142B)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, -4))],
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const Text(
                "Aapki Seat",
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _profileAction(
                    icon: isMuted ? Icons.mic : Icons.mic_off,
                    label: isMuted ? "Unmute" : "Mute",
                    color: Colors.amberAccent,
                    onTap: () {
                      Navigator.pop(context);
                      _toggleMySeatMute();
                    },
                  ),
                  _profileAction(
                    icon: Icons.airline_seat_recline_normal,
                    label: "Stand Up",
                    color: Colors.blueAccent,
                    onTap: () {
                      Navigator.pop(context);
                      _leaveSeat(seatIndex);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _joinSeat(int index, Map<String, dynamic>? existingData) async {
    final uid = user?.uid;
    if (uid == null || !_engineReady || _isSwitchingSeat) return;

    if (existingData != null && existingData['uid'] != null && existingData['uid'] != uid) {
      return;
    }
    if (existingData != null && existingData['uid'] == uid) {
      await _toggleMySeatMute();
      return;
    }

    _isSwitchingSeat = true;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};

      // Find every seat currently holding this user — normally just the one
      // in _mySeatIndex, but this also self-heals any stale duplicate left
      // behind by a dropped connection or a previous switch — and clear
      // them in the SAME atomic write as claiming the new seat, so this
      // user can never end up seated in two places at once.
      final myCurrentSeats = await _roomRef.where('uid', isEqualTo: uid).get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in myCurrentSeats.docs) {
        if (doc.id != index.toString()) {
          batch.delete(doc.reference);
        }
      }
      batch.set(_roomRef.doc(index.toString()), {
        'uid': uid,
        'name': userData['name'] ?? "User",
        'avatar': userData['avatar'] ?? "🧑",
        'isMuted': false,
      });
      await batch.commit();

      await _leaveAudience();
      setState(() => _mySeatIndex = index);
      await _becomeSpeaker();
    } finally {
      _isSwitchingSeat = false;
    }
  }

  Future<void> _leaveSeat(int index, {bool rejoinAudience = true}) async {
    await _roomRef.doc(index.toString()).delete();
    setState(() => _mySeatIndex = null);
    await _becomeAudience();
    if (rejoinAudience) await _joinAsAudience();
  }

  Future<void> _leaveRoom({bool kicked = false}) async {
    if (_mySeatIndex != null) {
      await _leaveSeat(_mySeatIndex!, rejoinAudience: false);
    }
    await _leaveAudience();
    await _engine.leaveChannel();
    await _deleteRoomIfEmpty();

    // best-effort cleanup of the kick signal that brought us here
    final uid = user?.uid;
    if (kicked && uid != null) {
      await _roomDoc.collection('kicked').doc(uid).delete().catchError((_) {});
    }

    if (mounted) Navigator.pop(context);
  }

  /// Called after anyone leaves — if the room now has nobody seated AND
  /// nobody in the audience, the room is considered ended and its
  /// document is removed (so it disappears from the party rooms list).
  Future<void> _deleteRoomIfEmpty() async {
    try {
      final seats = await _roomRef.limit(1).get();
      if (seats.docs.isNotEmpty) return;
      final audience = await _roomDoc.collection('audience').limit(1).get();
      if (audience.docs.isNotEmpty) return;

      await _roomDoc.delete();
    } catch (e) {
      debugPrint("Failed to check/delete empty room: $e");
    }
  }

  // ---------------- Chat ----------------

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final uid = user?.uid;
    if (text.isEmpty || uid == null) return;

    final banDoc = await _roomDoc.collection('chatBanned').doc(uid).get();
    if (banDoc.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Aap is room mein message nahi bhej sakte")),
        );
      }
      return;
    }

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

  /// "Chat" action from a user's profile popup — instead of a separate
  /// private chat, this just prefills the room chat box with an @mention
  /// of that user and focuses it so the current user can type right away.
  void _mentionUserInChat(String targetName) {
    final mention = "@$targetName ";
    // Avoid stacking duplicate mentions if tapped more than once.
    if (!_messageController.text.startsWith(mention)) {
      _messageController.text = mention + _messageController.text;
    }
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
    _messageFocusNode.requestFocus();
  }

  Future<void> _openRecipientPicker() async {
    final seatsSnap = await _roomRef.get();
    final myUid = user?.uid;
    final occupants = seatsSnap.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .where((data) => data['uid'] != null && data['uid'] != myUid)
        .toList();

    if (occupants.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Abhi koi seat par nahi hai gift bhejne ke liye")),
      );
      return;
    }

    if (!mounted) return;
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF241E42), Color(0xFF17142B)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.card_giftcard, color: Colors.pinkAccent, size: 18),
                  const SizedBox(width: 8),
                  const Text("Gift kisay bhejna hai?", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              ...occupants.map((data) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [Color(0xFFB983FF), Color(0xFF5B247A)]),
                        ),
                        child: CircleAvatar(
                          backgroundColor: Colors.white10,
                          child: Text(data['avatar'] ?? "🧑", style: const TextStyle(fontSize: 18)),
                        ),
                      ),
                      title: Text(data['name'] ?? "User", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
                      onTap: () => Navigator.pop(context, data),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );

    if (selected != null && mounted) {
      showSendGiftSheet(context, selected['uid'] as String?, selected['name'] as String?);
    }
  }

  @override
  void dispose() {
    _kickListener?.cancel();
    _leaveAudience();
    _engine.leaveChannel();
    _engine.release();
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  // ---------------- UI pieces ----------------

  Widget _seatWidget(int index, Map<String, dynamic>? data, Map<String, dynamic> roomData) {
    final isOccupied = data != null && data['uid'] != null;
    final isMe = isOccupied && data!['uid'] == user?.uid;
    final isMuted = data?['isMuted'] == true;

    return GestureDetector(
      onTap: () => _onSeatTap(index, data, roomData),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(2.4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isOccupied
                      ? LinearGradient(
                          colors: isMe
                              ? [const Color(0xFFFFE082), const Color(0xFFFFA000)]
                              : [const Color(0xFFB983FF), const Color(0xFF5B247A)],
                        )
                      : null,
                  border: isOccupied
                      ? null
                      : Border.all(color: Colors.white.withOpacity(0.14), width: 1.2),
                  boxShadow: isOccupied
                      ? [
                          BoxShadow(
                            color: (isMe ? Colors.amberAccent : const Color(0xFFB983FF)).withOpacity(0.45),
                            blurRadius: 14,
                            spreadRadius: 0.5,
                          ),
                        ]
                      : [],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOccupied ? const Color(0xFF15122A) : Colors.white.withOpacity(0.04),
                    gradient: isOccupied
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2A2350), Color(0xFF171331)],
                          )
                        : null,
                  ),
                  child: Center(
                    child: isOccupied
                        ? Text(data!['avatar'] ?? "🧑", style: const TextStyle(fontSize: 22))
                        : Icon(Icons.lock_outline, color: Colors.white.withOpacity(0.28), size: 18),
                  ),
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
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: (isMuted ? Colors.redAccent : Colors.greenAccent).withOpacity(0.4),
                          blurRadius: 5,
                        ),
                      ],
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
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFB8860B)]),
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.35), blurRadius: 4)],
                  ),
                  child: Text(
                    "${index + 2}",
                    style: const TextStyle(color: Colors.black87, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            isOccupied ? (data!['name'] ?? "User") : "Empty",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isOccupied ? Colors.white.withOpacity(0.85) : Colors.white24,
              fontSize: 10,
              fontWeight: isOccupied ? FontWeight.w600 : FontWeight.normal,
            ),
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 18, bottom: 6),
              child: Text(
                "AUDIENCE · ${docs.length}",
                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: Container(
                      padding: const EdgeInsets.all(1.6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.16)),
                      ),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white.withOpacity(0.06),
                        child: Text(data['avatar'] ?? "🧑", style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _chatSection() {
    return Container(
      height: 190,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withOpacity(0.0), Colors.white.withOpacity(0.035)],
        ),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF15122A).withOpacity(0.6), const Color(0xFF0D0B1E)],
        ),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
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
                    ? Colors.white.withOpacity(0.05)
                    : (_isMicOn ? Colors.greenAccent.withOpacity(0.16) : Colors.redAccent.withOpacity(0.16)),
                border: Border.all(
                  color: _mySeatIndex == null
                      ? Colors.white.withOpacity(0.1)
                      : (_isMicOn ? Colors.greenAccent.withOpacity(0.4) : Colors.redAccent.withOpacity(0.4)),
                ),
                boxShadow: _mySeatIndex == null
                    ? []
                    : [
                        BoxShadow(
                          color: (_isMicOn ? Colors.greenAccent : Colors.redAccent).withOpacity(0.25),
                          blurRadius: 10,
                        ),
                      ],
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
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white.withOpacity(0.07), Colors.white.withOpacity(0.03)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
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
          const SizedBox(width: 6),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFFFA000)]),
              boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.35), blurRadius: 10)],
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.black87, size: 18),
              onPressed: _sendMessage,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFFFF6FA5), Color(0xFFC2185B)]),
              boxShadow: [BoxShadow(color: Colors.pinkAccent.withOpacity(0.35), blurRadius: 10)],
            ),
            child: IconButton(
              icon: const Icon(Icons.card_giftcard, color: Colors.white, size: 18),
              onPressed: _openRecipientPicker,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E1836), Color(0xFF0D0B1E), Color(0xFF0A0815)],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<DocumentSnapshot>(
          stream: _roomDoc.snapshots(),
          builder: (context, roomSnap) {
            final roomData = roomSnap.data?.data() as Map<String, dynamic>? ?? {};

            return Column(
              children: [
                // ---------- Top bar ----------
                Container(
                  padding: const EdgeInsets.fromLTRB(6, 8, 12, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.0)],
                    ),
                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
                  ),
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1))],
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.only(right: 5),
                                  decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                                ),
                                Text(
                                  "ID: ${widget.roomId}",
                                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                                ),
                              ],
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
                      if (_isModerator(roomData))
                        IconButton(
                          icon: const Icon(Icons.block, color: Colors.white70, size: 20),
                          tooltip: "Banned Users",
                          onPressed: _openBannedUsersSheet,
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                        onPressed: _leaveRoom,
                      ),
                    ],
                  ),
                ),

                // ---------- Host + Seats (scrollable so it never overflows) ----------
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        StreamBuilder<QuerySnapshot>(
                          stream: _roomRef.snapshots(),
                          builder: (context, seatSnap) {
                            final Map<int, Map<String, dynamic>> seatMap = {};
                            if (seatSnap.hasData) {
                              for (final doc in seatSnap.data!.docs) {
                                seatMap[int.parse(doc.id)] = doc.data() as Map<String, dynamic>;
                              }
                            }

                            // If a moderator muted/unmuted me remotely, sync my
                            // actual mic state to match (not just the icon).
                            if (_mySeatIndex != null && seatMap.containsKey(_mySeatIndex)) {
                              final remoteMuted = seatMap[_mySeatIndex]!['isMuted'] == true;
                              if (remoteMuted == _isMicOn) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  _syncMicFromRemote(!remoteMuted);
                                });
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
                                  mainAxisSpacing: 18,
                                  childAspectRatio: 0.72,
                                ),
                                itemBuilder: (context, index) => _seatWidget(index, seatMap[index], roomData),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        _audienceStrip(),
                        const SizedBox(height: 8),
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
      ),
    );
  }
}