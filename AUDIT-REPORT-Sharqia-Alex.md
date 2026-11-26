# تقرير تدقيق Read-only — my_test_app: مشتري الشرقية مقابل تاجر الإسكندرية

> **منهجية:** قراءة فقط، بدون تعديل كود/بيانات/إعدادات، بدون Commit/Push/Deploy.
> **النطاق:** `my_test_app` فقط (دور buyer يشتري من seller يحدد مناطق توصيل).
> **قيد التوثيق:** تعذّر تشغيل أوامر `git` بسبب حظر Sandbox على `powershell`، لذلك `origin/main hash` وتاريخ الرفع **غير متحقق منهما**. كل الأدلة من ملفات working-tree كما قُرئت. لم تُشغَّل `flutter test`.

## 1) الخلاصة التنفيذية

نعم — مشتري الشرقية **يستطيع** رؤية أسعار تاجر الإسكندرية وإضافتها للسلة وإتمام الطلب في مسارات محددة، رغم وجود فلترة صحيحة في مسارات أخرى. الخلل **جزئي في العرض وشامل في الإنفاذ**: لا توجد فلترة Backend/Firestore query جغرافية، ولا إعادة تحقق عند السلة أو إنشاء الطلب.

## 2) رحلة موقع المشتري حتى السعر والسلة

```
دخول/تسجيل + اختيار موقع (خريطة GPS) [client_details_step.dart:124]
  → SharedPreferences: loggedUser.location {lat,lng} + user_lat/user_lng [auth_service.dart:234]
  → BuyerDataProvider: userLat/userLng (ثابت) + sessionLat/sessionLng (مؤقت) [buyer_data_provider.dart:68]
  → effectiveLat/effectiveLng = sessionLat ?? userLat
  → BuyerAreaResolver: GPS → أسماء مناطق عبر GeoJSON [buyer_area_resolver.dart:111]
  → offer_geo_filter: zones.any(buyerAreas.contains) [offer_geo_filter.dart:97]
  → عرض السعر (بعض الشاشات) → addItemToCart (بدون فحص) [cart_provider.dart:386]
  → placeOrder (بدون فحص) [checkout_controller.dart:75]
```

### 2.1 أين يحدد المشتري موقعه أول مرة؟

- شاشة بيانات العميل بعد التسجيل: `_handleMapOpeningSequence` يطلب إذن الموقع ثم `Geolocator.getCurrentPosition` ويفتح خريطة لاختيار النقطة — `my_test_app/lib/screens/auth/client_details_step.dart:124`.
- مسارات أخرى تستخدم GPS لاحقًا (بحث المتاجر، طلب خاص) لكن التسجيل هو المصدر الأول للمشتري.

### 2.2 هل يُحفظ؟ أين؟ وبأي صيغة؟

- نعم: `SharedPreferences` مفتاح `loggedUser` كـ JSON فيه `location: {lat, lng}`، plus مفاتيح منفصلة `user_lat`/`user_lng` — `my_test_app/lib/helpers/auth_service.dart:234-265`.
- `BuyerDataProvider` يحمّلها إلى `userLat/userLng/userAddress` عند `initializeData` — `my_test_app/lib/providers/buyer_data_provider.dart:107-141`.
- موقع الجلسة المؤقت عبر `setSessionLocation(lat,lng)` ولا يُحفظ في Firestore/Local — `buyer_data_provider.dart:92`.
- **الصيغة إحداثيات فقط (double). لا تُحفظ محافظة/مدينة/منطقة إطلاقًا.**

### 2.3 هل يُستخدم في جلب المنتجات أم للعرض فقط؟

يُستخدم فعليًا في 4 مسارات عبر `BuyerAreaResolver.resolveBuyerAreas(lat: effectiveLat, lng: effectiveLng)`:

- `trader_offers_screen.dart:237-244`
- `product_details_screen.dart:57-60`
- `product_list_grid.dart:45-56` (يمررها إلى `ProductOffersProvider`)
- `traders_screen.dart:122` عبر `_getUserLocation` (يقرأ `loggedUser.location` مباشرة)

