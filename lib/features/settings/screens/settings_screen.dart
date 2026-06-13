import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  String get _username {
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
    return meta?['username'] as String? ?? 'User';
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    // AuthNotifier triggers router redirect to /login
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SectionLabel('Profile'),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                _username[0].toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(_username),
            subtitle: const Text('Free plan · 1 team'),
          ),
          const Divider(),
          _SectionLabel('Team'),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Create team'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/teams/new'),
          ),
          const Divider(),
          _SectionLabel('Account'),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: _signOut,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}
