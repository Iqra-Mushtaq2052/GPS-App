import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' as drift;
import '../../app_scope.dart';
import 'mosque_detail_page.dart' show formatDateTime;
import '../../core/supabase/supabase_service.dart';
import '../../data/db/app_database.dart';

class ImamPrayerTimesPage extends StatefulWidget {
  final int mosqueId;
  final String mosqueName;
  final String shareCode;
  final String cloudMosqueId;

  const ImamPrayerTimesPage({
    super.key,
    required this.mosqueId,
    required this.mosqueName,
    required this.shareCode,
    required this.cloudMosqueId,
  });

  @override
  State<ImamPrayerTimesPage> createState() => _ImamPrayerTimesPageState();
}

class _ImamPrayerTimesPageState extends State<ImamPrayerTimesPage> {
  String _fajr = '05:00';
  String _dhuhr = '13:00';
  String _asr = '17:00';
  String _maghrib = '18:30';
  String _isha = '20:00';
  String? _jumuah;

  bool _isLoading = true;
  bool _isSaving = false;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    // AppScope must not be read synchronously in initState.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrayerTimes());
  }

  void _apply(CloudPrayerTimes t) {
    _fajr = t.fajr;
    _dhuhr = t.dhuhr;
    _asr = t.asr;
    _maghrib = t.maghrib;
    _isha = t.isha;
    _jumuah = (t.jumuah == null || t.jumuah!.isEmpty) ? null : t.jumuah;
    _lastUpdated = t.updatedAt;
  }

  Future<void> _loadPrayerTimes() async {
    if (!mounted) return;
    final scope = AppScope.of(context);
    final cached = scope.sync.timesFor(widget.cloudMosqueId);
    if (cached != null) setState(() => _apply(cached));
    try {
      final fresh = await scope.supabaseService.fetchPrayerTimes(widget.cloudMosqueId);
      if (fresh != null && mounted) setState(() => _apply(fresh));
    } catch (_) {
      // Offline — keep cached values.
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _savePrayerTimes() async {
    setState(() => _isSaving = true);
    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await scope.supabaseService.updatePrayerTimes(
        cloudMosqueId: widget.cloudMosqueId,
        fajr: _fajr,
        dhuhr: _dhuhr,
        asr: _asr,
        maghrib: _maghrib,
        isha: _isha,
        jumuah: _jumuah,
      );

      // Local copy (kept for offline use by the imam's own phone).
      await scope.database.localPrayerTimesDao.upsert(
        LocalPrayerTimesCompanion(
          mosqueId: drift.Value(widget.mosqueId),
          fajr: drift.Value(_fajr),
          dhuhr: drift.Value(_dhuhr),
          asr: drift.Value(_asr),
          maghrib: drift.Value(_maghrib),
          isha: drift.Value(_isha),
          cloudMosqueId: drift.Value(widget.cloudMosqueId),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );
      await scope.sync.refresh();

      if (mounted) {
        setState(() => _lastUpdated = DateTime.now());
        messenger.showSnackBar(
          const SnackBar(content: Text('Jamaat times update ho gaye — sab namaziyon ko live pohnch gaye.')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Update nahi hua: ${friendlyCloudError(e)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickTime(String current, Function(String) onSelected) async {
    final parts = current.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 12,
      minute: int.tryParse(parts[1]) ?? 0,
    );

    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (time != null) {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      setState(() {
        onSelected('$h:$m');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
        title: Text(widget.mosqueName),
      ),
      body: Container(
        decoration: isDark ? const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [Color(0xFF161B22), Color(0xFF0D1117)],
          ),
        ) : null,
        child: _isLoading 
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Card(
                  color: theme.colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.key, color: theme.colorScheme.secondary, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Share Code',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                              Text(
                                widget.shareCode,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.copy, color: theme.colorScheme.onSecondaryContainer),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: widget.shareCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Share code copied to clipboard')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Prayer Times',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _TimePickerTile(
                  name: 'Fajr',
                  time: _fajr,
                  onTap: () => _pickTime(_fajr, (t) => _fajr = t),
                ),
                _TimePickerTile(
                  name: 'Dhuhr',
                  time: _dhuhr,
                  onTap: () => _pickTime(_dhuhr, (t) => _dhuhr = t),
                ),
                _TimePickerTile(
                  name: 'Asr',
                  time: _asr,
                  onTap: () => _pickTime(_asr, (t) => _asr = t),
                ),
                _TimePickerTile(
                  name: 'Maghrib',
                  time: _maghrib,
                  onTap: () => _pickTime(_maghrib, (t) => _maghrib = t),
                ),
                _TimePickerTile(
                  name: 'Isha',
                  time: _isha,
                  onTap: () => _pickTime(_isha, (t) => _isha = t),
                ),
                _TimePickerTile(
                  name: 'Jumuah (optional)',
                  time: _jumuah ?? '--:--',
                  onTap: () => _pickTime(_jumuah ?? '13:30', (t) => _jumuah = t),
                  onClear: _jumuah == null ? null : () => setState(() => _jumuah = null),
                ),
                const SizedBox(height: 32),
                if (_lastUpdated != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Last updated: ${formatDateTime(_lastUpdated!)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _savePrayerTimes,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Update Prayer Times', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  final String name;
  final String time;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _TimePickerTile({
    required this.name,
    required this.time,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: onClear == null
            ? null
            : IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: onClear),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            time,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
