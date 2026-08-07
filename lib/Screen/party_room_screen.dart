import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:http/http.dart' as http;
import 'send_gift_sheet.dart';
import 'message_inbox_screen.dart';
import 'vip_utils.dart';

// TODO: Replace with your own Agora App ID from console.agora.io
const String agoraAppId = "508ffabe8f984a6f897794fbccc4cec9";

// Cloudinary — same unsigned upload account used across the app
// (see edit_profile_screen.dart for avatar/cover photo uploads).
const String cloudinaryCloudName = "bmdl7tkd";
const String cloudinaryUploadPreset = "euhkghkc";

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
  static const int totalSeats = 12; // default/fallback seat count
  static const int maxAdmins = 8;

  // Seat-count choices offered in the "Mic Mode" sheet.
  static const List<int> _micModeSeatOptions = [2, 5, 8, 9, 12, 15];

  // The room's actual seat count — host-controlled via Mic Mode, stored on
  // the room doc under 'totalSeats'. Falls back to the default above for
  // rooms that were created before this feature existed.
  int _seatCountFor(Map<String, dynamic> roomData) =>
      (roomData['totalSeats'] as num?)?.toInt() ?? totalSeats;

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

  // ---------------- Shared premium popup shell ----------------
  // Every dialog in this screen (not just the bottom sheets) uses this same
  // dark-purple gradient + soft border + shadow, so nothing ever renders as
  // a flat single-color box.
  Future<T?> _showPremiumDialog<T>({
    required String title,
    IconData? icon,
    Color iconColor = Colors.amberAccent,
    required Widget content,
    required List<Widget> actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF241E42), Color(0xFF17142B)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: iconColor, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              content,
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (int i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    actions[i],
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

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
            await _showPremiumDialog(
              title: "You're Banned",
              icon: Icons.block_rounded,
              iconColor: Colors.redAccent,
              content: Text(
                "You can rejoin this room in $hours h $mins min.",
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK", style: TextStyle(color: Colors.amberAccent)),
                ),
              ],
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
    _restoreHostDefaultsIfNeeded();
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
      const SnackBar(content: Text("You have been removed from this room")),
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
    final vipLevel = vipLevelForSpend(((userData['totalSent'] ?? 0) as num).toInt());

    await _roomDoc.collection('audience').doc(uid).set({
      'uid': uid,
      'name': userData['name'] ?? "User",
      'avatar': userData['avatar'] ?? "🧑",
      'avatarUrl': userData['avatarUrl'] ?? "",
      'joinedAt': FieldValue.serverTimestamp(),
      'vipLevel': vipLevel,
    });

    // VIP entrance effect — a glowing banner announcing their arrival,
    // shown in the room chat feed.
    if (vipLevel > 0) {
      await _roomDoc.collection('messages').add({
        'type': 'entrance',
        'senderUid': uid,
        'senderName': userData['name'] ?? "User",
        'senderVipLevel': vipLevel,
        'text': "${userData['name'] ?? 'User'} entered the room",
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
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

  // ---------------- Host's cover / announcement picture persistence ----------------
  // The room document (and its coverImage/announcementImage) gets deleted
  // once the room ends (see _deleteRoomIfEmpty), so without this the host
  // would have to re-upload their cover + announcement picture every single
  // time they start a new room. Instead, whenever the host sets one of these,
  // we also save a copy under a per-host profile doc that outlives the room.
  Future<void> _saveHostDefaultImage(String field, String url) async {
    final uid = user?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('host_profiles')
        .doc(uid)
        .set({field: url}, SetOptions(merge: true))
        .catchError((_) {});
  }

  // Called once when entering a room: if this user is the host and the room
  // doesn't already have a cover / announcement picture set (e.g. a fresh
  // room), restore the host's last-used ones from their profile so nothing
  // is lost just because a previous room ended. Never overwrites values the
  // host has already set for this room.
  Future<void> _restoreHostDefaultsIfNeeded() async {
    final uid = user?.uid;
    if (uid == null) return;
    try {
      final roomSnap = await _roomDoc.get();
      final roomData = roomSnap.data() as Map<String, dynamic>? ?? {};
      if (roomData['hostUid'] != uid) return;

      final needsCover = (roomData['coverImage'] as String?)?.isNotEmpty != true;
      final needsAnnouncementImage = (roomData['announcementImage'] as String?)?.isNotEmpty != true;
      if (!needsCover && !needsAnnouncementImage) return;

      final defaultsSnap = await FirebaseFirestore.instance.collection('host_profiles').doc(uid).get();
      final defaults = defaultsSnap.data() as Map<String, dynamic>? ?? {};

      final Map<String, dynamic> restore = {};
      if (needsCover && (defaults['coverImage'] as String?)?.isNotEmpty == true) {
        restore['coverImage'] = defaults['coverImage'];
      }
      if (needsAnnouncementImage && (defaults['announcementImage'] as String?)?.isNotEmpty == true) {
        restore['announcementImage'] = defaults['announcementImage'];
      }
      if (restore.isNotEmpty) {
        await _roomDoc.update(restore);
      }
    } catch (e) {
      debugPrint("Failed to restore host defaults: $e");
    }
  }

  // Picks an image from gallery, lets the user crop it, then uploads to
  // Cloudinary (same account/unsigned preset as edit_profile_screen.dart).
  // Returns the hosted image URL, or null if cancelled/failed.
  // isSquare: true -> 1:1 crop (Announcement picture), false -> 3:1 crop
  // (Room Cover, same banner shape as the profile cover photo).
  Future<String?> _pickAndUploadImage({required bool isSquare}) async {
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    } catch (e) {
      debugPrint("Image pick error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not open gallery: $e")));
      }
      return null;
    }
    if (picked == null || !mounted) return null; // user cancelled selection

    CroppedFile? cropped;
    try {
      cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressQuality: 85,
        aspectRatio: isSquare
            ? const CropAspectRatio(ratioX: 1, ratioY: 1)
            : const CropAspectRatio(ratioX: 3, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: isSquare ? "Adjust Picture" : "Adjust Room Cover",
            toolbarColor: const Color(0xFF1A1A2E),
            toolbarWidgetColor: Colors.white,
            backgroundColor: const Color(0xFF12121F),
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: isSquare ? "Adjust Picture" : "Adjust Room Cover",
            aspectRatioLockEnabled: true,
          ),
          WebUiSettings(context: context, presentStyle: WebPresentStyle.dialog),
        ],
      );
    } catch (e) {
      debugPrint("Image crop error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not open crop screen: $e")));
      }
      return null;
    }
    if (cropped == null || !mounted) return null; // user cancelled the crop

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.amberAccent)),
    );

    final url = await _uploadToCloudinary(cropped.path);
    if (mounted) Navigator.pop(context); // close loading dialog

    if (url == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Photo upload failed, please try again")),
      );
    }
    return url;
  }

  Future<String?> _uploadToCloudinary(String filePath) async {
    try {
      final url = Uri.parse("https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload");
      final bytes = await File(filePath).readAsBytes();
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = cloudinaryUploadPreset
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filePath.split('/').last));

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        return data['secure_url'] as String?;
      } else {
        debugPrint("Cloudinary upload failed: ${streamedResponse.statusCode} $responseBody");
        return null;
      }
    } catch (e) {
      debugPrint("Cloudinary upload error: $e");
      return null;
    }
  }

  Future<void> _setSeatMute(int seatIndex, bool muted) async {
    await _roomRef.doc(seatIndex.toString()).update({'isMuted': muted});
  }

  Future<void> _kickUser(String targetUid, int? seatIndex, String targetName) async {
    final myUid = user?.uid;
    if (seatIndex != null) await _roomRef.doc(seatIndex.toString()).delete();
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
                        child: Text("No banned users", style: TextStyle(color: Colors.white38)),
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
            SnackBar(content: Text("You can have a maximum of $maxAdmins admins")),
          );
        }
        return;
      }
      admins.add(targetUid);
    }
    await _roomDoc.update({'admins': admins});
  }

  // ---------------- Mic Mode sheet (seat layout, host-only) ----------------
  // Opened from the "Mic Mode" tile in the apps grid. Not full-screen — a
  // little over half the screen height — with a grid of seat-count choices.
  // Picking one saves it on the room doc (so everyone sees the same seat
  // layout) and vacates anyone currently sitting in a seat index that no
  // longer exists under the new count (they're moved back to audience).
  Future<void> _openMicModeSheet(Map<String, dynamic> roomData) async {
    if (!_isHost(roomData)) return;
    final int current = _seatCountFor(roomData);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.58,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF241E42), Color(0xFF17142B)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Row(
                children: const [
                  Icon(Icons.settings_voice_rounded, color: Colors.amberAccent, size: 18),
                  SizedBox(width: 8),
                  Text("Mic Mode", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Choose how many mic seats this room has",
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: GridView.builder(
                  itemCount: _micModeSeatOptions.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                  ),
                  itemBuilder: (context, i) {
                    final option = _micModeSeatOptions[i];
                    final bool selected = option == current;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          Navigator.pop(context);
                          if (option != current) {
                            await _changeSeatCount(option);
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: selected
                                ? const LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFFFA000)])
                                : const LinearGradient(colors: [Color(0xFF352C5C), Color(0xFF241E42)]),
                            border: Border.all(
                              color: selected ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.1),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_seat_rounded,
                                  size: 18, color: selected ? Colors.black87 : Colors.white70),
                              const SizedBox(height: 4),
                              Text(
                                "$option seats",
                                style: TextStyle(
                                  color: selected ? Colors.black87 : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  // Saves the new seat count on the room doc, then moves anyone seated at
  // an index >= newCount back to the audience (in one atomic batch) so no
  // one is left occupying a seat that no longer exists in the layout.
  Future<void> _changeSeatCount(int newCount) async {
    await _roomDoc.update({'totalSeats': newCount});

    final seatsSnap = await _roomRef.get();
    final batch = FirebaseFirestore.instance.batch();
    bool kickedMe = false;
    for (final doc in seatsSnap.docs) {
      final index = int.tryParse(doc.id) ?? -1;
      if (index >= newCount) {
        final data = doc.data() as Map<String, dynamic>;
        batch.delete(doc.reference);
        final uid = data['uid'] as String?;
        if (uid != null) {
          batch.set(_roomDoc.collection('audience').doc(uid), {
            'uid': uid,
            'name': data['name'] ?? "User",
            'avatar': data['avatar'] ?? "🧑",
            'avatarUrl': data['avatarUrl'] ?? "",
            'joinedAt': FieldValue.serverTimestamp(),
          });
          if (uid == user?.uid) kickedMe = true;
        }
      }
    }
    await batch.commit();

    if (kickedMe && mounted) {
      setState(() => _mySeatIndex = null);
      await _becomeAudience();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Mic Mode set to $newCount seats"), backgroundColor: const Color(0xFF241E42)),
      );
    }
  }

  // ---------------- Room Settings sheet (opened from the 4-dot menu) ----------------

  // Simple text-edit dialog reused for Room label and Announcement.
  Future<void> _editTextField({
    required String title,
    required String currentValue,
    required String firestoreField,
    int maxLines = 1,
    int? maxLength,
  }) async {
    final controller = TextEditingController(text: currentValue);
    final result = await _showPremiumDialog<String>(
      title: title,
      icon: Icons.edit_rounded,
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: maxLines,
        maxLength: maxLength,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.amberAccent)),
          counterStyle: const TextStyle(color: Colors.white38),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text("Save", style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
        ),
      ],
    );

    if (result != null && result.isNotEmpty && mounted) {
      await _roomDoc.update({firestoreField: result});
    }
  }

  // Admin management — lists everyone currently in the room (seated +
  // audience) with a switch to grant/revoke admin. Only the host can toggle.
  void _openAdminManagementSheet(Map<String, dynamic> roomData) {
    final bool iAmHost = _isHost(roomData);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF241E42), Color(0xFF17142B)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: _roomDoc.snapshots(),
                builder: (context, snap) {
                  final admins = (snap.data?.get('admins') as List?) ?? [];
                  return Row(
                    children: [
                      const Icon(Icons.admin_panel_settings_outlined, color: Colors.amberAccent, size: 18),
                      const SizedBox(width: 8),
                      Text("Admin  ${admins.length}/$maxAdmins",
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 4),
              if (!iAmHost)
                const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 8),
                  child: Text("Only the host can add or remove admins",
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ),
              const SizedBox(height: 8),
              Flexible(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _roomRef.snapshots(),
                  builder: (context, seatSnap) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: _roomDoc.collection('audience').snapshots(),
                      builder: (context, audienceSnap) {
                        if (!seatSnap.hasData || !audienceSnap.hasData) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator(color: Colors.amberAccent)),
                          );
                        }

                        // Merge seated + audience users, de-duplicated by uid.
                        final Map<String, Map<String, dynamic>> people = {};
                        for (final doc in seatSnap.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final uid = data['uid'] as String?;
                          if (uid != null) people[uid] = data;
                        }
                        for (final doc in audienceSnap.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final uid = data['uid'] as String?;
                          if (uid != null) people.putIfAbsent(uid, () => data);
                        }
                        final list = people.values.toList();

                        if (list.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text("No one is in the room yet", style: TextStyle(color: Colors.white38)),
                          );
                        }

                        return StreamBuilder<DocumentSnapshot>(
                          stream: _roomDoc.snapshots(),
                          builder: (context, roomSnap) {
                            final admins = (roomSnap.data?.get('admins') as List?) ?? [];
                            final hostUid = roomSnap.data?.get('hostUid') as String?;

                            return ListView.separated(
                              shrinkWrap: true,
                              itemCount: list.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final data = list[index];
                                final uid = data['uid'] as String;
                                final isThisHost = uid == hostUid;
                                final isAdmin = admins.contains(uid);

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                                  ),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: _avatarImage(data['avatarUrl'] as String?, data['avatar'] ?? "🧑", 36),
                                    title: Text(data['name'] ?? "User",
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                    subtitle: isThisHost
                                        ? const Text("Host", style: TextStyle(color: Colors.amberAccent, fontSize: 11))
                                        : null,
                                    trailing: isThisHost
                                        ? const Icon(Icons.verified, color: Colors.amberAccent, size: 18)
                                        : Switch(
                                            value: isAdmin,
                                            activeColor: Colors.amberAccent,
                                            onChanged: iAmHost ? (_) => _toggleAdmin({'admins': admins}, uid) : null,
                                          ),
                                  ),
                                );
                              },
                            );
                          },
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

  // Main Settings sheet — Room Cover, Room label, Announcement, Announcement
  // picture, Admin, and the "Send pictures in the room" toggle. Live-updates
  // via StreamBuilder so it always reflects the current room doc.
  void _openRoomSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF241E42), Color(0xFF17142B)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: StreamBuilder<DocumentSnapshot>(
            stream: _roomDoc.snapshots(),
            builder: (context, snap) {
              final roomData = snap.data?.data() as Map<String, dynamic>? ?? {};
              final bool iAmHost = _isHost(roomData);
              final admins = (roomData['admins'] as List?) ?? [];

              void hostOnlyGuard(VoidCallback action) {
                if (iAmHost) {
                  action();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Only the host can change settings")),
                  );
                }
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const Center(
                      child: Text("Settings",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 18),

                    // Room Cover
                    _settingsRow(
                      label: "Room Cover",
                      onTap: () => hostOnlyGuard(() async {
                        final url = await _pickAndUploadImage(isSquare: false);
                        if (url != null && mounted) {
                          await _roomDoc.update({'coverImage': url});
                          await _saveHostDefaultImage('coverImage', url);
                        }
                      }),
                      trailing: Container(
                        width: 40,
                        height: 40,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white.withOpacity(0.06),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: (roomData['coverImage'] as String?)?.isNotEmpty == true
                            ? Image.network(roomData['coverImage'], fit: BoxFit.cover)
                            : const Icon(Icons.image_outlined, color: Colors.white38, size: 18),
                      ),
                    ),

                    // Room label
                    _settingsRow(
                      label: "Room label",
                      onTap: () => hostOnlyGuard(() => _editTextField(
                            title: "Room label",
                            currentValue: roomData['title'] ?? "",
                            firestoreField: 'title',
                            maxLength: 40,
                          )),
                      trailingText: (roomData['title'] as String?)?.isNotEmpty == true ? roomData['title'] : "Not set",
                    ),

                    // Announcement
                    _settingsRow(
                      label: "Announcement",
                      onTap: () => hostOnlyGuard(() => _editTextField(
                            title: "Announcement",
                            currentValue: roomData['announcement'] ?? "",
                            firestoreField: 'announcement',
                            maxLines: 4,
                            maxLength: 200,
                          )),
                      trailingText:
                          (roomData['announcement'] as String?)?.isNotEmpty == true ? roomData['announcement'] : "Not set",
                    ),

                    // Announcement picture
                    _settingsRow(
                      label: "Announcement picture",
                      onTap: () => hostOnlyGuard(() async {
                        final url = await _pickAndUploadImage(isSquare: true);
                        if (url != null && mounted) {
                          await _roomDoc.update({'announcementImage': url});
                          await _saveHostDefaultImage('announcementImage', url);
                        }
                      }),
                      trailing: Container(
                        width: 40,
                        height: 40,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white.withOpacity(0.06),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: (roomData['announcementImage'] as String?)?.isNotEmpty == true
                            ? Image.network(roomData['announcementImage'], fit: BoxFit.cover)
                            : const Icon(Icons.image_outlined, color: Colors.white38, size: 18),
                      ),
                    ),

                    // Admin
                    _settingsRow(
                      label: "Admin",
                      onTap: () => _openAdminManagementSheet(roomData),
                      trailingText: "${admins.length}/$maxAdmins",
                    ),

                    // Send pictures in the room
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text("Send pictures in the room", style: TextStyle(color: Colors.white, fontSize: 13.5)),
                          ),
                          Switch(
                            value: roomData['allowPictures'] != false, // default true
                            activeColor: Colors.amberAccent,
                            onChanged: (val) => hostOnlyGuard(() => _roomDoc.update({'allowPictures': val})),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // One tappable row in the Settings sheet: label on the left, either a
  // short text preview or a custom trailing widget (thumbnail) on the
  // right, followed by a chevron — matches the reference design.
  Widget _settingsRow({
    required String label,
    required VoidCallback onTap,
    String? trailingText,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
            ),
            if (trailingText != null)
              Flexible(
                child: Text(
                  trailingText,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12.5),
                ),
              ),
            if (trailing != null) trailing,
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }

  /// Removes someone from their seat only (they go back to being audience,
  /// not kicked from the room and no ban applied) — used by "Stand Up".
  Future<void> _standUpUser(int seatIndex, String targetUid, String targetName, String targetAvatar, String targetAvatarUrl) async {
    await _roomRef.doc(seatIndex.toString()).delete();
    await _roomDoc.collection('audience').doc(targetUid).set({
      'uid': targetUid,
      'name': targetName,
      'avatar': targetAvatar,
      'avatarUrl': targetAvatarUrl,
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

  /// Shared avatar renderer for seats, the audience/lobby strip, and the
  /// profile popup — shows the user's real Cloudinary photo when
  /// [avatarUrl] is set, otherwise falls back to the chosen emoji.
  Widget _avatarImage(String? avatarUrl, String emoji, double size) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: size,
              height: size,
              child: Center(
                child: SizedBox(
                  width: size * 0.35,
                  height: size * 0.35,
                  child: const CircularProgressIndicator(strokeWidth: 1.6, color: Colors.amberAccent),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) =>
              Center(child: Text(emoji, style: TextStyle(fontSize: size * 0.5))),
        ),
      );
    }
    return Center(child: Text(emoji, style: TextStyle(fontSize: size * 0.5)));
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

  Future<void> _openUserProfileSheet(int? seatIndex, Map<String, dynamic> occupant, Map<String, dynamic> roomData) async {
    final targetUid = occupant['uid'] as String;
    final targetName = occupant['name'] as String? ?? "User";
    final targetAvatar = occupant['avatar'] as String? ?? "🧑";
    final targetAvatarUrl = occupant['avatarUrl'] as String? ?? "";
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
    final vipLevel = vipLevelForSpend(totalSent);

    if (!mounted) return;

    bool idCopied = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
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
            VipAvatarFrame(
              level: vipLevel,
              borderWidth: 3,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                  boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 16, spreadRadius: 1)],
                ),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white10,
                  child: _avatarImage(targetAvatarUrl, targetAvatar, 66),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  targetName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1))],
                  ),
                ),
                if (vipLevel > 0) ...[
                  const SizedBox(width: 6),
                  VipBadge(level: vipLevel, fontSize: 11),
                ],
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (userID.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: userID));
                        setSheetState(() => idCopied = true);
                        Future.delayed(const Duration(seconds: 2), () {
                          try {
                            setSheetState(() => idCopied = false);
                          } catch (_) {
                            // Sheet already closed — nothing to update.
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: idCopied ? Colors.greenAccent.withOpacity(0.15) : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: idCopied ? Border.all(color: Colors.greenAccent.withOpacity(0.4)) : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              idCopied ? "Copied!" : "ID: $userID",
                              style: TextStyle(
                                color: idCopied ? Colors.greenAccent : Colors.white54,
                                fontSize: 11,
                                fontWeight: idCopied ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              idCopied ? Icons.check : Icons.copy_rounded,
                              size: 12,
                              color: idCopied ? Colors.greenAccent : Colors.white38,
                            ),
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
                  if (seatIndex != null)
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
                  if (seatIndex != null)
                    _profileAction(
                      icon: Icons.airline_seat_recline_normal,
                      label: "Stand Up",
                      color: Colors.blueAccent,
                      onTap: () {
                        Navigator.pop(context);
                        _standUpUser(seatIndex, targetUid, targetName, targetAvatar, targetAvatarUrl);
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
                      _mentionUserInChat(targetName);
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
                      showSendGiftSheet(context, targetUid, targetName, widget.roomId);
                    },
                  ),
                ],
              ),
          ],
        ),
        ),
      ),
      ),
    );
  }

  void _onSeatTap(int index, Map<String, dynamic>? existingData, Map<String, dynamic> roomData) {
    // Any seat interaction should close the keyboard if it was open —
    // it should only be open while the user is actually typing a comment.
    FocusScope.of(context).unfocus();

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
                "My Seat",
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
        'avatarUrl': userData['avatarUrl'] ?? "",
        'isMuted': false,
        'vipLevel': vipLevelForSpend(((userData['totalSent'] ?? 0) as num).toInt()),
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

  // "Clean Text" from the apps grid (host/admin only) — wipes every
  // message in the room's chat immediately on tap, including gift lines
  // (they live in the same 'messages' collection with type: 'gift'), not
  // just the ~50 currently visible on screen.
  Future<void> _onCleanTextTap(Map<String, dynamic> roomData) async {
    if (!_isModerator(roomData)) return;
    await _clearChatMessages();
  }

  Future<void> _clearChatMessages() async {
    final messagesRef = _roomDoc.collection('messages');

    try {
      // Delete in batches of 400 (Firestore's batch limit is 500) and keep
      // going until the collection is empty — a room can easily have more
      // messages than fit in a single batch or the chat's on-screen limit(50).
      while (true) {
        final snap = await messagesRef.limit(400).get(const GetOptions(source: Source.server));
        if (snap.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snap.docs.length < 400) break;
      }
    } on FirebaseException catch (e) {
      // If Firestore rules don't let this account delete other people's
      // messages, the batch gets rejected server-side and the SDK rolls
      // the optimistic local delete back — which looks like "it clears,
      // then the comment shows up again". Surface that clearly instead of
      // failing silently.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.code == 'permission-denied'
                  ? "Couldn't clear chat — Firestore rules aren't allowing this account to delete messages"
                  : "Couldn't clear chat: ${e.message}",
            ),
            backgroundColor: const Color(0xFF241E42),
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final uid = user?.uid;
    if (text.isEmpty || uid == null) return;

    final banDoc = await _roomDoc.collection('chatBanned').doc(uid).get();
    if (banDoc.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You can't send messages in this room")),
        );
      }
      return;
    }

    _messageController.clear();
    _messageFocusNode.unfocus();

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final name = userDoc.data()?['name'] ?? "User";
    final vipLevel = vipLevelForSpend(((userDoc.data()?['totalSent'] ?? 0) as num).toInt());

    await _roomDoc.collection('messages').add({
      'text': text,
      'senderUid': uid,
      'senderName': name,
      'senderVipLevel': vipLevel,
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

  Future<void> _openRecipientPicker(Map<String, dynamic> roomData) async {
    final seatsSnap = await _roomRef.get();
    final myUid = user?.uid;
    final hostUid = roomData['hostUid'] as String?;

    final occupants = seatsSnap.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .where((data) => data['uid'] != null && data['uid'] != myUid)
        .toList();

    // Make sure the host shows up in the recipient list even if they
    // aren't currently seated (e.g. standing in the audience) — fetch
    // their name from Firestore since a seat doc won't exist for them.
    final hostAlreadySeated = occupants.any((data) => data['uid'] == hostUid);
    if (hostUid != null && hostUid != myUid && !hostAlreadySeated) {
      String? hostName;
      String? hostAvatar;
      try {
        final hostDoc = await FirebaseFirestore.instance.collection('users').doc(hostUid).get();
        hostName = hostDoc.data()?['name'] as String?;
        hostAvatar = hostDoc.data()?['avatar'] as String?;
      } catch (_) {
        // Best-effort — falls back to defaults below if this fails.
      }
      occupants.insert(0, {'uid': hostUid, 'name': hostName ?? 'Host', 'avatar': hostAvatar ?? '🧑'});
    }

    if (!mounted) return;

    Map<String, dynamic>? defaultRecipient;
    if (occupants.isNotEmpty) {
      defaultRecipient = occupants.firstWhere(
        (data) => data['uid'] == hostUid,
        orElse: () => occupants.first,
      );
    }

    // Always open the gift box — even with no one to send to, it can
    // still be browsed. When someone (host and/or seated users) is
    // present, the sheet itself shows a recipient row (with an "All"
    // option) along its top; if it's empty, "no one to receive" is only
    // shown once the sender actually tries to hit Send.
    showSendGiftSheet(
      context,
      defaultRecipient?['uid'] as String?,
      defaultRecipient?['name'] as String?,
      widget.roomId,
      occupants,
      hostUid,
    );
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

  // Small translucent circular icon button used in the top bar.
  Widget _circleIconButton(IconData icon, VoidCallback onPressed, {String? tooltip}) {
    final button = GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        onPressed();
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Icon(icon, color: Colors.white70, size: 16),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: button) : button;
  }

  // Plain locked/occupied seat circle — matches the reference design:
  // a soft dark ring with a centered lock glyph when empty, and the seat
  // number underneath (or the occupant's name when someone is seated).
  // Lays out the remaining seats (everything after host + seat 1) in
  // balanced, centered rows instead of a plain 5-per-row grid — a plain
  // grid leaves an odd, left-hugging leftover row for counts like 7 or 13
  // (e.g. 5 + 2). Instead this spreads each seat count as evenly as
  // possible across rows of at most 5, so e.g. 9 seats (7 remaining)
  // renders as 4 + 3, and 15 seats (13 remaining) renders as 5 + 4 + 4 —
  // every row centered and no sparse trailing row.
  Widget _balancedSeatRows({
    required int remaining,
    required int startIndex,
    required double availableWidth,
    required Map<int, Map<String, dynamic>> seatMap,
    required Map<String, dynamic> roomData,
  }) {
    if (remaining <= 0) return const SizedBox.shrink();

    const int maxCols = 5;
    const double spacing = 4;
    final int rowCount = (remaining / maxCols).ceil();
    final int base = remaining ~/ rowCount;
    final int extra = remaining % rowCount;
    final double itemWidth = (availableWidth - spacing * (maxCols - 1)) / maxCols;

    final List<Widget> rows = [];
    int seatIndex = startIndex;
    for (int r = 0; r < rowCount; r++) {
      final int countInRow = base + (r < extra ? 1 : 0);
      final List<Widget> rowChildren = [];
      for (int c = 0; c < countInRow; c++) {
        if (c > 0) rowChildren.add(const SizedBox(width: spacing));
        rowChildren.add(SizedBox(
          width: itemWidth,
          child: _seatWidget(seatIndex, seatMap[seatIndex], roomData),
        ));
        seatIndex++;
      }
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: r != rowCount - 1 ? 8 : 0),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: rowChildren),
      ));
    }
    return Column(children: rows);
  }

  Widget _seatWidget(int index, Map<String, dynamic>? data, Map<String, dynamic> roomData) {
    final isOccupied = data != null && data['uid'] != null;
    final isMe = isOccupied && data!['uid'] == user?.uid;
    final isMuted = data?['isMuted'] == true;
    final vipLevel = isOccupied ? (((data!['vipLevel'] ?? 0) as num).toInt()) : 0;

    return GestureDetector(
      onTap: () => _onSeatTap(index, data, roomData),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              VipAvatarFrame(
                level: vipLevel,
                child: Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isOccupied
                      ? LinearGradient(
                          colors: isMe
                              ? [const Color(0xFFFFE082), const Color(0xFFFFA000)]
                              : [const Color(0xFFB983FF), const Color(0xFF5B247A)],
                        )
                      : null,
                  border: Border.all(
                    color: Colors.white.withOpacity(isOccupied ? 0.0 : 0.16),
                    width: 1.3,
                  ),
                  boxShadow: isOccupied
                      ? [
                          BoxShadow(
                            color: (isMe ? Colors.amberAccent : const Color(0xFFB983FF)).withOpacity(0.4),
                            blurRadius: 10,
                            spreadRadius: 0.4,
                          ),
                        ]
                      : [],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOccupied ? const Color(0xFF15122A) : Colors.white.withOpacity(0.03),
                    gradient: isOccupied
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2A2350), Color(0xFF171331)],
                          )
                        : null,
                  ),
                  child: isOccupied
                      ? _avatarImage(data!['avatarUrl'] as String?, data['avatar'] ?? "🧑", 43)
                      : Center(child: Icon(Icons.lock_outline, color: Colors.white.withOpacity(0.4), size: 19)),
                ),
                ),
              ),
              if (isOccupied)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0B1E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: (isMuted ? Colors.redAccent : Colors.greenAccent).withOpacity(0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      isMuted ? Icons.mic_off : Icons.mic,
                      color: isMuted ? Colors.redAccent : Colors.greenAccent,
                      size: 8,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            isOccupied ? (data!['name'] ?? "User") : "${index + 1}",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isOccupied ? Colors.white.withOpacity(0.85) : Colors.white38,
              fontSize: 9,
              fontWeight: isOccupied ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (vipLevel > 0) ...[
            const SizedBox(height: 1),
            VipBadge(level: vipLevel, fontSize: 8),
          ],
        ],
      ),
    );
  }

  // The host slot (seat index 0) — rendered bigger with a gold laurel
  // crest around it, same tap/seat logic as every other seat.
  Widget _hostSeatWidget(Map<String, dynamic>? data, Map<String, dynamic> roomData) {
    final isOccupied = data != null && data['uid'] != null;
    final vipLevel = isOccupied ? (((data!['vipLevel'] ?? 0) as num).toInt()) : 0;

    return GestureDetector(
      onTap: () => _onSeatTap(0, data, roomData),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 78,
            height: 70,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: -2,
                  child: Transform.rotate(
                    angle: -0.25,
                    child: ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        colors: [Color(0xFFFFF0B8), Color(0xFFB8860B)],
                      ).createShader(b),
                      child: const Icon(Icons.eco, size: 31, color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  right: -2,
                  child: Transform.flip(
                    flipX: true,
                    child: Transform.rotate(
                      angle: -0.25,
                      child: ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [Color(0xFFFFF0B8), Color(0xFFB8860B)],
                        ).createShader(b),
                        child: const Icon(Icons.eco, size: 31, color: Colors.white),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 58,
                  height: 58,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [Color(0xFFFFEBAE), Color(0xFFC0912E)]),
                    boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.45), blurRadius: 10, spreadRadius: 1)],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF15122A)),
                    child: isOccupied
                        ? _avatarImage(data!['avatarUrl'] as String?, data['avatar'] ?? "🧑", 49)
                        : Center(child: Icon(Icons.lock_outline, color: Colors.white.withOpacity(0.4), size: 21)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFC24BFF), Color(0xFF7B2FF7)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, size: 10, color: Colors.white),
                const SizedBox(width: 3),
                const Text("1", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Text(
                  isOccupied ? (data!['name'] ?? "User") : "Host",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                ),
                if (vipLevel > 0) ...[
                  const SizedBox(width: 4),
                  VipBadge(level: vipLevel, fontSize: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _audienceStrip(Map<String, dynamic> roomData) {
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
                    child: GestureDetector(
                      onTap: () => _openUserProfileSheet(null, data, roomData),
                      child: Container(
                        padding: const EdgeInsets.all(1.6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.16)),
                        ),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white.withOpacity(0.06),
                          child: _avatarImage(data['avatarUrl'] as String?, data['avatar'] ?? "🧑", 30),
                        ),
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
      height: 260,
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
                    final isGift = data['type'] == 'gift';
                    final isEntrance = data['type'] == 'entrance';

                    if (isEntrance) {
                      final entranceLevel = ((data['senderVipLevel'] ?? 0) as num).toInt();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: vipGradient(entranceLevel).map((c) => c.withOpacity(0.22)).toList(),
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: vipColor(entranceLevel).withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              VipBadge(level: entranceLevel, fontSize: 10),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  data['text'] ?? "",
                                  style: TextStyle(
                                    color: vipColor(entranceLevel),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (isGift) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.pinkAccent.withOpacity(0.18), Colors.amberAccent.withOpacity(0.08)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.pinkAccent.withOpacity(0.25)),
                          ),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: "${data['giftEmoji'] ?? '🎁'} ",
                                  style: const TextStyle(fontSize: 13),
                                ),
                                TextSpan(
                                  text: "${data['senderName'] ?? 'User'} ",
                                  style: const TextStyle(
                                      color: Colors.amberAccent, fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                                const TextSpan(
                                  text: "sent ",
                                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                                ),
                                TextSpan(
                                  text: "${data['receiverName'] ?? 'User'} ",
                                  style: const TextStyle(
                                      color: Colors.amberAccent, fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: "a ${data['giftName'] ?? 'gift'}",
                                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final senderVipLevel = ((data['senderVipLevel'] ?? 0) as num).toInt();
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
                            if (senderVipLevel > 0)
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: VipBadge(level: senderVipLevel, fontSize: 9),
                                ),
                              ),
                            TextSpan(
                              text: "${data['senderName'] ?? 'User'}: ",
                              style: TextStyle(
                                color: senderVipLevel > 0 ? vipColor(senderVipLevel) : Colors.amberAccent,
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

  // Emoji picker — tap an emoji to drop it into the comment box (no
  // keyboard involved). Sheet has its own Send button so a quick
  // emoji-only message can go out without ever opening the keyboard.
  static const List<String> _quickEmojis = [
    "😀", "😂", "😍", "😘", "😎", "🤩", "🥳", "😢",
    "😡", "😱", "🤔", "👍", "👎", "👏", "🙏", "💪",
    "❤️", "🔥", "🎉", "🎁", "🌹", "⭐", "✨", "💯",
    "😅", "😉", "😜", "🤗", "😴", "🥰", "😭", "👋",
  ];

  Future<void> _openEmojiPicker() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF241E42), Color(0xFF17142B)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _quickEmojis.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemBuilder: (context, i) {
                      return GestureDetector(
                        onTap: () {
                          _messageController.text += _quickEmojis[i];
                          _messageController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _messageController.text.length),
                          );
                          setSheetState(() {});
                        },
                        child: Center(
                          child: Text(_quickEmojis[i], style: const TextStyle(fontSize: 24)),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) {
                              _sendMessage();
                              Navigator.pop(context);
                            },
                            onChanged: (_) => setSheetState(() {}),
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
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          _sendMessage();
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFFFA000)]),
                            boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.35), blurRadius: 10)],
                          ),
                          child: const Icon(Icons.send, color: Colors.black87, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- Apps grid menu (4-dot icon, top-right of bottom bar) ----------
  // Full feature grid matching the reference design: Interactive Features,
  // Management Tool, and Other Tool sections. Each item currently opens the
  // existing placeholder sheet below — real functionality for each feature
  // can be wired in one at a time later without touching this layout.
  //
  // Visibility is role-based:
  //  - Host (room owner): everything — every item in all three sections.
  //  - Admin (host-assigned moderator, in roomData['admins']): Interactive
  //    Features full row, Management Tool -> Clean Text / Music / Voice
  //    Effect only, Other Tool -> Visual Effect / Sound On / Report.
  //  - Regular user (in the room, not host/admin): Interactive Features
  //    full row, Management Tool -> Visual Effect / Sound On only,
  //    Other Tool -> Report only.
  Future<void> _openAppsMenuSheet(Map<String, dynamic> roomData) async {
    final bool iAmHost = _isHost(roomData);
    final admins = (roomData['admins'] as List?) ?? [];
    final bool iAmAdmin = !iAmHost && admins.contains(user?.uid);

    final List<_AppsMenuItem> managementItems;
    final List<_AppsMenuItem> otherItems;

    if (iAmHost) {
      managementItems = [
        _AppsMenuItem("Clean Text", Icons.cleaning_services_rounded, onTap: () => _onCleanTextTap(roomData)),
        _AppsMenuItem("Setting", Icons.tune_rounded, onTap: _openRoomSettingsSheet),
        _AppsMenuItem("Music", Icons.library_music_rounded),
        _AppsMenuItem("Voice Effect", Icons.graphic_eq_rounded),
        _AppsMenuItem("Lock Room", Icons.lock_rounded),
        _AppsMenuItem("Mic Mode", Icons.settings_voice_rounded,
            onTap: () => _openMicModeSheet(roomData)),
        _AppsMenuItem("Background", Icons.wallpaper_rounded),
        _AppsMenuItem("Kick Record", Icons.history_toggle_off_rounded),
      ];
      otherItems = [
        _AppsMenuItem("Visual Effect", Icons.auto_awesome_rounded),
        _AppsMenuItem("Sound On", Icons.volume_up_rounded),
      ];
    } else if (iAmAdmin) {
      managementItems = [
        _AppsMenuItem("Clean Text", Icons.cleaning_services_rounded, onTap: () => _onCleanTextTap(roomData)),
        _AppsMenuItem("Music", Icons.library_music_rounded),
        _AppsMenuItem("Voice Effect", Icons.graphic_eq_rounded),
      ];
      otherItems = [
        _AppsMenuItem("Visual Effect", Icons.auto_awesome_rounded),
        _AppsMenuItem("Sound On", Icons.volume_up_rounded),
        _AppsMenuItem("Report", Icons.flag_rounded),
      ];
    } else {
      managementItems = [
        _AppsMenuItem("Visual Effect", Icons.auto_awesome_rounded),
        _AppsMenuItem("Sound On", Icons.volume_up_rounded),
      ];
      otherItems = [
        _AppsMenuItem("Report", Icons.flag_rounded),
      ];
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF241E42), Color(0xFF17142B)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                _menuSectionTitle("Interactive Features"),
                const SizedBox(height: 16),
                _menuGrid([
                  _AppsMenuItem("Costume", Icons.theater_comedy_rounded,
                      gradient: const [Color(0xFFFFD166), Color(0xFFFF7B39), Color(0xFFE8590C)]),
                  _AppsMenuItem("Team PK", Icons.bolt_rounded,
                      gradient: const [Color(0xFF5AC8FA), Color(0xFF6C5CE7), Color(0xFFE8447A)]),
                  _AppsMenuItem("Seats", Icons.weekend_rounded,
                      gradient: const [Color(0xFFB388FF), Color(0xFF7C4DFF), Color(0xFF536DFE)]),
                  _AppsMenuItem("Red Envelope", Icons.card_giftcard_rounded,
                      gradient: const [Color(0xFFFF8A65), Color(0xFFE64A19), Color(0xFFB71C1C)]),
                ]),
                const SizedBox(height: 26),
                _menuSectionTitle("Management Tool"),
                const SizedBox(height: 16),
                _menuGrid(managementItems),
                const SizedBox(height: 26),
                _menuSectionTitle("Other Tool"),
                const SizedBox(height: 16),
                _menuGrid(otherItems),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Small gold accent bar + uppercase tracked label — premium section header.
  Widget _menuSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 12,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFFFA000)]),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.68),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  // Rows of up to 4 tiles, each tile sized by Expanded so the row always
  // fits the available width exactly (no wrap-overflow, no oversized icons).
  Widget _menuGrid(List<_AppsMenuItem> items) {
    const int perRow = 4;
    final List<Widget> rows = [];
    for (int i = 0; i < items.length; i += perRow) {
      final rowItems = items.sublist(i, (i + perRow).clamp(0, items.length));
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + perRow < items.length ? 16 : 0),
          child: Row(
            children: [
              for (final item in rowItems) Expanded(child: _menuTile(item)),
              // Pad out a short final row so tiles stay left-aligned and
              // the same size as full rows, instead of stretching wider.
              for (int j = rowItems.length; j < perRow; j++) const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _menuTile(_AppsMenuItem item) {
    final bool tinted = item.gradient != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          if (item.onTap != null) {
            item.onTap!();
          } else {
            _openPlaceholderSheet(item.label, item.icon);
          }
        },
        borderRadius: BorderRadius.circular(14),
        splashColor: (tinted ? item.gradient!.first : const Color(0xFFFFC107)).withOpacity(0.18),
        highlightColor: Colors.white.withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: tinted
                      ? LinearGradient(
                          colors: item.gradient!,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF352C5C), Color(0xFF241E42)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  border: Border.all(
                    color: tinted ? Colors.white.withOpacity(0.28) : Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (tinted ? item.gradient!.first : Colors.black).withOpacity(tinted ? 0.28 : 0.18),
                      blurRadius: tinted ? 8 : 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  item.icon,
                  color: tinted ? Colors.white : const Color(0xFFFFD54F),
                  size: 15,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Placeholder opener for the remaining bottom-bar icons (mail, games,
  // apps grid). These just open an empty sheet for now — the real
  // functionality for each will be wired up later.
  Future<void> _openPlaceholderSheet(String title, IconData icon) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF241E42), Color(0xFF17142B)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.06)),
                child: Icon(icon, color: Colors.white70, size: 26),
              ),
              const SizedBox(height: 14),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                "This feature is coming soon",
                style: TextStyle(color: Colors.white38, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(Map<String, dynamic> roomData) {
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
          // Rounded chat pill (icon + input + send), matching the reference look.
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Icon(Icons.chat_bubble_outline, color: Colors.white.withOpacity(0.35), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
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
                  GestureDetector(
                    onTap: _sendMessage,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.send, color: Colors.amberAccent, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Emoji — opens a quick emoji picker; tap an emoji to drop it
          // into the comment box, or send straight from the sheet.
          GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              _openEmojiPicker();
            },
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.emoji_emotions_outlined, color: Colors.white70, size: 22),
            ),
          ),

          // Mic toggle — real logic, same as before, just restyled to match
          // the plain-icon look (no circle background) used in the reference.
          GestureDetector(
            onTap: _mySeatIndex != null
                ? () {
                    FocusScope.of(context).unfocus();
                    _toggleMySeatMute();
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                _mySeatIndex == null ? Icons.mic_off : (_isMicOn ? Icons.mic : Icons.mic_off),
                size: 22,
                color: _mySeatIndex == null
                    ? Colors.white24
                    : (_isMicOn ? Colors.greenAccent : Colors.redAccent),
              ),
            ),
          ),

          // Mail / inbox — opens as a half-screen sheet over the lower
          // part of the room (below the seats), not a full-screen push.
          GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => FractionallySizedBox(
                  heightFactor: 0.55,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: const MessageInboxScreen(),
                  ),
                ),
              );
            },
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.mail_outline, color: Colors.white70, size: 21),
            ),
          ),

          const SizedBox(width: 8),

          // Mini-games — placeholder for now.
          GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              _openPlaceholderSheet("Mini Games", Icons.sports_esports_outlined);
            },
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.sports_esports_outlined, color: Colors.white70, size: 22),
            ),
          ),
          const SizedBox(width: 4),

          // Gift — real logic, same as before.
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(colors: [Color(0xFFFFD54F), Color(0xFFFF9800)]),
              boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.35), blurRadius: 10)],
            ),
            child: IconButton(
              icon: const Icon(Icons.card_giftcard, color: Colors.black87, size: 18),
              onPressed: () {
                FocusScope.of(context).unfocus();
                _openRecipientPicker(roomData);
              },
            ),
          ),
          const SizedBox(width: 6),

          // Apps grid (4-dot) — top-right corner icon; opens the full
          // feature menu (Interactive Features / Management Tool / Other Tool).
          GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              _openAppsMenuSheet(roomData);
            },
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white.withOpacity(0.06),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(Icons.apps, color: Colors.white70, size: 18),
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
                  padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
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
                      GestureDetector(
                        onTap: _leaveRoom,
                        child: Container(
                          width: 40,
                          height: 40,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.06),
                            border: Border.all(color: Colors.white.withOpacity(0.14)),
                          ),
                          child: (roomData['coverImage'] as String?)?.isNotEmpty == true
                              ? Image.network(
                                  roomData['coverImage'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                                )
                              : const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                        ),
                      ),
                      const SizedBox(width: 10),
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
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.only(right: 5),
                                    decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                                  ),
                                  Text(
                                    "ID: ${widget.roomId}",
                                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                                  ),
                                ],
                              ),
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
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: _circleIconButton(Icons.block, _openBannedUsersSheet, tooltip: "Banned Users"),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: _circleIconButton(Icons.close, _leaveRoom),
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
                              child: Column(
                                children: [
                                  // Seat 0 = host slot (gold crest), seat 1 sits
                                  // beside it — same as the reference layout.
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _hostSeatWidget(seatMap[0], roomData),
                                      const SizedBox(width: 24),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: _seatWidget(1, seatMap[1], roomData),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  LayoutBuilder(
                                    builder: (context, constraints) => _balancedSeatRows(
                                      remaining: _seatCountFor(roomData) - 2,
                                      startIndex: 2,
                                      availableWidth: constraints.maxWidth,
                                      seatMap: seatMap,
                                      roomData: roomData,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        _audienceStrip(roomData),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),

                // ---------- Chat / Comments ----------
                _chatSection(),

                // ---------- Bottom control bar ----------
                _bottomBar(roomData),
              ],
            );
          },
          ),
        ),
      ),
    );
  }
}

// Simple data holder for one tile in the apps grid menu (icon + label,
// optional colored gradient for the "Interactive Features" row).
class _AppsMenuItem {
  final String label;
  final IconData icon;
  final List<Color>? gradient;
  final VoidCallback? onTap;
  const _AppsMenuItem(this.label, this.icon, {this.gradient, this.onTap});
}