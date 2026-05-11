import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/banner.dart';
import 'banner_repository.dart';

class SupabaseBannerRepository implements BannerRepository {
  SupabaseBannerRepository({required SupabaseClient supabase})
      : _supabase = supabase;

  final SupabaseClient _supabase;

  @override
  Future<List<HomeBanner>> list() async {
    final response = await _supabase
        .from('banners')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return response
        .map<HomeBanner>(HomeBanner.fromSupabaseJson)
        .toList(growable: false);
  }
}
