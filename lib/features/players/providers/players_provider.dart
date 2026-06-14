import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../teams/models/player.dart';

final playerProvider =
    FutureProvider.family<Player, String>((ref, playerId) async {
  final data = await Supabase.instance.client
      .from('players')
      .select()
      .eq('id', playerId)
      .single();
  return Player.fromJson(data);
});
