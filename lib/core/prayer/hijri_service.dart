import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Comprehensive Hijri Date Representation
class HijriDate {
  final int day;
  final int month;
  final int year;
  final DateTime gregorianDate;

  const HijriDate({
    required this.day,
    required this.month,
    required this.year,
    required this.gregorianDate,
  });

  String get monthNameEn => HijriService.monthNamesEn[month - 1];
  String get monthNameAr => HijriService.monthNamesAr[month - 1];
  String get monthNameUr => HijriService.monthNamesUr[month - 1];

  /// Sacred Month in Islam (Al-Ashhur Al-Hurum: Muharram, Rajab, Dhu al-Qi'dah, Dhu al-Hijjah)
  bool get isSacredMonth => month == 1 || month == 7 || month == 11 || month == 12;

  /// Ayyam al-Beed (White Days Sunnah Fasting: 13th, 14th, 15th of lunar month)
  bool get isWhiteDay => day == 13 || day == 14 || day == 15;

  /// Full formatted string (e.g. "19 Rabi' al-Awwal 1448 AH")
  String get formattedEn => '$day $monthNameEn $year AH';
  String get formattedAr => '$day $monthNameAr $year هـ';
  String get formattedUr => '$day $monthNameUr $year ھ';

  /// Events occurring on this Hijri date
  List<IslamicEvent> get events => HijriService.getEventsForDate(day, month);
}

/// Structured Islamic Event with metadata
class IslamicEvent {
  final int day;
  final int month;
  final String titleEn;
  final String titleUr;
  final String titleAr;
  final String description;
  final bool isMajor; // Eid, Ramadan, Ashura

  const IslamicEvent({
    required this.day,
    required this.month,
    required this.titleEn,
    required this.titleUr,
    required this.titleAr,
    required this.description,
    this.isMajor = false,
  });
}

/// Professional Standalone Hijri Calendar Service
/// Calculates Kuwaiti / Astronomical lunar phases with Ruet-e-Hilal moon-sighting offset.
class HijriService {
  HijriService._();

  static const String _prefsOffsetKey = 'hijri_day_offset';
  static int _cachedOffset = 1; // Default +1 day for Pakistan / South Asia moon sighting
  static bool _initialized = false;

  static const List<String> monthNamesEn = [
    'Muharram',
    'Safar',
    'Rabi\' al-Awwal',
    'Rabi\' al-Thani',
    'Jumada al-Awwal',
    'Jumada al-Thani',
    'Rajab',
    'Sha\'ban',
    'Ramadan',
    'Shawwal',
    'Dhu al-Qi\'dah',
    'Dhu al-Hijjah',
  ];

  static const List<String> monthNamesAr = [
    'مُحَرَّم',
    'صَفَر',
    'رَبِيع الأَوَّل',
    'رَبِيع الآخِر',
    'جُمَادَى الأُولَى',
    'جُمَادَى الآخِرَة',
    'رَجَب',
    'شَعْبَان',
    'رَمَضَان',
    'شَوَّال',
    'ذُو القَعْدَة',
    'ذُو الحِجَّة',
  ];

  static const List<String> monthNamesUr = [
    'محرم الحرام',
    'صفر المظفر',
    'ربیع الاول',
    'ربیع الثانی',
    'جمادی الاول',
    'جمادی الثانی',
    'رجب المرجب',
    'شعبان المعظم',
    'رمضان المبارک',
    'شوال المکرم',
    'ذی القعدہ',
    'ذی الحجہ',
  ];

