import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: leggere email da AuthController (MSAL claims) o endpoint /me (se lo aggiungi)
    const email = 'non ancora autenticato';

    return Scaffold(
      appBar: AppBar(title: const Text('Profilo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Text('Accesso effettuato con: $email'),
        ),
      ),
    );
  }
}