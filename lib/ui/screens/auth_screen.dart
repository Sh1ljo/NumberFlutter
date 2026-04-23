import 'dart:async';

import 'package:flutter/material.dart';

import '../../logic/supabase_service.dart';
import '../../utils/network_error_utils.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isBusy = false;
  bool _isSignUp = false;
  String? _errorMessage;
  StreamSubscription<dynamic>? _authSub;

  @override
  void initState() {
    super.initState();
    final service = SupabaseService.instance;
    if (!service.isInitialized) return;
    _authSub = service.authStateChanges().listen((data) {
      final session = data.session;
      if (session != null && mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final service = SupabaseService.instance;
      if (_isSignUp) {
        final response = await service.signUpWithEmailPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        // Supabase returns a user but null session when email confirmation is required.
        if (response.session == null && mounted) {
          setState(() {
            _errorMessage =
                'Account created. If a confirmation email does not arrive within a few minutes, '
                'disable "Confirm email" in Supabase → Authentication → Providers → Email, '
                'or configure a custom SMTP provider. Then sign in here.';
          });
        }
      } else {
        await service.signInWithEmailPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = cloudErrorMessage(
          error,
          offlineMessage:
              'No internet connection. Please reconnect and try again.',
          fallbackMessage: 'Authentication failed. Please try again.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _oauthSignIn(Future<void> Function() action) async {
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = cloudErrorMessage(
          error,
          offlineMessage:
              'No internet connection. Please reconnect and try again.',
          fallbackMessage: 'Could not complete sign in. Please try again.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configured = SupabaseService.instance.isConfigured;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'CLOUD ACCOUNT',
                    style: theme.textTheme.displayLarge?.copyWith(fontSize: 44),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Optional: sign in to sync progress and use the leaderboard. Local play works without an account.',
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 24),
                  if (!configured)
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: theme.colorScheme.errorContainer,
                      child: Text(
                        'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY in assets/.env (or use --dart-define).',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  if (!configured) const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty || !email.contains('@')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Password'),
                          validator: (value) {
                            if ((value ?? '').length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isBusy || !configured ? null : _submitEmailAuth,
                    child: Text(_isSignUp ? 'Create account' : 'Sign in'),
                  ),
                  TextButton(
                    onPressed: _isBusy
                        ? null
                        : () {
                            setState(() {
                              _isSignUp = !_isSignUp;
                            });
                          },
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign in'
                          : 'Need an account? Sign up',
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isBusy || !configured
                        ? null
                        : () => _oauthSignIn(
                              SupabaseService.instance.signInWithGoogle,
                            ),
                    icon: const Icon(Icons.login),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _isBusy || !configured
                        ? null
                        : () => _oauthSignIn(
                              SupabaseService.instance.signInWithApple,
                            ),
                    icon: const Icon(Icons.apple),
                    label: const Text('Continue with Apple'),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
