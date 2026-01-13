  Future<User?> registerClient({
    required String fullname,
    required String email,    
    required String phone,    
    required String password,
    required String address,
    required String country,
    required String userType,
    Map<String, double>? location,
    String? logoUrl,       
    String? crUrl,         
    String? tcUrl,         
    String? merchantName,
    String? businessType,
    String? additionalPhone,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      final String userId = userCredential.user!.uid;

      final Map<String, dynamic> userData = {
        'fullname': fullname,
        'email': email,
        'phone': phone,       
        'address': address,
        'location': location,
        'role': userType,     
        'country': country,
        'createdAt': FieldValue.serverTimestamp(),
        'isNewUser': true, 
      };

      // 🔵 تعديل منطق المستهلك ليتوافق مع "مستمع" الـ Home
      if (userType == "consumer") {
        userData['loyaltyPoints'] = 0; 
        userData['hasClaimedWelcomeGift'] = false; 
        // ✅ هذا الحقل حيوي جداً لأن الـ Home يراقبه لإظهار الـ Celebration
        userData['welcomePointsProcessed'] = false; 
      }

      if (userType == 'seller') {
        userData['merchantName'] = merchantName;
        userData['businessType'] = businessType;
        userData['additionalPhone'] = additionalPhone;
        userData['logoUrl'] = logoUrl;
        userData['crUrl'] = crUrl;
        userData['tcUrl'] = tcUrl;
        userData['isVerified'] = false;
      } else {
        userData['isVerified'] = true;
      }

      String targetCollectionName;
      if (userType == "seller") {
        targetCollectionName = "pendingSellers";
      } else if (userType == "consumer") {
        targetCollectionName = "consumers";
      } else {
        targetCollectionName = "users"; 
      }

      await _firestore.collection(targetCollectionName).doc(userId).set(userData);
      
      await _registerFCMTokenApi(userId, userType, address);

      return userCredential.user;
    } catch (e) {
      throw e.toString();
    }
  }
