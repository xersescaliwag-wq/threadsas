// lib/core/json.dart

/// These helpers read JSON values safely. Numbers can arrive as int or double,
/// and a missing list becomes an empty list.
int asInt(Object? value) => value is num ? value.toInt() : 0;

DateTime? asDate(Object? value) {
  if (value is! String) return null;
  return DateTime.parse(value).toLocal();
}

List<String> asStringList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList();
}
