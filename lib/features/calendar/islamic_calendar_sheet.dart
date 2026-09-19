import 'package:flutter/material.dart';
import '../../core/prayer/hijri_service.dart';

class IslamicCalendarSheet extends StatefulWidget {
  const IslamicCalendarSheet({super.key});

  @override
  State<IslamicCalendarSheet> createState() => _IslamicCalendarSheetState();
}

class _IslamicCalendarSheetState extends State<IslamicCalendarSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _currentHijriMonth;
  late int _currentHijriYear;
  late HijriDate _todayHijri;
  HijriDate? _selectedHijriDate;
  int _activeOffset = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _activeOffset = HijriService.offset;
    _todayHijri = HijriService.gregorianToHijri(DateTime.now());
    _currentHijriMonth = _todayHijri.month;
    _currentHijriYear = _todayHijri.year;
    _selectedHijriDate = _todayHijri;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _changeMonth(int delta) {
    setState(() {
      int newMonth = _currentHijriMonth + delta;
      int newYear = _currentHijriYear;

      if (newMonth > 12) {
        newMonth = 1;
        newYear += 1;
      } else if (newMonth < 1) {
        newMonth = 12;
        newYear -= 1;
      }

      _currentHijriMonth = newMonth;
      _currentHijriYear = newYear;

      if (newMonth == _todayHijri.month && newYear == _todayHijri.year) {
        _selectedHijriDate = _todayHijri;
      } else {
        final days = HijriService.generateMonthDays(_currentHijriYear, _currentHijriMonth);
        if (days.isNotEmpty) {
          _selectedHijriDate = days.first;
        }
      }
    });
  }

  void _jumpToToday() {
    setState(() {
      _todayHijri = HijriService.gregorianToHijri(DateTime.now());
      _currentHijriMonth = _todayHijri.month;
      _currentHijriYear = _todayHijri.year;
      _selectedHijriDate = _todayHijri;
    });
  }

  Future<void> _updateOffset(int offset) async {
    await HijriService.setOffset(offset);
    setState(() {
      _activeOffset = offset;
      _todayHijri = HijriService.gregorianToHijri(DateTime.now());
      _currentHijriMonth = _todayHijri.month;
      _currentHijriYear = _todayHijri.year;
      _selectedHijriDate = _todayHijri;
    });
  }

  void _showMoonOffsetDialog(BuildContext context, ThemeData theme, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161B22) : theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.nightlight_round, color: Color(0xFFF59E0B), size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Moon Sighting (رویت ہلال)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adjust Hijri day offset to match local moon sighting in Pakistan or your country.',
              style: TextStyle(
                fontSize: 12.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [-2, -1, 0, 1, 2].map((off) {
                final isSelected = off == _activeOffset;
                final label = off > 0 ? '+$off' : '$off';
                return InkWell(
                  onTap: () {
                    _updateOffset(off);
                    Navigator.of(ctx).pop();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 44,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF10B981) : theme.dividerColor,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle Bar
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Top Clean App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mosque, color: Color(0xFF10B981), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Islamic Calendar',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Moon Sighting Adjuster Button
                  InkWell(
                    onTap: () => _showMoonOffsetDialog(context, theme, isDark),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune, size: 14, color: theme.colorScheme.secondary),
                          const SizedBox(width: 4),
                          Text(
                            _activeOffset >= 0 ? '+$_activeOffset d' : '$_activeOffset d',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Clean Segmented Tab Switcher
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.dividerColor),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: '📅 Monthly Calendar'),
                  Tab(text: '⭐ Islamic Events'),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMonthlyCalendarTab(theme, isDark),
                  _buildIslamicEventsTab(theme, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyCalendarTab(ThemeData theme, bool isDark) {
    final monthDays = HijriService.generateMonthDays(_currentHijriYear, _currentHijriMonth);
    int firstWeekday = 1;
    if (monthDays.isNotEmpty) {
      firstWeekday = monthDays.first.gregorianDate.weekday;
    }

    final monthNameEn = HijriService.monthNamesEn[_currentHijriMonth - 1];
    final monthNameAr = HijriService.monthNamesAr[_currentHijriMonth - 1];
    final monthNameUr = HijriService.monthNamesUr[_currentHijriMonth - 1];
    final isSacred = _currentHijriMonth == 1 || _currentHijriMonth == 7 || _currentHijriMonth == 11 || _currentHijriMonth == 12;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Clean Month Navigation Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF0D1117) : theme.scaffoldBackgroundColor,
                      padding: const EdgeInsets.all(8),
                    ),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 14),
                    onPressed: () => _changeMonth(-1),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          monthNameAr,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF59E0B),
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '$monthNameEn $_currentHijriYear AH • $monthNameUr',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF0D1117) : theme.scaffoldBackgroundColor,
                      padding: const EdgeInsets.all(8),
                    ),
                    icon: const Icon(Icons.arrow_forward_ios, size: 14),
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (isSacred)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                      ),
                      child: const Text(
                        '⭐ Sacred Month (شہر حرام)',
                        style: TextStyle(color: Color(0xFFF59E0B), fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  InkWell(
                    onTap: _jumpToToday,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'Jump to Today (آج)',
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Clean Weekdays Bar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              _WeekdayLabel('Mon'),
              _WeekdayLabel('Tue'),
              _WeekdayLabel('Wed'),
              _WeekdayLabel('Thu'),
              _WeekdayLabel('Fri', isJummah: true),
              _WeekdayLabel('Sat'),
              _WeekdayLabel('Sun'),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Clean Calendar Grid
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.dividerColor),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 0.92,
            ),
            itemCount: (firstWeekday - 1) + monthDays.length,
            itemBuilder: (context, index) {
              if (index < firstWeekday - 1) {
                return const SizedBox.shrink();
              }

              final dayObj = monthDays[index - (firstWeekday - 1)];
              final isToday = dayObj.day == _todayHijri.day &&
                  dayObj.month == _todayHijri.month &&
                  dayObj.year == _todayHijri.year;
              final isSelected = _selectedHijriDate != null &&
                  dayObj.day == _selectedHijriDate!.day &&
                  dayObj.month == _selectedHijriDate!.month &&
                  dayObj.year == _selectedHijriDate!.year;
              final hasEvents = dayObj.events.isNotEmpty;
              final isWhiteDay = dayObj.isWhiteDay;
              final isFriday = dayObj.gregorianDate.weekday == DateTime.friday;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedHijriDate = dayObj;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF10B981)
                        : (isToday
                            ? const Color(0xFF10B981).withValues(alpha: 0.2)
                            : (isDark ? const Color(0xFF0D1117) : theme.scaffoldBackgroundColor)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF10B981)
                          : (isToday
                              ? const Color(0xFF10B981)
                              : (hasEvents ? const Color(0xFFF59E0B) : Colors.transparent)),
                      width: isSelected || isToday ? 2 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Center: Hijri Day Number + Gregorian Day
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${dayObj.day}',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : (isFriday
                                        ? const Color(0xFF10B981)
                                        : (hasEvents
                                            ? const Color(0xFFF59E0B)
                                            : theme.colorScheme.onSurface)),
                              ),
                            ),
                            Text(
                              '${dayObj.gregorianDate.day}',
                              style: TextStyle(
                                fontSize: 8.5,
                                color: isSelected
                                    ? Colors.white70
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Top indicator dots
                      if (hasEvents)
                        Positioned(
                          top: 3,
                          right: 3,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : const Color(0xFFF59E0B),
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      else if (isWhiteDay)
                        Positioned(
                          top: 3,
                          right: 3,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white70 : const Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // Selected Day Details Card (Fully Flexible & Overflow-Proof)
        if (_selectedHijriDate != null)
          _buildSelectedDayCard(theme, isDark, _selectedHijriDate!),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSelectedDayCard(ThemeData theme, bool isDark, HijriDate date) {
    final events = date.events;
    final isJummah = date.gregorianDate.weekday == DateTime.friday;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  date.formattedAr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_getDayName(date.gregorianDate.weekday)}, ${date.gregorianDate.day} ${_getMonthLong(date.gregorianDate.month)}',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${date.formattedEn} (${date.formattedUr})',
            style: TextStyle(
              fontSize: 11.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 6),

          // Badges Row
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (isJummah)
                _buildTag('🕌 Jummah Mubarak', const Color(0xFF10B981)),
              if (date.isWhiteDay)
                _buildTag('🌙 Ayyam al-Beed (White Day)', const Color(0xFFF59E0B)),
              if (date.isSacredMonth)
                _buildTag('🛡️ Sacred Month', const Color(0xFFD97706)),
            ],
          ),

          // Events on this Day
          if (events.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...events.map((ev) => Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Color(0xFFF59E0B), size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${ev.titleEn} (${ev.titleUr})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildIslamicEventsTab(ThemeData theme, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: HijriService.allEvents.length,
      itemBuilder: (context, index) {
        final ev = HijriService.allEvents[index];
        final isCurrentMonth = ev.month == _currentHijriMonth;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCurrentMonth ? const Color(0xFF10B981) : theme.dividerColor,
              width: isCurrentMonth ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isCurrentMonth
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : theme.colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${ev.day}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isCurrentMonth ? const Color(0xFF10B981) : theme.colorScheme.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ev.titleEn,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isCurrentMonth ? const Color(0xFF10B981) : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ev.titleUr} • ${HijriService.monthNamesEn[ev.month - 1]}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  static String _getMonthLong(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  static String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;
  final bool isJummah;
  const _WeekdayLabel(this.label, {this.isJummah = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isJummah ? const Color(0xFF10B981) : Colors.grey,
          ),
        ),
      ),
    );
  }
}
