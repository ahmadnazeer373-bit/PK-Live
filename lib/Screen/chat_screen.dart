import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final String myUid;
  late final String chatId;

  String? _otherAvatar;
  Timer? _typingDebounce;
  bool _iAmTyping = false;
  final Set<String> _seenMarked = {};

  @override
  void initState() {
    super.initState();
    myUid = FirebaseAuth.instance.currentUser!.uid;
    final ids = [myUid, widget.otherUserId]..sort();
    chatId = ids.join('_');
    _loadOtherAvatar();
  }

  Future<void> _loadOtherAvatar() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.otherUserId).get();
    if (mounted) {
      setState(() => _otherAvatar = doc.data()?['avatar'] as String?);
    }
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _setTyping(false);
    messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------- Typing indicator ----------------

  void _onTextChanged(String value) {
    if (!_iAmTyping) {
      _iAmTyping = true;
      _setTyping(true);
    }
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      _iAmTyping = false;
      _setTyping(false);
    });
  }

  Future<void> _setTyping(bool value) async {
    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'typing': {myUid: value},
    }, SetOptions(merge: true));
  }

  // ---------------- Sending ----------------

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    messageController.clear();
    _typingDebounce?.cancel();
    _iAmTyping = false;
    _setTyping(false);

    final myDoc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
    final myData = myDoc.data() ?? {};
    final myName = (myData['name'] as String?)?.trim().isNotEmpty == true
        ? (myData['name'] as String).trim()
        : "User";
    final myAvatar = myData['avatar'] as String?;

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);

    try {
      await chatRef.collection('messages').add({
        'senderId': myUid,
        'text': text,
        'type': 'text',
        'timestamp': FieldValue.serverTimestamp(),
        'seenBy': [myUid],
      });

      await chatRef.set({
        'participants': [myUid, widget.otherUserId],
        'participantNames': {
          myUid: myName,
          widget.otherUserId: widget.otherUserName,
        },
        'participantAvatars': {
          if (myAvatar != null) myUid: myAvatar,
          if (_otherAvatar != null) widget.otherUserId: _otherAvatar,
        },
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 🔥 MESSAGE NOTIFICATION
      final notificationRef = FirebaseFirestore.instance
          .collection('notifications')
          .doc(widget.otherUserId)
          .collection('items')
          .doc();

      await notificationRef.set({
        'type': 'message',
        'title': 'New Message',
        'body': '$myName: $text',
        'senderId': myUid,
        'senderName': myName,
        'messagePreview': text,
        'chatId': chatId,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't send message, please try again")),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------------- Seen status ----------------

  void _markSeenIfNeeded(List<QueryDocumentSnapshot> messages) {
    for (final doc in messages) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['senderId'] == myUid) continue;
      final seenBy = List<String>.from(data['seenBy'] ?? []);
      if (seenBy.contains(myUid) || _seenMarked.contains(doc.id)) continue;

      _seenMarked.add(doc.id);
      doc.reference.update({
        'seenBy': FieldValue.arrayUnion([myUid]),
      });
    }
  }

  // ---------------- Delete message ----------------

  Future<void> _confirmDelete(String messageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1730),
        title: const Text("Delete message?", style: TextStyle(color: Colors.white)),
        content: const Text("This will only delete it for you.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
    }
  }

  // ---------------- Helpers ----------------

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $period";
  }

  Widget _avatar(String? emoji, {double size = 36}) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Color(0xFFFF512F), Color(0xFFDD2476)]),
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF1A1A2E),
        ),
        alignment: Alignment.center,
        child: Text(emoji ?? "🧑", style: TextStyle(fontSize: size * 0.46)),
      ),
    );
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      extendBodyBehindAppBar: false,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A1730), Color(0xFF0D0B1E)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  _avatar(_otherAvatar, size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('chats').doc(chatId).snapshots(),
                      builder: (context, snap) {
                        final data = snap.data?.data() as Map<String, dynamic>?;
                        final typingMap = Map<String, dynamic>.from(data?['typing'] ?? {});
                        final otherTyping = typingMap[widget.otherUserId] == true;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.otherUserName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: otherTyping
                                  ? const Text(
                                      "typing...",
                                      key: ValueKey("typing"),
                                      style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                                    )
                                  : const SizedBox.shrink(key: ValueKey("empty")),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF120F26), Color(0xFF0D0B1E)],
          ),
        ),
        child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(100)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text("Couldn't load messages", style: TextStyle(color: Colors.white54)),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.redAccent),
                    );
                  }

                  final messages = snapshot.data!.docs;

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline, color: Colors.white24, size: 56),
                          const SizedBox(height: 12),
                          const Text(
                            "No messages yet\nStart the conversation",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white38),
                          ),
                        ],
                      ),
                    );
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) => _markSeenIfNeeded(messages));

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final doc = messages[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final isMe = data['senderId'] == myUid;
                      final text = data['text'] ?? "";
                      final ts = data['timestamp'] as Timestamp?;
                      final timeStr = ts != null ? _formatTime(ts.toDate()) : "";
                      final seenBy = List<String>.from(data['seenBy'] ?? []);
                      final isSeenByOther = seenBy.contains(widget.otherUserId);

                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 200),
                        builder: (context, value, child) => Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, (1 - value) * 8),
                            child: child,
                          ),
                        ),
                        child: GestureDetector(
                          onLongPress: isMe ? () => _confirmDelete(doc.id) : null,
                          child: Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!isMe) ...[
                                  _avatar(_otherAvatar, size: 26),
                                  const SizedBox(width: 6),
                                ],
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 3),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      gradient: isMe
                                          ? const LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)])
                                          : null,
                                      color: isMe ? null : Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                                        bottomRight: Radius.circular(isMe ? 4 : 16),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              timeStr,
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.6),
                                                fontSize: 10,
                                              ),
                                            ),
                                            if (isMe) ...[
                                              const SizedBox(width: 4),
                                              Icon(
                                                isSeenByOther ? Icons.done_all : Icons.done,
                                                size: 13,
                                                color: isSeenByOther ? Colors.lightBlueAccent : Colors.white70,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
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
            Container(
              margin: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image_outlined, color: Colors.white54),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Image sending is coming soon")),
                      );
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      onChanged: _onTextChanged,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white10,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: messageController,
                    builder: (context, value, _) {
                      final hasText = value.text.trim().isNotEmpty;
                      return GestureDetector(
                        onTap: hasText ? sendMessage : null,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: hasText
                                ? const LinearGradient(colors: [Color(0xFFFF512F), Color(0xFFDD2476)])
                                : null,
                            color: hasText ? null : Colors.white10,
                          ),
                          child: Icon(
                            hasText ? Icons.send : Icons.mic_none,
                            color: hasText ? Colors.white : Colors.white38,
                            size: 20,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}