import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RelationshipHelper {
  static final RelationshipHelper _instance = RelationshipHelper._internal();
  factory RelationshipHelper() => _instance;
  RelationshipHelper._internal();

  // Cache for relationships to reduce Firestore calls
  final Map<String, Map<String, dynamic>> _cache = {};

  /// Check relationship between current user and target user
  Future<Map<String, dynamic>?> getRelationship(String targetUid) async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null || targetUid.isEmpty) return null;
      if (currentUid == targetUid) return null;

      // Check cache first
      final cacheKey = '$currentUid-$targetUid';
      if (_cache.containsKey(cacheKey)) {
        final cached = _cache[cacheKey];
        // Check if expired
        if (cached != null) {
          final expiryDate = cached['expiryDate'] as DateTime?;
          if (expiryDate != null && DateTime.now().isAfter(expiryDate)) {
            _cache.remove(cacheKey);
            return null;
          }
          return cached;
        }
        _cache.remove(cacheKey);
        return null;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('relationships')
          .where('friendId', isEqualTo: targetUid)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final expiryDate = (data['expiryDate'] as Timestamp?)?.toDate();
        
        // Check if expired
        if (expiryDate != null && DateTime.now().isAfter(expiryDate)) {
          _cache[cacheKey] = null;
          return null;
        }

        // Check if both users have relationship (mutual)
        final mutualCheck = await FirebaseFirestore.instance
            .collection('users')
            .doc(targetUid)
            .collection('relationships')
            .where('friendId', isEqualTo: currentUid)
            .limit(1)
            .get();

        if (mutualCheck.docs.isEmpty) {
          _cache[cacheKey] = null;
          return null;
        }

        final mutualData = mutualCheck.docs.first.data();
        
        // Return combined data (use current user's relationship data)
        final result = {
          'frameColor': data['frameColor'] ?? mutualData['frameColor'] ?? '#FF6B6B',
          'relationshipEmoji': data['relationshipEmoji'] ?? mutualData['relationshipEmoji'] ?? '💕',
          'relationshipLabel': data['relationshipLabel'] ?? mutualData['relationshipLabel'] ?? 'Friend',
          'friendId': targetUid,
          'friendName': data['friendName'] ?? 'Unknown',
          'expiryDate': expiryDate,
        };
        
        _cache[cacheKey] = result;
        return result;
      }
      
      _cache[cacheKey] = null;
      return null;
    } catch (e) {
      print('Error checking relationship: $e');
      return null;
    }
  }

  /// Clear cache for a user
  void clearCache(String? uid) {
    if (uid == null) return;
    _cache.removeWhere((key, _) => key.contains(uid));
  }

  /// Clear all cache
  void clearAllCache() {
    _cache.clear();
  }

  /// Parse frame color from hex string
  static Color parseFrameColor(String? colorHex) {
    try {
      final hex = colorHex ?? '#FF6B6B';
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) {
      return Colors.pinkAccent;
    }
  }

  /// Get frame gradient for a relationship
  static LinearGradient getFrameGradient(Color color) {
    return LinearGradient(
      colors: [
        color.withOpacity(0.8),
        color.withOpacity(0.3),
      ],
    );
  }

  /// Get frame shadow for a relationship
  static BoxShadow getFrameShadow(Color color) {
    return BoxShadow(
      color: color.withOpacity(0.5),
      blurRadius: 20,
      spreadRadius: 4,
    );
  }
}