### 2.4 ماذا عند رفض الصلاحية أو غياب الموقع؟

- الرفض في التسجيل = `return` بدون حفظ موقع — `client_details_step.dart:124-146`.
- `resolveBuyerAreas(lat:null,lng:null)` تُرجع `[]` — `buyer_area_resolver.dart:111-120` — والقاعدة الموحدة: **يرى الـGlobal فقط** (`isOfferVisibleForBuyer` + `TradersScreen:191`).

### 2.5 قيم افتراضية/fallback خطيرة

| الموقع | القيمة | الأثر |
|---|---|---|
| المنتجات العامة للمستهلك | `_selectedCity = "الإسكندرية"` ثابت | `consumer_general_product_list_screen.dart:24` — يتجاهل GPS تمامًا |
| مسار `/abaatly-had` بدون موقع | `LatLng(30.0444, 31.2357)` القاهرة | `main.dart:443` |
| الهدايا بدون موقع | `userLat ?? 0.0, userLng ?? 0.0` أي خليج غينيا | `gifts_tab.dart:31-32` |
| ملف الإسكندرية كـ fallback | `GEOJSON_FILE_PATH` للإسكندرية | `delivery_constants.dart:8` |

## 3) مناطق توصيل التاجر

### 3.1 أين تُحفظ؟

- `sellers/{sellerId}.deliveryAreas: List<String>` — `delivery_area_data_source.dart:8-9` و`area_service.dart:65-71`.
- التحديث عبر `DeliveryAreaDataSource.updateAreas` (`set merge:true`) و`AreaService.saveSellerAreas` (`update` ثم استدعاء Cloud Function للمزامنة).

### 3.2 الشكل الفعلي

- `List<String>` أسماء مناطق نصية (مثال: سموحة، المنتزه). لا polygons ولا radius ولا إحداثيات.
- مستند العرض يحمل حقلين: `deliveryZones` (جديد) و`deliveryAreas` (قديم للتوافق). القراءة الموحدة `readOfferZones`: `deliveryZones` أولًا ثم `deliveryAreas` — `offer_geo_filter.dart:64-76` و`offer_data_model.dart:50-53`.

### 3.3 الفرق بين الحقول

- `deliveryAreas` على مستوى `sellers` = مصدر التاجر.
- `deliveryZones`/`deliveryAreas` على مستوى `productOffers` = نسخة مُزامنة عبر Cloud Function (`callCloudFunctionToUpdateOffers` — `area_service.dart:31`).
- لا توجد محافظات/مدن ككيانات مستقلة؛ المحافظات المدعومة فقط ملفا GeoJSON: الإسكندرية والبحيرة — `delivery_constants.dart:12-15` و`traders_screen.dart:35-48`.

### 3.4 كيف تتم المقارنة؟

1. تحميل polygons الإسكندرية + البحيرة فقط.
2. `isPointInPolygon(GPS, polygon)` لكل منطقة → `buyerAreas: List<String>`.
3. مقارنة نصية تامة: `zones.any(buyerAreas.contains)` — `offer_geo_filter.dart:97`.
4. كل ذلك **client-side بعد جلب كل المستندات**. لا `where` جغرافي في Firestore.

### 3.5 الدقة والبيانات المفقودة

- المقارنة حساسة لحرف الاسم (مفردات GeoJSON `name`/`name:ar`/...) — `buyer_area_resolver.dart:16-43`.
- فارغ/غائب = Global يظهر للجميع — `offer_geo_filter.dart:79-81` و`traders_screen.dart:192-200`.
- قديم: فشل Cloud Function يترك `productOffers` بمناطق قديمة بينما `sellers` محدثة — `area_service.dart:73-80`.

## 4) فلترة كل مسار

