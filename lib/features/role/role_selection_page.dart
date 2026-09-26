import 'package:flutter/material.dart';
import '../../app_scope.dart';
import '../../core/role/role_service.dart';
import '../auth/imam_auth_page.dart';
import '../home/home_page.dart';
import '../onboarding/permission_onboarding_page.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  bool _busy = false;

  Future<void> _selectRole(AppRole role) async {
    if (_busy) return;
    final scope = AppScope.of(context);

    if (role == AppRole.imam) {
      // Imam / committee must sign in first (approval is checked by server).
      if (!scope.auth.isSignedIn) {
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const ImamAuthPage()),
        );
        if (ok != true) return;
      }
    } else if (scope.auth.isSignedIn) {
      // Switching back to Namazi: sign out of the management account.
      await scope.auth.signOut();
      scope.sync.clearManaged();
    }
    if (!mounted) return;

    setState(() => _busy = true);
    await scope.roleService.setRole(role);
    final foreground = await scope.permissions.hasForegroundLocation();
    final background = await scope.permissions.hasBackgroundLocation();
    if (!mounted) return;
    setState(() => _busy = false);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => (foreground && background)
            ? const HomePage()
            : const PermissionOnboardingPage(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF059669), Color(0xFF0D1117)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.mosque_rounded,
                  size: 64,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Masjid GPS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aap kaun hain? Apna role chunein',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 48),
                _RoleCard(
                  title: 'Imam / Committee',
                  subtitle: 'Account se login karein. Admin approval ke baad masjid register karein, jamaat times aur announcements update karein.',
                  icon: Icons.mosque_rounded,
                  onTap: () => _selectRole(AppRole.imam),
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  title: 'Namazi (User)',
                  subtitle: 'Login ki zaroorat nahi. Masjid Store se qareeb ki masjidein download karein — live times, announcements aur auto-vibrate.',
                  icon: Icons.person_rounded,
                  onTap: () => _selectRole(AppRole.user),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
