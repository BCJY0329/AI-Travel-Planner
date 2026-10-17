import '../../widgets/map_action.dart';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/travel_models.dart';
import '../../services/travel_api_service.dart';

class AttractionsView extends StatefulWidget {
  const AttractionsView({super.key, this.apiService});
  final TravelApiService? apiService;

  @override
  State<AttractionsView> createState() => _AttractionsViewState();
}

class _AttractionsViewState extends State<AttractionsView> {
  late final TravelApiService _apiService =
      widget.apiService ?? TravelApiService();
  final TextEditingController _cityCtrl = TextEditingController(text: 'Paris');
  String _selectedCategory = 'All';

  bool _isLoading = false;
  String? _error;
  int _searchId = 0;
  List<AttractionItem> _attractions = [];

  final List<String> _categories = [
    'All',
    'Sightseeing',
    'Landmark & Sights',
    'Culture & Heritage',
    'Entertainment'
  ];
  final List<String> _suggestedCities = [
    'Paris',
    'Tokyo',
    'Rome',
    'Barcelona',
    'Kyoto'
  ];

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final city = _cityCtrl.text.trim();
    if (city.isEmpty) return;
    final searchId = ++_searchId;
    setState(() {
      _isLoading = true;
      _error = null;
      _attractions = [];
    });
    try {
      final results = await _apiService.getAttractions(city: city, radiusKm: 8);
      if (!mounted || searchId != _searchId) return;
      setState(() {
        _attractions = results;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || searchId != _searchId) return;
      setState(() {
        _isLoading = false;
        _error = 'Unable to load attractions. Please try again.';
      });
    }
  }

  List<AttractionItem> get _filteredAttractions {
    if (_selectedCategory == 'All') return _attractions;
    return _attractions.where((a) => a.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchHeader(context),
          const SizedBox(height: 16),
          _buildCategoryFilters(),
          const SizedBox(height: 24),
          _buildResultsSection(context),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Icon(Icons.place_rounded, color: AppTheme.primary, size: 22),
              SizedBox(width: 8),
              Text(
                'Explore Points of Interest & Sights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: (MediaQuery.sizeOf(context).width - 88).clamp(0, 280),
                child: TextField(
                  controller: _cityCtrl,
                  decoration: const InputDecoration(
                    labelText: 'City / Region',
                    hintText: 'e.g. Paris, Tokyo, Rome',
                    prefixIcon: Icon(Icons.travel_explore_rounded, size: 18),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _search,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Discover Attractions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text(
                  'Popular: ',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary),
                ),
                ..._suggestedCities.map((c) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () {
                        _cityCtrl.text = c;
                        _search();
                      },
                      child: Text(
                        '$c • ',
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(cat),
              selected: isSelected,
              selectedColor: AppTheme.lavenderTint,
              backgroundColor: AppTheme.surface,
              side: BorderSide(
                  color: isSelected ? AppTheme.primary : AppTheme.border),
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12.5,
              ),
              onSelected: (_) => setState(() => _selectedCategory = cat),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResultsSection(BuildContext context) {
    if (_error != null) {
      return Column(children: [
        Text(_error!),
        TextButton(onPressed: _search, child: const Text('Retry')),
      ]);
    }

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(height: 16),
              Text(
                'Fetching top attractions & sights...',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    final list = _filteredAttractions;
    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
          child: Text(
            'No attractions found under this category. Try selecting "All" or another city.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${list.length} Attractions in ${_cityCtrl.text}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const Text(
              'Points of Interest & Heritage',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
            builder: (context, box) =>
                Wrap(spacing: 16, runSpacing: 16, children: [
                  for (final item in list)
                    SizedBox(
                        width: box.maxWidth > 750
                            ? (box.maxWidth - 16) / 2
                            : box.maxWidth,
                        child: _buildAttractionCard(context, item)),
                ])),
      ],
    );
  }

  Widget _buildAttractionCard(BuildContext context, AttractionItem item) =>
      Card(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Chip(
                        label: Text(item.category),
                        backgroundColor: const Color(0xFFE1F1EB)),
                    const SizedBox(height: 10),
                    Text(item.name,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.4)),
                    const SizedBox(height: 12),
                    MapAction(lat: item.lat, lon: item.lon),
                  ])));
}