  /// Master list of major authentic Islamic Historical Events & Sunnah Occasions
  static const List<IslamicEvent> allEvents = [
    IslamicEvent(
      day: 1,
      month: 1,
      titleEn: 'Islamic New Year (Hijri 1448)',
      titleUr: 'یکم محرم — نیا اسلامی سال',
      titleAr: 'رأس السنة الهجرية',
      description: 'First day of the Islamic lunar calendar year.',
      isMajor: true,
    ),
    IslamicEvent(
      day: 9,
      month: 1,
      titleEn: 'Tasu\'a (Day before Ashura)',
      titleUr: 'تاسوعاء — نویں محرم کا روزہ',
      titleAr: 'تاسوعاء',
      description: 'Sunnah fasting day along with 10th Muharram.',
    ),
    IslamicEvent(
      day: 10,
      month: 1,
      titleEn: 'Day of Ashura',
      titleUr: 'یوم عاشوراء',
      titleAr: 'يوم عاشوراء',
      description: 'Day Prophet Musa (AS) was saved; Martyrdom of Imam Hussain (RA). Highly recommended fast.',
      isMajor: true,
    ),
    IslamicEvent(
      day: 12,
      month: 3,
      titleEn: 'Mawlid an-Nabi ﷺ',
      titleUr: '۱۲ ربیع الاول — میلاد النبی ﷺ',
      titleAr: 'المولد النبوي الشريف',
      description: 'Birth of Prophet Muhammad ﷺ, Mercy to the Worlds.',
      isMajor: true,
    ),
    IslamicEvent(
      day: 27,
      month: 7,
      titleEn: 'Al-Isra\' wal-Mi\'raj',
      titleUr: 'شب معراج (اسراء و معراج)',
      titleAr: 'الإسراء والمعراج',
      description: 'The Miraculous Night Journey and Heavenly Ascension of Prophet Muhammad ﷺ.',
      isMajor: true,
    ),
    IslamicEvent(
      day: 15,
      month: 8,
      titleEn: 'Shab-e-Bara\'at (Mid-Sha\'ban)',
      titleUr: 'شب برات (پندرہویں شعبان)',
      titleAr: 'ليلة النصف من شعبان',
      description: 'Night of records, forgiveness and supplications.',
    ),
    IslamicEvent(
      day: 1,
      month: 9,
      titleEn: '1st Ramadan (First Day of Fasting)',
      titleUr: 'یکم رمضان المبارک',
      titleAr: 'أول أيام رمضان المبارك',
      description: 'Start of the Blessed Month of Fasting, Taraweeh and Quran revelation.',
      isMajor: true,
    ),
    IslamicEvent(
      day: 17,
      month: 9,
      titleEn: 'Ghazwa-e-Badr (Battle of Badr)',
      titleUr: 'یوم بدر (۱۷ رمضان)',
      titleAr: 'غزوة بدر الكبرى',
      description: 'First decisive battle between Truth and Falsehood.',
    ),
    IslamicEvent(
      day: 20,
      month: 9,
      titleEn: 'Conquest of Makkah (Fath Makkah)',
      titleUr: 'فتح مکہ (۲۰ رمضان)',
      titleAr: 'فتح مكة',
      description: 'The peaceful and glorious entry of the Prophet ﷺ into Makkah.',
    ),
    IslamicEvent(
      day: 21,
      month: 9,
      titleEn: '1st Odd Night of Laylat al-Qadr (21st)',
      titleUr: 'پہلی طاق رات (۲۱ رمضان)',
      titleAr: 'ليلة القدر (٢١)',
      description: 'Search for the Night of Decree in the last ten odd nights.',
    ),
    IslamicEvent(
      day: 27,
      month: 9,
      titleEn: 'Laylat al-Qadr (Night of Power)',
      titleUr: 'شب قدر (۲۷ رمضان المبارک)',
      titleAr: 'ليلة القدر المباركة',
      description: 'A night better than a thousand months (Surah Al-Qadr).',
      isMajor: true,
    ),
    IslamicEvent(
      day: 1,
      month: 10,
      titleEn: 'Eid-ul-Fitr (1st Shawwal)',
      titleUr: 'عید الفطر المبارک',
      titleAr: 'عيد الفطر المبارك',
      description: 'Joyful celebration after completing the fasts of Ramadan.',
      isMajor: true,
    ),
    IslamicEvent(
      day: 1,
      month: 12,
      titleEn: '1st of Dhu al-Hijjah (Sacred 10 Days)',
      titleUr: 'یکم ذی الحجہ (پہلے دس مبارک دن)',
      titleAr: 'أول ذي الحجة',
      description: 'Start of the best 10 days of good deeds in the entire year.',
    ),
    IslamicEvent(
      day: 8,
      month: 12,
      titleEn: 'Day of Tarwiyah (Start of Hajj)',
      titleUr: 'یوم الترویہ (آغاز حج)',
      titleAr: 'يوم التروية',
      description: 'Pilgrims depart for Mina to begin Hajj rituals.',
    ),
    IslamicEvent(
      day: 9,
      month: 12,
      titleEn: 'Day of Arafah (Hajj Day & Sunnah Fast)',
      titleUr: 'یوم عرفہ (وقوف عرفات و روزہ)',
      titleAr: 'يوم عرفة',
      description: 'Pinnacle of Hajj. Fasting for non-pilgrims expiates sins of previous and coming year.',
      isMajor: true,
    ),
    IslamicEvent(
      day: 10,
      month: 12,
      titleEn: 'Eid-ul-Adha (Feast of Sacrifice)',
      titleUr: 'عید الاضحیٰ المبارک (قربانی کا دن)',
      titleAr: 'عيد الأضحى المبارك',
      description: 'Commemoration of Prophet Ibrahim (AS)\'s devotion; Qurbani.',
      isMajor: true,
    ),
    IslamicEvent(
      day: 11,
      month: 12,
      titleEn: 'Ayyam at-Tashriq (1st Day of Qurbani)',
      titleUr: 'ایام تشریق (۱۱ ذی الحجہ)',
      titleAr: 'أيام التشريق',
      description: 'Days of eating, drinking and remembering Allah (Takbeerat).',
    ),
  ];

