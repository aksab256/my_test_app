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
        // ✅ إضافة حالة "مستخدم جديد" لإظهار الرسالة الترحيبية عند أول دخول
        'isNewUser': true, 
      };

      // 🔵 منطق النقاط والهدايا الترحيبية للمستهلك
      if (userType == "consumer") {
        userData['loyaltyPoints'] = 0; // القيمة المبدئية قبل تفعيل هدية الترحيب
        userData['hasClaimedWelcomeGift'] = false; // لم يستلم الهدية بعد
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
      
      // ✅ تسجيل التوكن مع إرسال الـ Role لضمان توجيه إشعارات الترحيب صح
      await _registerFCMTokenApi(userId, userType, address);

      return userCredential.user;
    } catch (e) {
      throw e.toString();
    }
  }
