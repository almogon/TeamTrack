import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/subscription.dart';

final subscriptionProvider = FutureProvider<Subscription?>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;
  final data = await Supabase.instance.client
      .from('subscriptions')
      .select()
      .eq('user_id', user.id)
      .maybeSingle();
  if (data == null) return null;
  return Subscription.fromJson(data);
});
