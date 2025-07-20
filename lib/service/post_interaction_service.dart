import 'package:cloud_firestore/cloud_firestore.dart';

class PostInteractionService {
  static final _collection = FirebaseFirestore.instance.collection(
    'posts_interactions',
  );

  // Toggle like/unlike
  static Future<void> toggleLike(String postId, String userId) async {
    final docRef = _collection.doc(postId);
    final doc = await docRef.get();

    if (doc.exists) {
      List likedUsers = doc['liked_users'] ?? [];

      if (likedUsers.contains(userId)) {
        likedUsers.remove(userId); // Unlike
      } else {
        likedUsers.add(userId); // Like
      }

      await docRef.update({
        'liked_users': likedUsers,
        'likes': likedUsers.length,
      });
    } else {
      await docRef.set({
        'liked_users': [userId],
        'likes': 1,
        'comments': [],
      });
    }
  }

  // Check if post is liked
  static Future<bool> isPostLiked(String postId, String userId) async {
    final doc = await _collection.doc(postId).get();
    if (doc.exists) {
      List likedUsers = doc['liked_users'] ?? [];
      return likedUsers.contains(userId);
    }
    return false;
  }

  // Get like count
  static Future<int> getLikeCount(String postId) async {
    final doc = await _collection.doc(postId).get();
    if (doc.exists) {
      return doc['likes'] ?? 0;
    }
    return 0;
  }

  // Add comment
  static Future<void> addComment({
    required String postId,
    required String userId,
    required String userName,
    required String comment,
  }) async {
    final docRef = _collection.doc(postId);
    final snapshot = await docRef.get();

    final newComment = {
      "user_id": userId,
      "user_name": userName,
      "comment": comment,
      "timestamp": DateTime.now().toIso8601String(),
    };

    if (snapshot.exists) {
      final List comments = snapshot.data()?['comments'] ?? [];
      comments.add(newComment);

      await docRef.update({'comments': comments});
    } else {
      await docRef.set({
        'liked_users': [],
        'likes': 0,
        'comments': [newComment],
      });
    }
  }

  // Get all comments
  static Future<List<Map<String, dynamic>>> getComments(String postId) async {
    final doc = await _collection.doc(postId).get();
    if (doc.exists && doc.data()!.containsKey('comments')) {
      return List<Map<String, dynamic>>.from(doc['comments']);
    }
    return [];
  }
}
