import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/firebase/auth_repository.dart';
import '../../data/i18n/ui_strings.dart';
import '../../services/haptics.dart';
import '../../state/providers.dart';
import '../../state/study_controller.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/common.dart';

/// Real sign-in: Google, Apple (required on iOS whenever another third-party
/// provider is offered) and email/password with a reset link.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, required this.onToast});
  final void Function(String message) onToast;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

enum _Mode { chooser, signUp, signIn }

class _AuthScreenState extends ConsumerState<AuthScreen> {
  _Mode _mode = _Mode.chooser;
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      // A successful sign-in pulls cloud progress before returning.
      await ref.read(studyProvider.notifier).pullAndMerge();
      if (mounted) Navigator.of(context).pop();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTokens tk = context.tokens;
    final UiStrings t = ref.watch(uiStringsProvider);
    final AuthRepository auth = ref.read(authRepositoryProvider);

    return Scaffold(
      backgroundColor: tk.paper,
      appBar: AppBar(
        backgroundColor: tk.paper,
        foregroundColor: tk.ink,
        elevation: 0,
        title: Text(
          t('Save your progress'),
          style: TextStyle(
              fontFamily: tk.fontHead, fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      body: ThemedBackground(
        child: SafeArea(
          child: PageBody(
            child: ListView(
              children: <Widget>[
                Text(
                  t('Create an account or log in so your progress and Pro plan live in your account — not just on this device.'),
                  style: TextStyle(fontSize: 13, height: 1.5, color: tk.muted),
                ),
                const SizedBox(height: 18),
                if (_busy)
                  Center(child: CircularProgressIndicator(color: tk.blue))
                else ...<Widget>[
                  _providerButton(
                    tk,
                    label: t('Continue with Google'),
                    leading: _googleGlyph(tk),
                    onTap: () => _run(auth.signInWithGoogle),
                  ),
                  if (Platform.isIOS || Platform.isMacOS) ...<Widget>[
                    const SizedBox(height: 10),
                    _providerButton(
                      tk,
                      label: t('Continue with Apple'),
                      leading: Text('',
                          style: TextStyle(fontSize: 20, color: tk.ink)),
                      onTap: () => _run(auth.signInWithApple),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(children: <Widget>[
                    Expanded(child: Divider(color: tk.line)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('or',
                          style: TextStyle(fontSize: 12, color: tk.muted)),
                    ),
                    Expanded(child: Divider(color: tk.line)),
                  ]),
                  const SizedBox(height: 16),
                  if (_mode == _Mode.chooser) ...<Widget>[
                    OutlineButton(
                      label: t('Sign up with email'),
                      onPressed: () => setState(() => _mode = _Mode.signUp),
                    ),
                    const SizedBox(height: 10),
                    OutlineButton(
                      label: t('I already have an account'),
                      onPressed: () => setState(() => _mode = _Mode.signIn),
                    ),
                  ] else
                    _emailForm(tk, t, auth),
                ],
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 14),
                  Text(_error!,
                      style: TextStyle(fontSize: 13, color: tk.red)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emailForm(AppTokens tk, UiStrings t, AuthRepository auth) {
    final bool signUp = _mode == _Mode.signUp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (signUp) ...<Widget>[
          _field(tk, _name, t('Your name'), TextInputType.name),
          const SizedBox(height: 10),
        ],
        _field(tk, _email, t('Email address'), TextInputType.emailAddress),
        const SizedBox(height: 10),
        _field(tk, _password, t('Password'), TextInputType.visiblePassword,
            obscure: true),
        const SizedBox(height: 14),
        GenButton(
          label: signUp ? t('Create account') : t('Log in'),
          alt: true,
          onPressed: () => _run(() async {
            if (signUp) {
              await auth.signUpWithEmail(
                email: _email.text,
                password: _password.text,
                displayName: _name.text,
              );
            } else {
              await auth.signInWithEmail(
                email: _email.text,
                password: _password.text,
              );
            }
          }),
        ),
        const SizedBox(height: 10),
        if (!signUp)
          TextButton(
            onPressed: () async {
              Haptics.tap();
              if (_email.text.trim().isEmpty) {
                setState(() => _error = t('Enter your email address first.'));
                return;
              }
              try {
                await auth.sendPasswordReset(_email.text);
                widget.onToast(t('Password reset email sent.'));
              } on AuthFailure catch (e) {
                setState(() => _error = e.message);
              }
            },
            child: Text(t('Forgot your password?'),
                style: TextStyle(fontSize: 13, color: tk.blue)),
          ),
        TextButton(
          onPressed: () => setState(() {
            _mode = signUp ? _Mode.signIn : _Mode.signUp;
            _error = null;
          }),
          child: Text(
            signUp ? t('I already have an account') : t('Sign up with email'),
            style: TextStyle(fontSize: 13, color: tk.muted),
          ),
        ),
      ],
    );
  }

  Widget _field(
    AppTokens tk,
    TextEditingController c,
    String hint,
    TextInputType type, {
    bool obscure = false,
  }) {
    return TextField(
      controller: c,
      keyboardType: type,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: !obscure,
      style: TextStyle(fontSize: 15, color: tk.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: tk.muted2),
        filled: true,
        fillColor: tk.cardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: tk.cardRadius,
          borderSide: BorderSide(color: tk.line, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: tk.cardRadius,
          borderSide: BorderSide(color: tk.line, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: tk.cardRadius,
          borderSide: BorderSide(color: tk.accent, width: 2),
        ),
      ),
    );
  }

  Widget _providerButton(
    AppTokens tk, {
    required String label,
    required Widget leading,
    required VoidCallback onTap,
  }) {
    return Material(
      color: tk.cardBg,
      borderRadius: tk.cardRadius,
      child: InkWell(
        borderRadius: tk.cardRadius,
        onTap: () {
          Haptics.tap();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(color: tk.line, width: 2),
            borderRadius: tk.cardRadius,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              leading,
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                    fontFamily: tk.fontHead,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: tk.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _googleGlyph(AppTokens tk) => Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: tk.line),
        ),
        child: const Text(
          'G',
          style: TextStyle(
            fontFamily: 'Arial',
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: Color(0xFF4285F4),
          ),
        ),
      );
}
