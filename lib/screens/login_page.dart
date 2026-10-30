import 'package:flutter/material.dart';

import '../session.dart';
import '../theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.session});
  final FarmSession session;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    widget.session.store.meta('loginEmail').then((email) {
      if (!mounted || email == null || email.isEmpty || _email.text.isNotEmpty) return;
      setState(() => _email.text = email);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final session = widget.session;
    if (session.busy) return;
    session.login(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: _Mark(),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Farm desk',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.8),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in once on the farm network. After that, the same email and password open this phone without it.',
                    style: TextStyle(color: Desk.muted(context), fontSize: 16, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline, color: Desk.muted(context)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline, color: Desk.muted(context)),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Desk.muted(context)),
                      ),
                    ),
                  ),
                  if (session.message != null) ...[
                    const SizedBox(height: 16),
                    Text(session.message!, style: const TextStyle(color: FarmColors.danger, height: 1.35)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: session.busy ? null : _submit,
                    child: session.busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: FarmColors.accentInk),
                          )
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Powered by PlugoraHUB',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Desk.muted(context), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: FarmColors.accent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.agriculture, color: FarmColors.accentInk, size: 30),
    );
  }
}
