import 'package:flutter/material.dart';

import '../../core/prayer/hijri_service.dart';
import '../../core/prayer/prayer_tracker_service.dart';

class PrayerTrackerPage extends StatefulWidget {
  const PrayerTrackerPage({super.key});

  @override
  State<PrayerTrackerPage> createState() => _PrayerTrackerPageState();
}

class _PrayerTrackerPageState extends State<PrayerTrackerPage> {
  Map<String, PrayerStatus> _dailyStatuses = {};
  Map<String, dynamic> _weeklyStats = {
    'totalOffered': 0,
    'jamaatCount': 0,
    'individualCount': 0,
    'qazaCount': 0,
    'percentage': 0,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final statuses = await PrayerTrackerService.getDailyStatuses();
    final stats = await PrayerTrackerService.getWeeklyStats();

    if (mounted) {
      setState(() {
        _dailyStatuses = statuses;
        _weeklyStats = stats;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String prayer, PrayerStatus newStatus) async {
    final current = _dailyStatuses[prayer];
    final targetStatus = current == newStatus ? PrayerStatus.none : newStatus;

    await PrayerTrackerService.setStatus(prayer, targetStatus);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hijriDate = HijriService.formatHijriDate();
    final completedCount = _dailyStatuses.values.where((s) => s != PrayerStatus.none).length;
    final weeklyPercentage = _weeklyStats['percentage'] as int;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF059669), Colors.transparent]
                  : [const Color(0xFF059669).withValues(alpha: 0.2), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: const Text('Personal Prayer Tracker'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
          : Container(
              decoration: isDark
                  ? const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: 1.5,
                        colors: [Color(0xFF161B22), Color(0xFF0D1117)],
                      ),
                    )
                  : null,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ── Top Header Progress & Weekly Gauge Card ──
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161B22) : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Today\'s Namaz Log',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    hijriDate,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.secondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              // Circular Regularity Gauge
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 54,
                                    height: 54,
                                    child: CircularProgressIndicator(
                                      value: weeklyPercentage / 100,
                                      strokeWidth: 5,
                                      backgroundColor: theme.dividerColor,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  Text(
                                    '$weeklyPercentage%',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Progress Bar (Completed today: X / 5)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: completedCount / 5,
                              minHeight: 8,
                              backgroundColor: theme.dividerColor,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$completedCount of 5 Prayers Completed',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                completedCount == 5 ? '🎉 MashAllah! Full Today' : '${5 - completedCount} Remaining',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: completedCount == 5 ? const Color(0xFF10B981) : theme.colorScheme.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 5 Daily Prayer Cards ──
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Mark Your Prayers Today:',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),

                    ...PrayerTrackerService.prayersList.map((prayer) {
                      final status = _dailyStatuses[prayer] ?? PrayerStatus.none;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161B22) : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: status != PrayerStatus.none
                                ? const Color(0xFF10B981).withValues(alpha: 0.6)
                                : theme.dividerColor,
                            width: status != PrayerStatus.none ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Prayer Icon & Name
                            Icon(
                              _getPrayerIcon(prayer),
                              color: status != PrayerStatus.none ? const Color(0xFF10B981) : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              prayer,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),

                            // 3 Interactive Chips (Jama'at, Individual, Qaza)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildStatusChip(
                                  prayer: prayer,
                                  chipStatus: PrayerStatus.jamaat,
                                  currentStatus: status,
                                  label: 'Jama\'at',
                                  icon: Icons.mosque,
                                ),
                                const SizedBox(width: 4),
                                _buildStatusChip(
                                  prayer: prayer,
                                  chipStatus: PrayerStatus.individual,
                                  currentStatus: status,
                                  label: 'Alone',
                                  icon: Icons.person,
                                ),
                                const SizedBox(width: 4),
                                _buildStatusChip(
                                  prayer: prayer,
                                  chipStatus: PrayerStatus.qaza,
                                  currentStatus: status,
                                  label: 'Qaza',
                                  icon: Icons.access_time,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 20),

                    // ── Weekly Breakdown Stats ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161B22) : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '7-Day Breakdown:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem('🕌 Jama\'at', '${_weeklyStats["jamaatCount"]}', const Color(0xFF10B981)),
                              _buildStatItem('👤 Alone', '${_weeklyStats["individualCount"]}', theme.colorScheme.secondary),
                              _buildStatItem('⏰ Qaza', '${_weeklyStats["qazaCount"]}', Colors.orangeAccent),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusChip({
    required String prayer,
    required PrayerStatus chipStatus,
    required PrayerStatus currentStatus,
    required String label,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final isSelected = currentStatus == chipStatus;

    Color chipColor;
    if (chipStatus == PrayerStatus.jamaat) {
      chipColor = const Color(0xFF10B981);
    } else if (chipStatus == PrayerStatus.individual) {
      chipColor = theme.colorScheme.secondary;
    } else {
      chipColor = Colors.orangeAccent;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _updateStatus(prayer, chipStatus),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : chipColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: chipColor.withValues(alpha: isSelected ? 1 : 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isSelected ? Colors.white : chipColor),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : chipColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String count, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8)),
        ),
      ],
    );
  }

  IconData _getPrayerIcon(String prayer) {
    switch (prayer.toLowerCase()) {
      case 'fajr':
        return Icons.wb_twilight;
      case 'dhuhr':
        return Icons.wb_sunny;
      case 'asr':
        return Icons.sunny_snowing;
      case 'maghrib':
        return Icons.nightlight_round;
      case 'isha':
        return Icons.bedtime;
      default:
        return Icons.access_time;
    }
  }
}
