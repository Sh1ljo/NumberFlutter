import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../logic/backend_service.dart';
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
    final service = BackendService.instance;
    if (!service.isInitialized) return;
    _authSub = service.authStateChanges().listen((user) {
      if (user != null && mounted && Navigator.canPop(context)) {
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
      final service = BackendService.instance;
      if (_isSignUp) {
        // Firebase signs the new account in straight away; the auth
        // listener above closes this screen.
        await service.signUpWithEmailPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await service.signInWithEmailPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _authErrorMessage(
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
        _errorMessage = _authErrorMessage(
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

  /// Firebase auth errors carry a code we can explain; anything else falls
  /// back to the generic offline / failure message.
  String _authErrorMessage(
    Object error, {
    required String offlineMessage,
    required String fallbackMessage,
  }) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Wrong email or password.';
        case 'invalid-email':
          return 'That email address is not valid.';
        case 'email-already-in-use':
          return 'An account with this email already exists. Sign in instead.';
        case 'weak-password':
          return 'Password is too weak. Use at least 6 characters.';
        case 'too-many-requests':
          return 'Too many attempts. Wait a minute and try again.';
        case 'sign-in-cancelled':
        case 'popup-closed-by-user':
        case 'web-context-canceled':
          return 'Sign in was cancelled.';
        case 'network-request-failed':
          return offlineMessage;
        case 'google-not-configured':
        case 'missing-id-token':
          return error.message ?? fallbackMessage;
      }
    }
    return cloudErrorMessage(
      error,
      offlineMessage: offlineMessage,
      fallbackMessage: fallbackMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = BackendService.instance;
    final configured = service.isConfigured;
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
                        'Could not reach the cloud. Check your connection and restart the game to sign in.',
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
                  if (service.supportsGoogleSignIn) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _isBusy || !configured
                          ? null
                          : () => _oauthSignIn(service.signInWithGoogle),
                      icon: const Icon(Icons.login),
                      label: const Text('Continue with Google'),
                    ),
                  ],
                  if (service.supportsAppleSignIn) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _isBusy || !configured
                          ? null
                          : () => _oauthSignIn(service.signInWithApple),
                      icon: const Icon(Icons.apple),
                      label: const Text('Continue with Apple'),
                    ),
                  ],
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
