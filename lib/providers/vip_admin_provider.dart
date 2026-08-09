import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VipAdminProvider extends ChangeNotifier {

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;


  bool isLoading = false;


  List<Map<String, dynamic>> vipLevels = [];



  // ============================
  // Load VIP Levels
  // ============================

  Future<void> loadVipLevels() async {

    try {

      isLoading = true;
      notifyListeners();


      final snapshot = await _firestore
          .collection("vip_levels")
          .orderBy("level")
          .get();



      vipLevels = snapshot.docs.map((doc){

        return {

          "id": doc.id,

          ...doc.data(),

        };

      }).toList();



    } catch(e){

      debugPrint(
        "Load VIP Error: $e"
      );

    }


    isLoading = false;
    notifyListeners();

  }




  // ============================
  // Add VIP Level
  // ============================

  Future<void> addVipLevel({

    required String levelName,

    required int requiredCoins,

    required List benefits,

  }) async {


    await _firestore
        .collection("vip_levels")
        .add({

      "level": levelName,

      "coins": requiredCoins,

      "benefits": benefits,

      "status": true,

      "createdAt":
      FieldValue.serverTimestamp(),


    });



    await loadVipLevels();

  }







  // ============================
  // Update VIP Level
  // ============================

  Future<void> updateVipLevel({

    required String id,

    required Map<String,dynamic> data,

  }) async {


    await _firestore
        .collection("vip_levels")
        .doc(id)
        .update(data);



    await loadVipLevels();


  }







  // ============================
  // Delete VIP Level
  // ============================

  Future<void> deleteVipLevel(
      String id
      ) async {


    await _firestore
        .collection("vip_levels")
        .doc(id)
        .delete();



    await loadVipLevels();


  }








  // ============================
  // Update User VIP
  // ============================

  Future<void> updateUserVip({

    required String uid,

    required int vipLevel,

  }) async {


    await _firestore
        .collection("users")
        .doc(uid)
        .update({

      "vipLevel": vipLevel,

      "vipUpdatedAt":
      FieldValue.serverTimestamp(),

    });


  }







  // ============================
  // Remove User VIP
  // ============================

  Future<void> removeUserVip(
      String uid
      ) async {


    await _firestore
        .collection("users")
        .doc(uid)
        .update({

      "vipLevel":0,

      "vipUpdatedAt":
      FieldValue.serverTimestamp(),

    });


  }



}