| # | المسار | Backend/Firestore؟ | واجهة؟ | لا شيء؟ | الدليل |
|---|---|---|---|---|---|
| 1 | الرئيسية buyer (شبكات `ProductListGrid`) | لا | نعم client | — | `product_offers_provider.dart:41-83` |
| 2 | التصنيفات (`BuyerProductListScreen` → `ProductListGrid`) | لا | نعم client | — | `buyer_product_list_screen.dart:118` + `product_list_grid.dart:68` |
| 3 | البحث `SearchScreen` | لا | لا | **لا شيء** — يعرض `displayPrice` من `units[0].price` لأي عرض active | `product_repository.dart:45-103` + `search_screen.dart:157-160` |
| 4 | عروض تاجر `TraderOffersScreen` | لا | نعم client (`productOffers` context) | — | `trader_offers_screen.dart:233` |
| 5 | تفاصيل منتج `ProductDetailsScreen` | لا | نعم client | — | `product_details_screen.dart:98-109` |
| 6 | رابط مباشر `/traderOffers` و`/productDetails` | لا | يلتف على `TradersScreen`؛ التفاصيل/عروض التاجر ترشح، لكن الوصول نفسه بلا بوابة | جزئي | `main.dart:491-503` |
| 7 | المنتجات العامة (consumer) | لا | فلترة ثابتة خاطئة: `contains("الإسكندرية")` على `deliveryAreas` فقط | تتجاهل `deliveryZones` وGPS | `consumer_general_product_list_screen.dart:91-94` |
| 8 | الهدايا `GiftsTab` | لا | منطق مختلف مكسور: يتوقع `deliveryAreas` كـ JSON فيه `coords` | صيغة لا تطابق `List<String>` المحفوظة | `gifts_tab.dart:43-70` |
| 9 | السلة `addItemToCart` | لا | لا (فحص مخزون/كمية فقط) | **لا شيء** | `cart_provider.dart:386-444` |
| 10 | إنشاء الطلب `placeOrder` | لا | لا (فحص `address != null` فقط) | **لا شيء** | `checkout_controller.dart:104-114` |

ملاحظة معمارية مقصودة ومثبتة بالاختبارات: سياق `sellerStore` يعرض كل شيء (الأهلية حُسمت عند التاجر)، وسياق `productOffers` يرشح — `offer_geo_filter.dart:12-19` و`offer_geo_visibility_test.dart:22-48`. المشكلة أن `TraderOffersScreen` يستخدم `productOffers` (مرشح) بينما الدخول إليه يمكن أن يتم مباشرة دون المرور بقائمة التجار المرشحة.

## 5) السلة والأسعار — الإجابة المباشرة

- **هل يمكن لمنتج غير قابل للتوصيل أن يظهر سعره؟** نعم: البحث يعرض `displayPrice` بلا أي فحص، والمنتجات العامة تعرض عروض الإسكندرية لأي شخص، وأي `offerId` ممرر برابط مباشر يعرض سعره في شاشة لا ترشح (أو قبل الترشيح في المسارات المرشحة إذا تطابقت الثغرة).
- **هل يُعاد التحقق عند الإضافة؟** لا. `addItemToCart` يتحقق من `min/max/stock` فقط — `cart_provider.dart:405-417`. `BuyerProductCard._addToCart` و`ProductDetails._addToCart` يمرران السعر المعروض مباشرة — `buyer_product_card.dart:40-71` و`product_details_screen.dart:119-143`.
- **هل يُعاد التحقق عند الطلب؟** لا. `placeOrder` يخزن `effectiveLat/effectiveLng` في `buyer`/`deliveryLocation` كبيانات وصفية فقط دون مقارنتها بمناطق البائع — `checkout_controller.dart:206-256`. `validateCheckoutQuantities` يفحص كميات وحدًا أدنى ماليًا فقط — `cart_provider.dart:513-552`.

## 6) اختبار السيناريوهات الأربعة (تاجر إسكندرية فقط)

تاجر: `deliveryAreas = ["سموحة", "المنتزه"]`. مشتري الإسكندرية: GPS داخل سموحة. مشتري الشرقية: GPS في الزقازيق (خارج كل polygons). بلا موقع: `effectiveLat/Lng = null`.

