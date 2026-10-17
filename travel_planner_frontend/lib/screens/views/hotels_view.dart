import '../../widgets/map_action.dart';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/travel_models.dart';
import '../../services/travel_api_service.dart';

class HotelsView extends StatefulWidget {
  const HotelsView({super.key, this.apiService});
  final TravelApiService? apiService;

  @override
  State<HotelsView> createState() => _HotelsViewState();
}

class _HotelsViewState extends State<HotelsView> {
  late final TravelApiService _apiService =
      widget.apiService ?? TravelApiService();
  String? _error;
  String _resultCity = '';
  int _searchId = 0;
  final TextEditingController _cityCtrl = TextEditingController(text: 'Paris');
  int _radiusKm = 5;

  bool _isLoading = false;
  List<HotelItem> _hotels = [];

  final List<String> _popularCities = [
    'Paris',
    'Tokyo',
    'Rome',
    'London',
    'Kyoto',
    'Bali'
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
      _hotels = [];
      _resultCity = city;
    });
    try {
      final results =
          await _apiService.searchHotels(city: city, radiusKm: _radiusKm);
      if (!mounted || searchId != _searchId) return;
      setState(() {
        _hotels = results;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || searchId != _searchId) return;
      setState(() {
        _isLoading = false;
        _error = 'Unable to load hotels. Please try again.';
      });
    }
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
          _buildCityChips(),
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
              Icon(Icons.hotel_rounded, color: AppTheme.primary, size: 22),
              SizedBox(width: 8),
              Text(
                'Explore Hotels & Accommodations',
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
                width: (MediaQuery.sizeOf(context).width - 88).clamp(0, 260),
                child: TextField(
                  controller: _cityCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Destination City',
                    hintText: 'e.g. Paris, Tokyo, London',
                    prefixIcon: Icon(Icons.location_city_rounded, size: 18),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              DropdownButtonHideUnderline(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: DropdownButton<int>(
                    value: _radiusKm,
                    icon: const Icon(Icons.arrow_drop_down,
                        color: AppTheme.primary),
                    items: const [
                      DropdownMenuItem(value: 3, child: Text('Within 3 km')),
                      DropdownMenuItem(value: 5, child: Text('Within 5 km')),
                      DropdownMenuItem(value: 10, child: Text('Within 10 km')),
                      DropdownMenuItem(value: 15, child: Text('Within 15 km')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _radiusKm = val);
                        _search();
                      }
                    },
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _search,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Find Hotels'),
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
        ],
      ),
    );
  }

  Widget _buildCityChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const Text(
            'Suggested: ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          ..._popularCities.map((city) {
            final isSelected =
                _cityCtrl.text.toLowerCase() == city.toLowerCase();
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(city),
                selected: isSelected,
                selectedColor: AppTheme.lavenderTint,
                backgroundColor: AppTheme.surface,
                side: BorderSide(
                  color: isSelected ? AppTheme.primary : AppTheme.border,
                ),
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
                onSelected: (_) {
                  _cityCtrl.text = city;
                  _search();
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResultsSection(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(height: 16),
              Text(
                'Locating hotels near city center...',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Column(children: [
        Text(_error!),
        TextButton(onPressed: _search, child: const Text('Retry')),
      ]);
    }

    if (_hotels.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
          child: Text(
            'No hotels found for this city. Try expanding the radius or searching another city.',
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
              '${_hotels.length} Stays in $_resultCity',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const Text(
              'Listings from Geoapify',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Prices, ratings and amenities unavailable.',
                style: TextStyle(color: AppTheme.textSecondary))),
        LayoutBuilder(
          builder: (context, box) => Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final hotel in _hotels)
                SizedBox(
                  width: box.maxWidth > 750
                      ? (box.maxWidth - 16) / 2
                      : box.maxWidth,
                  child: _buildHotelCard(context, hotel),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHotelCard(BuildContext context, HotelItem hotel) => Card(
      child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(hotel.name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(hotel.address,
                style: const TextStyle(
                    color: AppTheme.textSecondary, height: 1.5)),
            const SizedBox(height: 10),
            MapAction(lat: hotel.lat, lon: hotel.lon),
          ])));
}
