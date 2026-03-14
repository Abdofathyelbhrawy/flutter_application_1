void main() {
  DateTime utcTime = DateTime.parse("2026-03-14T14:25:00Z"); // 16:25 local
  DateTime localTime = DateTime(utcTime.year, utcTime.month, utcTime.day, 10, 0); // 10:00 local

  print("utcTime (isUtc=${utcTime.isUtc}): $utcTime");
  print("localTime (isUtc=${localTime.isUtc}): $localTime");

  Duration diff = utcTime.difference(localTime);
  print("Difference: ${diff.inHours} hours, ${diff.inMinutes % 60} mins");
}
