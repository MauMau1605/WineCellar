import 'package:flutter/material.dart';

import 'package:wine_cellar/features/statistics/domain/entities/cellar_statistics.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/stat_bar_chart.dart';
import 'package:wine_cellar/features/statistics/presentation/widgets/stat_donut_chart.dart';

/// Geography section with tabs for country, region, and appellation.
class GeographySection extends StatefulWidget {
  final List<CountryStat> countryData;
  final List<RegionStat> regionData;
  final List<AppellationStat> appellationData;
  final bool _showAsPie;

  const GeographySection({
    super.key,
    required this.countryData,
    required this.regionData,
    required this.appellationData,
  }) : _showAsPie = false;

  const GeographySection.asPie({
    super.key,
    required this.countryData,
    required this.regionData,
    required this.appellationData,
  }) : _showAsPie = true;

  @override
  State<GeographySection> createState() => _GeographySectionState();
}

class _GeographySectionState extends State<GeographySection> {
  int _selectedTab = 0;

  static const _tabLabels = ['Pays', 'Régions', 'Appellations'];

  static const _pieColors = [
    Color(0xFF1976D2),
    Color(0xFFD32F2F),
    Color(0xFF388E3C),
    Color(0xFFF57C00),
    Color(0xFF7B1FA2),
    Color(0xFF00838F),
    Color(0xFFC2185B),
    Color(0xFF5D4037),
    Color(0xFF455A64),
    Color(0xFFAFB42B),
  ];

  @override
  Widget build(BuildContext context) {
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
        _buildChart(Theme.of(context)),
      ],
    );
  }

  Widget _buildChart(ThemeData theme) {
    if (widget._showAsPie) return _buildPieChart();
    return _buildBarChart(theme);
  }

  Widget _buildBarChart(ThemeData theme) {
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

  Widget _buildPieChart() {
    final totalBottles = _totalForTab();
    final segments = _segmentsForTab(totalBottles);
    return StatDonutChart(
      segments: segments,
      centerLabel: '$totalBottles\nbtl',
    );
  }

  int _totalForTab() {
    switch (_selectedTab) {
      case 0:
        return widget.countryData.fold<int>(0, (s, e) => s + e.bottles);
      case 1:
        return widget.regionData.fold<int>(0, (s, e) => s + e.bottles);
      case 2:
        return widget.appellationData.fold<int>(0, (s, e) => s + e.bottles);
      default:
        return 0;
    }
  }

  List<DonutSegment> _segmentsForTab(int total) {
    if (total == 0) return [];
    switch (_selectedTab) {
      case 0:
        return widget.countryData.asMap().entries.map((e) {
          return DonutSegment(
            label: e.value.country,
            value: e.value.percentage,
            count: e.value.bottles,
            color: _pieColors[e.key % _pieColors.length],
          );
        }).toList();
      case 1:
        return widget.regionData.asMap().entries.map((e) {
          return DonutSegment(
            label: e.value.region,
            value: e.value.percentage,
            count: e.value.bottles,
            color: _pieColors[e.key % _pieColors.length],
          );
        }).toList();
      case 2:
        return widget.appellationData.asMap().entries.map((e) {
          return DonutSegment(
            label: e.value.appellation,
            value: e.value.percentage,
            count: e.value.bottles,
            color: _pieColors[e.key % _pieColors.length],
          );
        }).toList();
      default:
        return [];
    }
  }
}
