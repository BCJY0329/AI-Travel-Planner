import '../../widgets/map_action.dart';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/discover_content.dart';
import '../../models/travel_models.dart';
import '../../services/travel_api_service.dart';
import '../../widgets/page_parts.dart';

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
  String _resultCity = '';
  List<AttractionItem> _attractions = [];

  final List<String> _categories = [
    'All',
    'Sightseeing',
    'Landmark & Sights',
    'Culture & Heritage',
    'Entertainment'
  ];
  static const _categoryIcons = {
    'Sightseeing': Icons.visibility_outlined,
    'Landmark & Sights': Icons.flag_outlined,
    'Culture & Heritage': Icons.account_balance_outlined,
    'Entertainment': Icons.confirmation_number_outlined,
  };
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
      _resultCity = city;
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
    final cityPhoto = DiscoverContent.photoForPlace(_resultCity);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageBanner(
                photo: DiscoverContent.sights,
                photoAlignment: const Alignment(0, -.2),
                eyebrow: 'Attractions',
                title: 'Follow your curiosity',
                subtitle:
                    'Find sights, landmarks and culture near your destination, then add them to your plan with Lemon.',
                tip:
                    'Use the filters to narrow things down. Culture & Heritage is great for museums and monuments.',
                search: SearchCard(child: _buildSearchFields()),
              ),
              const SizedBox(height: 22),
              CityChips(
                  cities: _suggestedCities,
                  selected: _cityCtrl.text,
                  onPick: (city) {
                    _cityCtrl.text = city;
                    _search();
                  }),
              const SizedBox(height: 22),
              const HowToSteps(steps: [
                ('Pick a city or region', 'Anywhere you are curious about.'),
                (
                  'Filter by what you love',
                  'Sights, landmarks, culture or fun.'
                ),
                (
                  'Open it on the map',
                  'Then ask Lemon to fit it into your days.'
                ),
              ]),
              const SizedBox(height: 40),
              _buildResultsSection(context, cityPhoto),
              const SizedBox(height: 28),
              PhotoCredits(photos: [
                DiscoverContent.sights,
                if (_attractions.isNotEmpty) cityPhoto
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchFields() {
    final city = SearchField(
        label: 'City or region',
        child: TextField(
            controller: _cityCtrl,
            style: searchValueStyle,
            decoration: const InputDecoration.collapsed(
                hintText: 'e.g. Paris, Tokyo, Rome'),
            onSubmitted: (_) => _search()));
    final button = ElevatedButton.icon(
        onPressed: _isLoading ? null : _search,
        icon: const Icon(Icons.explore_outlined, size: 20),
        label: const Text('Discover Attractions'),
        style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)));
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth >= 600) {
        return Row(children: [
          Expanded(child: city),
          const SizedBox(width: 12),
          button,
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        city,
        const SizedBox(height: 16),
        button,
      ]);
    });
  }

  Widget _buildCategoryFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((cat) {
        final isSelected = _selectedCategory == cat;
        final count = cat == 'All'
            ? _attractions.length
            : _attractions.where((a) => a.category == cat).length;
        return ChoiceChip(
          label: Text.rich(TextSpan(text: cat, children: [
            TextSpan(
                text: '  $count',
                style: const TextStyle(color: AppTheme.textSecondary)),
          ])),
          selected: isSelected,
          showCheckmark: false,
          labelStyle: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
          onSelected: (_) => setState(() => _selectedCategory = cat),
        );
      }).toList(),
    );
  }

  Widget _statusCard(List<Widget> children) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(children: children),
      );

  Widget _buildResultsSection(BuildContext context, DiscoverPhoto? cityPhoto) {
    if (_error != null) {
      return _statusCard([
        const Icon(Icons.cloud_off_rounded, color: AppTheme.primary, size: 32),
        const SizedBox(height: 10),
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        TextButton(onPressed: _search, child: const Text('Retry')),
      ]);
    }

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              LemonCircle(size: 72, background: AppTheme.background),
              SizedBox(height: 18),
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(height: 16),
              Text(
                'Fetching top attractions & sights...',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    const emptyText =
        'No attractions found under this category. Try selecting "All" or another city.';
    if (_attractions.isEmpty) {
      return _statusCard(const [
        Icon(Icons.place_outlined, color: AppTheme.primary, size: 32),
        SizedBox(height: 10),
        Text(emptyText,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary)),
      ]);
    }

    final list = _filteredAttractions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResultsBanner(
          photo: cityPhoto,
          photoAlignment: const Alignment(0, -.3),
          title:
              '${list.length} attraction${list.length == 1 ? '' : 's'} in $_resultCity',
          subtitle: 'Points of interest from Geoapify',
        ),
        const SizedBox(height: 18),
        Semantics(
            container: true,
            label: 'Filter by category',
            child: _buildCategoryFilters()),
        const SizedBox(height: 18),
        if (list.isEmpty)
          _statusCard(const [
            Text(emptyText,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary)),
          ])
        else
          ResponsiveGrid(children: [
            for (final item in list) _buildAttractionCard(item),
          ]),
      ],
    );
  }

  Widget _buildAttractionCard(AttractionItem item) => HoverCard(
      builder: (active) => Padding(
          padding: const EdgeInsets.all(22),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              AnimatedRotation(
                  turns: active ? -8 / 360 : 0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  child: AnimatedScale(
                      scale: active ? 1.08 : 1,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutBack,
                      child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                              color: AppTheme.skyMint,
                              borderRadius: BorderRadius.circular(14)),
                          child: Icon(
                              _categoryIcons[item.category] ??
                                  Icons.place_outlined,
                              color: AppTheme.textPrimary)))),
              const SizedBox(width: 12),
              Flexible(
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: AppTheme.sky,
                          borderRadius: BorderRadius.circular(999)),
                      child: Text(item.category,
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)))),
            ]),
            const SizedBox(height: 12),
            Text(item.name,
                style: tripHeading.copyWith(
                    fontSize: 16, height: 1.35, color: AppTheme.textPrimary)),
            const SizedBox(height: 14),
            PillButtonTheme(child: MapAction(lat: item.lat, lon: item.lon)),
          ])));
}
