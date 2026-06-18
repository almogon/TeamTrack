import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stat_rule.dart';

final statRulesProvider =
    FutureProvider.family<List<StatRule>, String>((ref, sport) async {
  final data = await Supabase.instance.client
      .from('stat_rules')
      .select()
      .eq('sport', sport);
  return (data as List<dynamic>)
      .map((e) => StatRule.fromJson(e as Map<String, dynamic>))
      .toList();
});
