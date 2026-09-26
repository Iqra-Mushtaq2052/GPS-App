import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/auth/auth_service.dart';
import '../../core/supabase/supabase_service.dart';

/// Login / sign-up for Imam and committee accounts.
/// Pops `true` once the user is signed in.
class ImamAuthPage extends StatefulWidget {
  const ImamAuthPage({super.key});

  @override
  State<ImamAuthPage> createState() => _ImamAuthPageState();
}

class _ImamAuthPageState extends State<ImamAuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  bool _isSignUp = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final scope = AppScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      if (_isSignUp) {
        final result = await scope.auth.signUp(
          email: _email.text,
          password: _password.text,
          fullName: _name.text,
          phone: _phone.text,
        );
        if (result == SignUpResult.confirmEmail) {
          if (!mounted) return;
          setState(() {
            _isSignUp = false;
            _info = 'Account ban gaya! Apni email (${_email.text.trim()}) mein aaya '
                'confirmation link kholein, phir yahan login karein.';
          });
          return;
        }
      } else {
        await scope.auth.signIn(email: _email.text, password: _password.text);
      }
      try {
        await scope.sync.refreshManaged();
      } catch (_) {}
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyCloudError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    InputDecoration deco(String label, IconData icon) => InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(_isSignUp ? 'Imam / Committee — Sign up' : 'Imam / Committee — Login')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.mosque_rounded, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  _isSignUp
                      ? 'Naya account banayein. Imam ke liye admin approval zaroori hai; '
                          'committee member ko Imam apni masjid mein add karega.'
                      : 'Apne Imam / Committee account se login karein.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 24),
                if (_isSignUp) ...[
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: deco('Poora naam', Icons.person),
                    validator: (v) => (v == null || v.trim().length < 3) ? 'Naam likhein' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: deco('Phone number (admin verification ke liye)', Icons.phone),
                    validator: (v) =>
                        (v == null || v.replaceAll(RegExp(r'\D'), '').length < 10) ? 'Sahi number likhein' : null,
                  ),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: deco('Email', Icons.email),
                  validator: (v) => (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()))
                      ? 'Sahi email likhein'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: deco('Password', Icons.lock).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Kam az kam 6 characters' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _Banner(text: _error!, color: Colors.redAccent, icon: Icons.error_outline),
                ],
                if (_info != null) ...[
                  const SizedBox(height: 14),
                  _Banner(text: _info!, color: theme.colorScheme.primary, icon: Icons.mark_email_read),
                ],
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isSignUp ? 'Account banayein' : 'Login'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _isSignUp = !_isSignUp;
                            _error = null;
                          }),
                  child: Text(_isSignUp ? 'Pehle se account hai? Login karein' : 'Naya account? Sign up karein'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color, required this.icon});
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }
}
