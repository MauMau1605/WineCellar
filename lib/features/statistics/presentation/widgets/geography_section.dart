import 'package:flutter/material.dart';

import 'package:wine_cellar/features/statistics/domain/entities/cellar_statistics.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/stat_bar_chart.dart';

/// Geography section with tabs for country, region, and appellation.
class GeographySection extends StatefulWidget {
  final List<CountryStat> countryData;
  final List<RegionStat> regionData;
  final List<AppellationStat> appellationData;

  const GeographySection({
    super.key,
    required this.countryData,
    required this.regionData,
    required this.appellationData,
  });

  @override
  State<GeographySection> createState() => _GeographySectionState();
}

class _GeographySectionState extends State<GeographySection> {
  int _selectedTab = 0;

  static const _tabLabels = ['Pays', 'Régions', 'Appellations'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _tabLabels.asMap().entries.map((entry) {
              final selected = _selectedTab == entry.key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(entry.value),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedTab = entry.key),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        _buildChart(theme),
      ],
    );
  }

  Widget _buildChart(ThemeData theme) {
    switch (_selectedTab) {
      case 0:
        return StatBarChart(
          items: widget.countryData
              .map((c) => BarItem(label: c.country, value: c.bottles.toDouble()))
              .toList(),
          barColor: theme.colorScheme.primary,
        );
      case 1:
        return StatBarChart(
          items: widget.regionData
              .map((r) => BarItem(label: r.region, value: r.bottles.toDouble()))
              .toList(),
          barColor: const Color(0xFF8D6E63),
        );
      case 2:
        return StatBarChart(
          items: widget.appellationData
              .map((a) =>
                  BarItem(label: a.appellation, value: a.bottles.toDouble()))
              .toList(),
          barColor: const Color(0xFF7B1FA2),
          maxItems: 15,
        );
      default:
        return const SizedBox();
    }
  }
}