| المشتري \ الشاشة | التجار | عروض التاجر | تفاصيل/تصنيفات | البحث | العامة (ثابت إسكندرية) | السلة/الطلب |
|---|---|---|---|---|---|---|
| إسكندرية | يرى التاجر | يرى عروضه وأسعارها | يرى الأسعار | يرى الأسعار | يرى | يُضيف ويطلب (صحيح) |
| الشرقية | **لا يرى التاجر** (لا تطابق polygon) + يرى Global فقط | **لا يرى** عروض المناطق، يرى Global فقط | **لا يرى** أسعار المناطق، يرى Global فقط | **يرى أسعار الإسكندرية** ويستطيع الإضافة | **يرى منتجات الإسكندرية** (المدينة ثابتة) | **يُضيف ويطلب بلا اعتراض** |
| بلا موقع | Global فقط | Global فقط | Global فقط | **يرى الكل** | **يرى منتجات الإسكندرية** | **يُضيف ويطلب بلا اعتراض** |

المتوقع مقابل الفعلي: الفعلي يطابق المتوقع في المسارات الأربعة المرشحة، ويخالفه تمامًا في البحث/العامة/السلة/الطلب.

## 7) هل الخلل في بعض الصفحات أم النظام كله؟

جزئي في العرض (4 مسارات سليمة client-side)، شامل في الإنفاذ (لا حاجز Backend، ولا فحص في السلة/الطلب، ومساران يعرضان بلا/بفلترة خاطئة). أي إعلان أو رابط مباشر يلتف على المسارات السليمة يُسقط الضمان كله.

## 8) مخاطر إعلانات Facebook واسعة النطاق

1. استهداف جغرافي واسع (الشرقية + الدلتا) مع هبوط على بحث/منتجات عامة/روابط منتجات = ظهور أسعار غير قابلة للتوصيل.
2. طلبات COD غير قابلة للتنفيذ: شحن، مرتجع، استرداد، عبء دعم، تقييمات سلبية.
3. تلوث قياس `logPurchase` بقيم تتضمن طلبات ستفشل لوجستيًا — `checkout_controller.dart:300`.
4. تباين `sellers` مقابل `productOffers` عند فشل مزامنة Cloud Function يضخم المشكلة أثناء الحملات (تحديث مناطق متكرر).

## 9) الملفات والدوال الشاهدة (مختصر)

- `lib/services/buyer_area_resolver.dart:111` — بلا إحداثيات → `[]`.
- `lib/utils/offer_geo_filter.dart:89-115` — قاعدة الظهور والسياقان.
- `lib/providers/buyer_data_provider.dart:68-72` — `effectiveLat/Lng`.
- `lib/helpers/auth_service.dart:234-265` — صيغة الحفظ `{lat,lng}`.
- `lib/constants/delivery_constants.dart:12-15` — محافظتان فقط.
- `lib/screens/buyer/traders_screen.dart:179-212` — فلترة التجار client-side.
- `lib/screens/buyer/trader_offers_screen.dart:233` — فلترة عروض التاجر.
- `lib/screens/product_details_screen.dart:98-109` — فلترة التفاصيل.
- `lib/providers/product_offers_provider.dart:41-83` — فلترة الشبكات.
- `lib/repositories/product_repository.dart:45-103` — بحث بلا فلترة.
- `lib/screens/consumer/consumer_general_product_list_screen.dart:24,91-94` — مدينة ثابتة.
- `lib/screens/buyer/gifts_tab.dart:30-70` — صيغة مختلفة و`(0,0)`.
- `lib/providers/cart_provider.dart:386-444` — إضافة بلا فحص جغرافي.
- `lib/controllers/checkout_controller.dart:75-114,206-256` — طلب بلا فحص جغرافي.
- `lib/services/area_service.dart:61-87` — حفظ المناطق ومزامنة العروض.
- `lib/main.dart:443,491-503` — fallback القاهرة والروابط المباشرة.
- `test/offer_geo_visibility_test.dart:63-265` — توثيق القصد (unit فقط).

## 10) حدود التدقيق (غير مفحوص)

- `origin/main hash`/التاريخ (تعذر git)، قواعد Firestore الأمنية، Cloud Function `updateLocation`/`createOrdersWithPromos`، `ConsumerHome/StoreSearch` بالتفصيل، وأي Backend خارج `my_test_app`.
