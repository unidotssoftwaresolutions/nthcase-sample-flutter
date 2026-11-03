import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../ids.dart';
import '../art.dart';
import '../components.dart';
import '../theme.dart';

const signInWrong = 'Wrong email or password';
const signInMissing = 'Enter your email and password';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _email.text;
    final password = _password.text;
    setState(() {
      _error = email.trim().isEmpty || password.isEmpty
          ? signInMissing
          : !AppState.credentialsMatch(email, password)
          ? signInWrong
          : null;
    });
    if (_error == null) AppScope.read(context).notifier!.signIn(email);
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: Id(
        TestIds.signinScreen,
        region: true,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ArtIcon(Art.shop, size: 48, color: scheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Semantics(header: true, child: Text('Mossgrove', style: theme.textTheme.displaySmall)),
                    Text(
                      'Home and desk goods',
                      style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    Id(
                      TestIds.signinEmail,
                      child: TextField(
                        controller: _email,
                        onChanged: (_) => _clearError(),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          error: _error == null ? null : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Id(
                      TestIds.signinPassword,
                      child: TextField(
                        controller: _password,
                        onChanged: (_) => _clearError(),
                        obscureText: !_showPassword,
                        enableSuggestions: false,
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          error: _error == null ? null : const SizedBox.shrink(),
                          suffixIcon: IdControl(
                            TestIds.signinPasswordToggle,
                            child: IconButton(
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                              icon: ArtIcon(
                                _showPassword ? Art.eyeOff : Art.eye,
                                label: _showPassword ? 'Hide password' : 'Show password',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ArtIcon(Art.warning, size: 18, color: scheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Id(
                              TestIds.signinError,
                              child: Semantics(
                                liveRegion: true,
                                child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: IdControl(
                        TestIds.signinSubmit,
                        child: FilledButton(onPressed: _submit, child: const Text('Sign in')),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Id(
                      TestIds.signinTestAccount,
                      // a plain box, not a Material Card, whose own semantics level would leave the id's node empty
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: radiusDrawer,
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Test account', style: theme.textTheme.titleSmall),
                              const SizedBox(height: 4),
                              Text(
                                'This is a sample app. Sign in with:',
                                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 4),
                              Text(AppState.testEmail, style: itemNumberStyle.copyWith(color: scheme.onSurface)),
                              Text(AppState.testPassword, style: itemNumberStyle.copyWith(color: scheme.onSurface)),
                              IdControl(
                                TestIds.signinUseTestAccount,
                                child: TextButton(
                                  onPressed: () {
                                    _email.text = AppState.testEmail;
                                    _password.text = AppState.testPassword;
                                    _clearError();
                                  },
                                  child: const Text('Use test account'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
