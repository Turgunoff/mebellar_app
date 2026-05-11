import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';

import '../../../../../core/di/service_locator.dart';
import '../../../../../shared/models/region.dart';
import '../../../../../shared/repositories/region_repository.dart';

/// 3-level drill-down picker: viloyat в†’ shahar в†’ tuman. Returned via
/// `Navigator.pop` as a record so the caller can persist all 3 in the
/// address form. Search bar narrows top-level options for quicker access on
/// the 14-region tree.
class RegionPickerResult {
  const RegionPickerResult({
    required this.region,
    required this.city,
    this.district,
  });
  final Region region;
  final Region city;
  final Region? district;
}

class RegionPickerScreen extends StatefulWidget {
  const RegionPickerScreen({super.key});

  @override
  State<RegionPickerScreen> createState() => _RegionPickerScreenState();
}

class _RegionPickerScreenState extends State<RegionPickerScreen> {
  late Future<List<Region>> _treeFuture;

  Region? _region;
  Region? _city;
  Region? _district;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _treeFuture = sl<RegionRepository>().tree();
  }

  void _reset() => setState(() {
        _region = null;
        _city = null;
        _district = null;
        _query = '';
      });

  void _confirm() {
    final region = _region;
    final city = _city ?? region;
    if (region == null || city == null) return;
    Navigator.of(context).pop(
      RegionPickerResult(
        region: region,
        city: city,
        district: _district,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForLevel()),
        leading: _region == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  if (_district != null) {
                    _district = null;
                  } else if (_city != null) {
                    _city = null;
                  } else {
                    _region = null;
                  }
                }),
              ),
      ),
      body: FutureBuilder<List<Region>>(
        future: _treeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final tree = snapshot.data ?? const <Region>[];
          if (_region == null) {
            return _buildLevelList(
              context,
              tree,
              showSearch: true,
              onTap: (r) => setState(() {
                _region = r;
                if (!r.hasChildren) {
                  _city = r;
                }
              }),
            );
          }
          if (_city == null) {
            return _buildLevelList(
              context,
              _region!.children,
              onTap: (r) => setState(() => _city = r),
            );
          }
          // District is optional. Show "Skip" as a CTA at the bottom.
          return Column(
            children: [
              Expanded(
                child: _buildLevelList(
                  context,
                  // Districts hang off the city. In the curated tree the city
                  // doesn't have its own children, so we simulate "no
                  // district" by offering only "Skip" вЂ” keeps mock simple.
                  _city!.children,
                  onTap: (r) => setState(() {
                    _district = r;
                    _confirm();
                  }),
                  emptyMessage: tr('region.no_districts'),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _confirm,
                      child: Text(tr('region.skip_district')),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: (_region != null || _city != null)
          ? FloatingActionButton.small(
              tooltip: tr('common.cancel'),
              onPressed: _reset,
              child: const Icon(Icons.refresh),
            )
          : null,
    );
  }

  String _titleForLevel() {
    if (_region == null) return tr('region.pick_region');
    if (_city == null) return tr('region.pick_city');
    return tr('region.pick_district');
  }

  Widget _buildLevelList(
    BuildContext context,
    List<Region> regions, {
    required ValueChanged<Region> onTap,
    bool showSearch = false,
    String? emptyMessage,
  }) {
    final lang = context.locale.languageCode;
    final filtered = _query.isEmpty
        ? regions
        : regions
            .where((r) =>
                r.name.get(lang).toLowerCase().contains(_query.toLowerCase()))
            .toList();
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyMessage ?? tr('region.empty'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Column(
      children: [
        if (showSearch)
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: tr('region.search_hint'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        Expanded(
          child: ListView.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = filtered[i];
              return ListTile(
                title: Text(r.name.get(lang)),
                trailing: r.hasChildren
                    ? const Icon(Icons.chevron_right)
                    : null,
                onTap: () => onTap(r),
              );
            },
          ),
        ),
      ],
    );
  }
}