  /// Initialize offset from SharedPreferences
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedOffset = prefs.getInt(_prefsOffsetKey) ?? 1; // Default +1 day for Pakistan
      _initialized = true;
    } catch (_) {
      _cachedOffset = 1;
    }
  }

  /// Sets custom Hijri offset (-2 to +2 days)
  static Future<void> setOffset(int offset) async {
    _cachedOffset = offset;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsOffsetKey, offset);
    } catch (_) {}
  }

  /// Gets current active offset
  static int get offset => _cachedOffset;

  /// Converts Gregorian date to HijriDate object with offset applied
  static HijriDate gregorianToHijri(DateTime date) {
    // Apply offset (e.g. +1 day for local moon sighting match)
    final adjustedDate = date.add(Duration(days: _cachedOffset));

    int day = adjustedDate.day;
    int month = adjustedDate.month;
    int year = adjustedDate.year;

    int m = month;
    int y = year;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }

    int a = (y / 100).floor();
    int b = 2 - a + (a / 4).floor();
    int jd = (365.25 * (y + 4716)).floor() + (30.6001 * (m + 1)).floor() + day + b - 1524;

    int z = jd - 1948440 + 10632;
    int n = ((z - 1) / 10631).floor();
    z = z - 10631 * n + 354;

    int j = ((10985 - z) / 5316).floor() * ((50 * z) / 17719).floor() +
        ((z / 5670).floor() * ((43 * z) / 15238).floor());
    z = z - ((30 - j) / 15).floor() * ((17719 * j) / 50).floor() -
        ((j / 15).floor() * ((15238 * j) / 43).floor()) + 29;

    int hMonth = ((24 * z) / 709).floor();
    int hDay = z - ((709 * hMonth) / 24).floor();
    int hYear = 30 * n + j - 30;

    return HijriDate(
      day: max(1, hDay),
      month: max(1, min(12, hMonth)),
      year: hYear,
      gregorianDate: date,
    );
  }

  /// Converts Hijri Year, Month, Day to approximate Gregorian Date
  static DateTime hijriToGregorian(int hYear, int hMonth, int hDay) {
    int n = ((11 * hYear + 3) / 30).floor() + 354 * hYear + 30 * hMonth - ((hMonth - 1) / 2).floor() + hDay + 1948440 - 385;
    int l = n + 68569;
    int q = ((4 * l) / 146097).floor();
    l = l - ((146097 * q + 3) / 4).floor();
    int i = ((4000 * (l + 1)) / 1461001).floor();
    l = l - ((1461 * i) / 4).floor() + 31;
    int j = ((80 * l) / 2447).floor();
    int day = l - ((2447 * j) / 80).floor();
    l = (j / 11).floor();
    int month = j + 2 - 12 * l;
    int year = 100 * (q - 49) + i + l;

    final base = DateTime(year, month, day);
    return base.subtract(Duration(days: _cachedOffset));
  }

  /// Returns today's Hijri Date string formatted, e.g. "19 Rabi' al-Awwal 1448 AH"
  static String formatHijriDate([DateTime? date]) {
    final target = date ?? DateTime.now();
    try {
      final hijri = gregorianToHijri(target);
      return hijri.formattedEn;
    } catch (_) {
      return '19 Rabi\' al-Awwal 1448 AH';
    }
  }

  /// Finds all events for a given Hijri day and month
  static List<IslamicEvent> getEventsForDate(int day, int month) {
    return allEvents.where((e) => e.day == day && e.month == month).toList();
  }

  /// Generates a complete month calendar matrix for the given Hijri Year & Month
  static List<HijriDate> generateMonthDays(int hYear, int hMonth) {
    final days = <HijriDate>[];
    // Find approximate starting gregorian date for day 1 of this hijri month
    final startGreg = hijriToGregorian(hYear, hMonth, 1);

    // Search around to find exact match for day 1
    DateTime cur = startGreg.subtract(const Duration(days: 3));
    while (true) {
      final h = gregorianToHijri(cur);
      if (h.year == hYear && h.month == hMonth && h.day == 1) {
        break;
      }
      cur = cur.add(const Duration(days: 1));
      if (cur.difference(startGreg).inDays > 10) break;
    }

    // Populate all days belonging to this hijri month (usually 29 or 30 days)
    while (true) {
      final h = gregorianToHijri(cur);
      if (h.year != hYear || h.month != hMonth) {
        break;
      }
      days.add(h);
      cur = cur.add(const Duration(days: 1));
      if (days.length > 30) break;
    }

    return days;
  }
}
