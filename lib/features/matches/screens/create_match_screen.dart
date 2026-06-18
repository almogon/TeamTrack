import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/match_list_provider.dart';

class CreateMatchScreen extends ConsumerStatefulWidget {
  const CreateMatchScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends ConsumerState<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _opponentCtrl = TextEditingController();
  final _competitionCtrl = TextEditingController();
  String _homeAway = 'home';
  DateTime _matchDate = DateTime.now();
  bool _loading = false;

  @override
  void dispose() {
    _opponentCtrl.dispose();
    _competitionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(matchListProvider(widget.teamId).notifier).createMatch(
            teamId: widget.teamId,
            matchDate: _matchDate,
            opponent: _opponentCtrl.text,
            homeAway: _homeAway,
            competition: _competitionCtrl.text,
          );
      if (mounted) context.pop();
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _matchDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _matchDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${_matchDate.day.toString().padLeft(2, '0')}/${_matchDate.month.toString().padLeft(2, '0')}/${_matchDate.year}';

    return Scaffold(
      appBar: AppBar(title: const Text('New Match')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _opponentCtrl,
              decoration: const InputDecoration(
                labelText: 'Opponent *',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Text('Location', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'home', label: Text('Home')),
                ButtonSegment(value: 'away', label: Text('Away')),
              ],
              selected: {_homeAway},
              onSelectionChanged: (s) => setState(() => _homeAway = s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _competitionCtrl,
              decoration: const InputDecoration(
                labelText: 'Competition (optional)',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Match date'),
              subtitle: Text(dateLabel),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create match'),
            ),
          ],
        ),
      ),
    );
  }
}
