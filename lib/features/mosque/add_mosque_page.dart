import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../app_scope.dart';
import '../../core/auth/auth_service.dart';
import '../../core/supabase/supabase_service.dart';

class AddMosquePage extends StatefulWidget {
  const AddMosquePage({super.key});

  @override
  State<AddMosquePage> createState() => _AddMosquePageState();
}

class _AddMosquePageState extends State<AddMosquePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  double _radius = 40;
  Position? _capturedPosition;
  bool _isCapturing = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifyImamRole());
  }

  /// Only an admin-approved imam (signed in) may register a mosque.
  /// The server enforces this again inside register_mosque().
  Future<void> _verifyImamRole() async {
    final scope = AppScope.of(context);
    final status = await scope.auth.refreshStatus();
    if (!mounted) return;
    if (!scope.auth.isSignedIn || status != ImamStatus.approved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !scope.auth.isSignedIn
                ? 'Masjid sirf Imam account se register hoti hai. Pehle login karein.'
                : 'Aap ka Imam account abhi admin se approve nahi hua. Approval ke baad masjid register kar sakenge.',
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() {
      _isCapturing = true;
      _error = null;
    });
    final scope = AppScope.of(context);
    try {
      if (!await scope.location.isLocationServiceEnabled()) {
        setState(() => _error = 'GPS is off — please turn it on first.');
        return;
      }
      var permission = await scope.location.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await scope.location.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _error = 'Location permission required.');
        return;
      }
      final position = await scope.location.getCurrentPosition();
      setState(() => _capturedPosition = position);
    } catch (e) {
      setState(() => _error = 'Could not capture location: $e');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_capturedPosition == null) {
      setState(() => _error = 'Pehle masjid ke andar khade ho kar location capture karein.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final scope = AppScope.of(context);
    try {
      final cloud = await scope.supabaseService.registerMosque(
        name: _nameController.text.trim(),
        latitude: _capturedPosition!.latitude,
        longitude: _capturedPosition!.longitude,
        radiusMeters: _radius.round(),
        address: _addressController.text.trim(),
      );

      // Imam's phone also gets the mosque (live view + auto-vibrate).
      await scope.mosqueRepository.upsertCloud(
        supabaseId: cloud.id,
        name: cloud.name,
        latitude: cloud.latitude,
        longitude: cloud.longitude,
        radiusMeters: cloud.radiusMeters,
        shareCode: cloud.shareCode,
      );
      await scope.sync.onLocalMosquesChanged?.call();
      try {
        await scope.sync.refreshManaged();
      } catch (_) {}

      if (!mounted) return;
      final code = cloud.shareCode;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
                SizedBox(width: 10),
                Expanded(child: Text('Masjid register ho gayi!')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ab ye masjid 10 km tak ke namaziyon ko Masjid Store mein nazar aayegi. '
                  'Share code bhi de sakte hain:',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.secondary),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          code,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Code copy ho gaya!')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Agla qadam: jamaat times set karein.', style: TextStyle(fontSize: 13)),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Done'),
              ),
            ],
          );
        },
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyCloudError(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final captured = _capturedPosition != null;

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
        title: const Text('Masjid Register Karein'),
      ),
      body: Container(
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
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Mosque Name ──
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Mosque Name',
                    labelStyle: TextStyle(color: theme.colorScheme.primary),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0D1117) : theme.scaffoldBackgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                    ),
                    prefixIcon: Icon(Icons.mosque, color: theme.colorScheme.secondary),
                  ),
                  validator: (v) => (v == null || v.trim().length < 3) ? 'Masjid ka naam likhein' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressController,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Address / Muhalla (optional)',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0D1117) : theme.scaffoldBackgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Icon(Icons.place_outlined, color: theme.colorScheme.secondary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Location capture karte waqt masjid ke andar (hall ke beech) khade hon.',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 14),

                // ── Capture Location ──
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _isCapturing ? null : _captureLocation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: isDark ? const Color(0xFF161B22) : theme.colorScheme.surface,
                      border: Border.all(
                        color: captured ? theme.colorScheme.primary : theme.dividerColor,
                        width: captured ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _isCapturing
                            ? SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : Icon(
                                captured ? Icons.check_circle : Icons.my_location,
                                size: 44,
                                color: captured ? theme.colorScheme.primary : Colors.grey,
                              ),
                        const SizedBox(height: 10),
                        Text(
                          captured ? 'Location Captured ✓' : 'Tap to Capture Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: captured ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                          ),
                        ),
                        if (captured) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${_capturedPosition!.latitude.toStringAsFixed(5)}, ${_capturedPosition!.longitude.toStringAsFixed(5)}',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Geofence Radius ──
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Geofence Radius',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_radius.round()}m',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: theme.colorScheme.primary,
                    inactiveTrackColor: theme.dividerColor,
                    thumbColor: theme.colorScheme.secondary,
                    overlayColor: theme.colorScheme.secondary.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _radius,
                    min: 20,
                    max: 60,
                    divisions: 40,
                    label: '${_radius.round()}m',
                    onChanged: (v) => setState(() => _radius = v),
                  ),
                ),

                // ── Error ──
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // ── Save Button ──
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    _isSaving ? 'Register ho rahi hai...' : 'Masjid Register Karein',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
