const medicineUnits = ['ML', 'LITER', 'TABLET', 'CAPSULE', 'BOLUS', 'DOSE', 'VIAL', 'PIECE', 'GRAM', 'SACHET', 'TUBE'];

const adminRoutes = ['ORAL', 'INTRAMUSCULAR', 'SUBCUTANEOUS', 'INTRAVENOUS', 'TOPICAL', 'OTHER'];

const treatmentOutcomes = ['IN_PROGRESS', 'RECOVERED', 'FOLLOW_UP_REQUIRED', 'REFERRED', 'OTHER'];

const breedingMethods = ['NATURAL', 'ARTIFICIAL_INSEMINATION', 'EMBRYO_TRANSFER', 'OTHER'];

const breedingOutcomes = ['PENDING', 'PREGNANT', 'NOT_PREGNANT', 'CANCELLED', 'UNKNOWN'];

const visitTypes = ['EXAMINATION', 'ILLNESS', 'INJURY', 'VACCINATION', 'FOLLOW_UP', 'OTHER'];

String pretty(String value) {
  final text = value.toLowerCase().replaceAll('_', ' ');
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

String unitLabel(String unit) {
  switch (unit) {
    case 'ML':
      return 'ml';
    case 'LITER':
      return 'L';
    case 'GRAM':
      return 'g';
    default:
      return pretty(unit).toLowerCase();
  }
}

String defaultRoute(String? form) {
  if (form == 'INJECTION') return 'INTRAMUSCULAR';
  if (form == 'OINTMENT' || form == 'POUR_ON' || form == 'SPRAY') return 'TOPICAL';
  if (form == 'INTRAMAMMARY') return 'OTHER';
  return 'ORAL';
}

String whenLabel(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${ymd(value)} $hour:$minute';
}

String ymd(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String dueLabel(String? raw) {
  if (raw == null || raw.length < 10) return '';
  final day = DateTime.tryParse(raw.substring(0, 10));
  if (day == null) return raw.substring(0, 10);
  final today = DateTime.now();
  final diff = DateTime(day.year, day.month, day.day).difference(DateTime(today.year, today.month, today.day)).inDays;
  if (diff < 0) return 'Overdue · ${ymd(day)}';
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  return 'In $diff days · ${ymd(day)}';
}

String? endOfLocalDay(DateTime? date) {
  if (date == null) return null;
  return DateTime(date.year, date.month, date.day, 23, 59).toUtc().toIso8601String();
}

Map<String, dynamic> compact(Map<String, dynamic> body) {
  final copy = Map<String, dynamic>.from(body);
  copy.removeWhere((_, value) => value == null || (value is String && value.trim().isEmpty));
  return copy;
}
