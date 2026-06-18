import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/validators.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../auth/providers/profile_provider.dart';
import '../models/sport_type.dart';
import '../providers/teams_provider.dart';

class CreateTeamScreen extends ConsumerStatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  ConsumerState<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends ConsumerState<CreateTeamScreen> {
  int _step = 0;
  SportType? _sport;
  TeamFormat? _format;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _seasonController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _seasonController.dispose();
    super.dispose();
  }

  void _pickSport(SportType sport) {
    setState(() {
      _sport = sport;
      _format = sport.formats.length == 1 ? sport.formats.first : null;
      _step = sport.formats.length == 1 ? 2 : 1;
    });
  }

  void _pickFormat(TeamFormat format) {
    setState(() {
      _format = format;
      _step = 2;
    });
  }

  Future<void> _createTeam() async {
    if (!_formKey.currentState!.validate()) return;

    final profile = ref.read(profileProvider).value;
    final teams = ref.read(teamsProvider).value ?? [];
    final teamLimit = profile?.teamLimit;
    if (profile != null && teamLimit != null && teams.length >= teamLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Plan limit reached ($teamLimit team${teamLimit == 1 ? '' : 's'}). Upgrade to add more.',
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(teamsProvider.notifier).createTeam(
            name: _nameController.text,
            sport: _sport!.value,
            format: _format!.size,
            minPlayers: _format!.minPlayers,
            maxPlayers: _format!.maxPlayers,
            season: _seasonController.text,
          );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create team: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) setState(() => _step--);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_appBarTitle),
          leading: _step == 0
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _step--),
                ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey(_step),
            child: switch (_step) {
              0 => _SportStep(onPick: _pickSport),
              1 => _FormatStep(sport: _sport!, onPick: _pickFormat),
              _ => _DetailsStep(
                  format: _format!,
                  formKey: _formKey,
                  nameController: _nameController,
                  seasonController: _seasonController,
                  loading: _loading,
                  onSubmit: _createTeam,
                ),
            },
          ),
        ),
      ),
    );
  }

  String get _appBarTitle => switch (_step) {
        0 => 'New team',
        1 => 'Choose format',
        _ => 'Team details',
      };
}

// ── Step 0: sport picker ──────────────────────────────────────────────────────

class _SportStep extends StatelessWidget {
  const _SportStep({required this.onPick});

  final void Function(SportType) onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Choose a sport',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        for (final sport in SportType.values) ...[
          _SportCard(sport: sport, onTap: () => onPick(sport)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SportCard extends StatelessWidget {
  const _SportCard({required this.sport, required this.onTap});

  final SportType sport;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Icon(_sportIcon(sport),
                  size: 32, color: cs.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sport.label,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      sport.formats.map((f) => f.label).join(' · '),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.outline),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }

  IconData _sportIcon(SportType sport) => switch (sport) {
        SportType.football => Icons.sports_soccer,
        SportType.basketball => Icons.sports_basketball,
        SportType.volleyball => Icons.sports_volleyball,
      };
}

// ── Step 1: format picker ─────────────────────────────────────────────────────

class _FormatStep extends StatelessWidget {
  const _FormatStep({required this.sport, required this.onPick});

  final SportType sport;
  final void Function(TeamFormat) onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Choose a format',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(sport.label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 24),
        for (final format in sport.formats) ...[
          _FormatCard(format: format, onTap: () => onPick(format)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({required this.format, required this.onTap});

  final TeamFormat format;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: cs.primaryContainer,
                child: Text(
                  format.size,
                  style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(format.label,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      '${format.minPlayers}–${format.maxPlayers} players',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.outline),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 2: name + season ─────────────────────────────────────────────────────

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    required this.format,
    required this.formKey,
    required this.nameController,
    required this.seasonController,
    required this.loading,
    required this.onSubmit,
  });

  final TeamFormat format;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController seasonController;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Team details',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  format.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Team name'),
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      Validators.requiredText(v, label: 'Team name'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: seasonController,
                  decoration: const InputDecoration(
                    labelText: 'Season (optional)',
                    hintText: 'e.g. 2026',
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => onSubmit(),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Create team',
                  onPressed: loading ? null : onSubmit,
                  loading: loading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
