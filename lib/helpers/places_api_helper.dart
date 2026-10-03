// Pure helpers for Places Web API status handling (no Flutter dependency).
//
// Keeps API status mapping in one place so UI code never crashes on error
// statuses and never logs secrets: only the status string and Google's
// `error_message` are logged, never request URLs, keys, or predictions.

// Statuses returned in the `status` field of Places Web API responses.
enum PlacesApiStatus {
  ok,
  zeroResults,
  notFound,
  requestDenied,
  overQueryLimit,
  invalidRequest,
  unknown,
}

// Maps a raw `status` value to [PlacesApiStatus]. Never throws.
PlacesApiStatus parsePlacesStatus(Object? raw) {
  switch (raw) {
    case 'OK':
      return PlacesApiStatus.ok;
    case 'ZERO_RESULTS':
      return PlacesApiStatus.zeroResults;
    case 'NOT_FOUND':
      return PlacesApiStatus.notFound;
    case 'REQUEST_DENIED':
      return PlacesApiStatus.requestDenied;
    case 'OVER_QUERY_LIMIT':
      return PlacesApiStatus.overQueryLimit;
    case 'INVALID_REQUEST':
      return PlacesApiStatus.invalidRequest;
    default:
      return PlacesApiStatus.unknown;
  }
}

// Arabic user-facing message for a non-OK Places status.
// Contains no request data, keys, or URLs.
String placesUserMessage(PlacesApiStatus status) {
  switch (status) {
    case PlacesApiStatus.ok:
      return '';
    case PlacesApiStatus.zeroResults:
    case PlacesApiStatus.notFound:
      return 'لا توجد نتائج مطابقة لبحثك';
    case PlacesApiStatus.requestDenied:
      return 'تعذر إتمام البحث (تم رفض الطلب). حاول لاحقًا';
    case PlacesApiStatus.overQueryLimit:
      return 'تم تجاوز حد الطلبات مؤقتًا. حاول بعد قليل';
    case PlacesApiStatus.invalidRequest:
      return 'طلب بحث غير صالح. عدّل كلمة البحث وحاول مجددًا';
    case PlacesApiStatus.unknown:
      return 'تعذر إتمام البحث. حاول مجددًا';
  }
}

// Log-safe one-line summary: status only, never URLs, keys, or predictions.
String placesLogLine(String api, PlacesApiStatus status, Object? errorMessage) {
  final detail =
      (errorMessage is String && errorMessage.isNotEmpty) ? ' ($errorMessage)' : '';
  return 'Places $api status: ${status.name}$detail';
}

// Extracts `{'lat': .., 'lng': ..}` from a place-details JSON body,
// or null when the response is not OK or has no usable geometry.
// Never throws.
Map<String, double>? parsePlaceDetailsLocation(Map<String, dynamic> data) {
  if (parsePlacesStatus(data['status']) != PlacesApiStatus.ok) return null;
  final result = data['result'];
  if (result is! Map) return null;
  final geometry = result['geometry'];
  if (geometry is! Map) return null;
  final loc = geometry['location'];
  if (loc is! Map) return null;
  final lat = loc['lat'];
  final lng = loc['lng'];
  if (lat is! num || lng is! num) return null;
  return {'lat': lat.toDouble(), 'lng': lng.toDouble()};
}
