import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_config.dart';

/// Approval state of an Imam account.
enum ImamStatus { none, pending, approved, rejected }

/// Result of a sign-up attempt.
enum SignUpResult { signedIn, confirmEmail }

/// Supabase Auth for Imam / committee accounts. Namazi users never log in.
class AuthService extends ChangeNotifier {
  SupabaseClient get _client => Supabase.instance.client;

  ImamStatus _status = ImamStatus.none;
  String? _fullName;

  ImamStatus get status => _status;
  String? get fullName => _fullName;

  User? get currentUser {
    try {
      return _client.auth.currentUser;
    } catch (_) {
      return null; // Supabase not initialised (e.g. widget tests)
    }
  }

  bool get isSignedIn => currentUser != null;
  bool get isApprovedImam => _status == ImamStatus.approved;
  String? get email => currentUser?.email;

  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    final res = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim(), 'phone': phone?.trim()},
    );
    if (res.session == null) {
      // Email confirmation is enabled on the project.
      return SignUpResult.confirmEmail;
    }
    await _ensureProfile(fullName: fullName, phone: phone);
    await refreshStatus();
    return SignUpResult.signedIn;
  }

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email.trim(), password: password);
    await refreshStatus(createIfMissing: true);
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
    _status = ImamStatus.none;
    _fullName = null;
    notifyListeners();
  }

  /// Reads this user's imam_profiles row. If [createIfMissing] and the user
  /// has no row yet (first login after confirming email), an access request
  /// is created from the sign-up metadata.
  Future<ImamStatus> refreshStatus({bool createIfMissing = false}) async {
    final user = currentUser;
    if (user == null) {
      _status = ImamStatus.none;
      notifyListeners();
      return _status;
    }
    try {
      var row = await _client
          .from(SupabaseConfig.imamProfilesTable)
          .select('full_name, status')
          .eq('user_id', user.id)
          .maybeSingle();

      if (row == null && createIfMissing) {
        final meta = user.userMetadata ?? const {};
        final name = (meta['full_name'] as String?)?.trim();
        await _ensureProfile(
          fullName: (name == null || name.isEmpty) ? (user.email ?? 'Imam') : name,
          phone: meta['phone'] as String?,
        );
        row = await _client
            .from(SupabaseConfig.imamProfilesTable)
            .select('full_name, status')
            .eq('user_id', user.id)
            .maybeSingle();
      }

      _fullName = row?['full_name'] as String?;
      _status = switch (row?['status']) {
        'approved' => ImamStatus.approved,
        'pending' => ImamStatus.pending,
        'rejected' => ImamStatus.rejected,
        _ => ImamStatus.none,
      };
    } catch (e) {
      debugPrint('refreshStatus failed: $e');
    }
    notifyListeners();
    return _status;
  }

  Future<void> _ensureProfile({required String fullName, String? phone}) async {
    await _client.rpc('request_imam_access', params: {
      'p_full_name': fullName,
      'p_phone': phone,
    });
  }
}
