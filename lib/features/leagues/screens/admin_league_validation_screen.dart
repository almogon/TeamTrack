import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/league.dart';
import '../providers/leagues_provider.dart';

class AdminLeagueValidationScreen extends ConsumerWidget {
  const AdminLeagueValidationScreen({super.key});

  Future<void> _approve(WidgetRef ref, League league) async {
    final user = Supabase.instance.client.auth.currentUser!;
    await Supabase.instance.client.from('leagues').update({
      'status': 'active',
      'validated_by': user.id,
    }).eq('id', league.id);
    ref.invalidate(pendingLeaguesProvider);
  }

  Future<void> _reject(WidgetRef ref, League league) async {
    await Supabase.instance.client.from('leagues').delete().eq('id', league.id);
    ref.invalidate(pendingLeaguesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingLeaguesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('League requests')),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (leagues) {
          if (leagues.isEmpty) {
            return const Center(child: Text('No pending league requests'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: leagues.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final league = leagues[index];
              return Card(
                child: ListTile(
                  title: Text(league.name),
                  subtitle: Text(
                    '${league.city} · ${league.zipCode} · ${league.season}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Reject',
                        onPressed: () => _reject(ref, league),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check),
                        tooltip: 'Approve',
                        onPressed: () => _approve(ref, league),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
