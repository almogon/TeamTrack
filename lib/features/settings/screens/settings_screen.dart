import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/profile_provider.dart';
import '../../teams/providers/teams_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final teamsAsync = ref.watch(teamsProvider);

    final username = profileAsync.value?.username ??
        Supabase.instance.client.auth.currentUser?.userMetadata?['username']
            as String? ??
        'User';
    final planLabel = profileAsync.value?.planLabel ?? 'Free';
    final int? teamLimit = profileAsync.value?.teamLimit; // null = unlimited
    final teamCount = teamsAsync.value?.length ?? 0;
    final matchLimit = profileAsync.value?.matchLimit;
    final atTeamLimit = teamLimit != null && teamCount >= teamLimit;
    final role = profileAsync.value?.role;
    final isAdminOrManager = role == 'admin' || role == 'manager';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SectionLabel('Profile'),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                username[0].toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text('@$username'),
            subtitle: Text(
              '$planLabel plan · $teamCount / ${teamLimit?.toString() ?? '∞'} team${teamLimit == 1 ? '' : 's'}'
              '${matchLimit != null ? ' · $matchLimit match limit' : ''}',
            ),
          ),
          const Divider(),
          _SectionLabel('Team'),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Create team'),
            trailing: atTeamLimit
                ? Chip(
                    label: const Text('Limit reached'),
                    backgroundColor:
                        Theme.of(context).colorScheme.errorContainer,
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontSize: 12,
                    ),
                    padding: EdgeInsets.zero,
                  )
                : const Icon(Icons.chevron_right),
            onTap: atTeamLimit ? null : () => context.push('/teams/new'),
          ),
          if (atTeamLimit)
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
              child: Text(
                "You've reached the beta's team limit.",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ),
          const Divider(),
          _SectionLabel('Plan'),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Plan'),
            subtitle: const Text('Free plan · Beta'),
          ),
          if (isAdminOrManager) ...[
            const Divider(),
            _SectionLabel('Admin'),
            ListTile(
              leading: const Icon(Icons.rule_folder_outlined),
              title: const Text('League requests'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/admin/leagues'),
            ),
          ],
          const Divider(),
          _SectionLabel('Account'),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/change-password'),
          ),
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
