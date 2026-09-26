import 'package:flutter/material.dart';
import '../../app_scope.dart';
import '../../core/security/security_service.dart';
import '../../core/supabase/supabase_service.dart';

class JoinMosquePage extends StatefulWidget {
  const JoinMosquePage({super.key});

  @override
  State<JoinMosquePage> createState() => _JoinMosquePageState();
}

class _JoinMosquePageState extends State<JoinMosquePage> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  CloudMosque? _found;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _searchMosque() async {
    final code = _codeController.text.trim().toUpperCase();
    if (!SecurityService.isValidShareCode(code)) {
      setState(() => _errorMessage = 'Code 6 characters (A-Z, 0-9) ka hota hai');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _found = null;
    });

    final scope = AppScope.of(context);
    try {
      final mosque = await scope.supabaseService.fetchMosqueByCode(code);
      if (!mounted) return;
      setState(() {
        if (mosque != null) {
          _found = mosque;
        } else {
          _errorMessage = 'Is code ki koi masjid nahi mili';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = friendlyCloudError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinMosque() async {
    final found = _found;
    if (found == null) return;
    final scope = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isLoading = true);
    try {
      await scope.sync.downloadMosque(found);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('✅ "${found.name}" connected — live times aur announcements shuru.')),
      );
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Join nahi hua: ${friendlyCloudError(e)}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        title: const Text('Share Code se Join'),
      ),
      body: Container(
        decoration: isDark ? const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [Color(0xFF161B22), Color(0xFF0D1117)],
          ),
        ) : null,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter Share Code',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Imam se 6 characters ka share code lein aur yahan likhein.',
                style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                style: const TextStyle(fontSize: 20, letterSpacing: 4, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Mosque Code',
                  hintText: 'e.g. ABCDEF',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                  ),
                  errorText: _errorMessage,
                ),
                onChanged: (v) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isLoading ? null : _searchMosque,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Search Mosque', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              
              if (_found != null) ...[
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Mosque Found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.mosque, size: 36, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _found!.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Radius: ${_found!.radiusMeters}m',
                                    style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _joinMosque,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.all(16),
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(AppScope.of(context).sync.isDownloaded(_found!.id) ? 'Pehle se downloaded — dobara sync karein' : 'Download & Connect', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
