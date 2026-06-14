import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/validators.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../teams/models/player.dart';
import '../../teams/models/sport_type.dart';
import '../../teams/providers/team_provider.dart';

class AddPlayerScreen extends ConsumerStatefulWidget {
  const AddPlayerScreen({super.key, required this.teamId, this.player});

  final String teamId;
  final Player? player;

  @override
  ConsumerState<AddPlayerScreen> createState() => _AddPlayerScreenState();
}

class _AddPlayerScreenState extends ConsumerState<AddPlayerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _aliasController;
  late final TextEditingController _numberController;
  String? _selectedPosition;
  bool _loading = false;

  bool get _isEdit => widget.player != null;

  @override
  void initState() {
    super.initState();
    final p = widget.player;
    _nameController = TextEditingController(text: p?.name ?? '');
    _aliasController = TextEditingController(text: p?.alias ?? '');
    _numberController =
        TextEditingController(text: p?.number?.toString() ?? '');
    _selectedPosition = p?.position;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aliasController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _submit(List<Position> positions) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final number = _numberController.text.trim().isEmpty
          ? null
          : int.tryParse(_numberController.text.trim());

      if (_isEdit) {
        await Supabase.instance.client.from('players').update({
          'name': _nameController.text.trim(),
          'alias': _aliasController.text.trim().isEmpty
              ? null
              : _aliasController.text.trim(),
          'number': number,
          'position': _selectedPosition,
        }).eq('id', widget.player!.id);
      } else {
        await Supabase.instance.client.from('players').insert({
          'team_id': widget.teamId,
          'name': _nameController.text.trim(),
          'alias': _aliasController.text.trim().isNotEmpty
              ? _aliasController.text.trim()
              : null,
          'number': number,
          'position': _selectedPosition,
        });
      }

      ref.invalidate(teamDetailProvider(widget.teamId));
      if (mounted) context.pop();
    } on PostgrestException catch (e) {
      if (mounted) {
        final msg = e.code == '23505'
            ? 'That shirt number is already taken in this team'
            : 'Error: ${e.message}';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(teamDetailProvider(widget.teamId));

    return detailAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (detail) {
        final positions = detail.team.sportType.positions;
        return Scaffold(
          appBar: AppBar(
            title: Text(_isEdit ? 'Edit player' : 'Add player'),
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration:
                            const InputDecoration(labelText: 'Full name'),
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            Validators.requiredText(v, label: 'Name'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _aliasController,
                        decoration: const InputDecoration(
                          labelText: 'Alias / nickname (optional)',
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _numberController,
                        decoration: const InputDecoration(
                          labelText: 'Shirt number (optional)',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPosition,
                        decoration:
                            const InputDecoration(labelText: 'Position'),
                        hint: const Text('Select position'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('— None —'),
                          ),
                          for (final pos in positions)
                            DropdownMenuItem(
                              value: pos.code,
                              child: Text('${pos.code} · ${pos.label}'),
                            ),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedPosition = v),
                      ),
                      const SizedBox(height: 32),
                      PrimaryButton(
                        label: _isEdit ? 'Save' : 'Add player',
                        onPressed: _loading ? null : () => _submit(positions),
                        loading: _loading,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
