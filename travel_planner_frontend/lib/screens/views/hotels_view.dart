import '../../widgets/map_action.dart';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/discover_content.dart';
import '../../models/travel_models.dart';
import '../../services/travel_api_service.dart';
import '../../widgets/page_parts.dart';

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
  int _resultRadius = 5;
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
      _resultRadius = _radiusKm;
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
                photo: DiscoverContent.stays,
                photoAlignment: const Alignment(0, .2),
                eyebrow: 'Hotels',
                title: 'Find a place to stay',
                subtitle:
                    'Browse hotel locations around your destination and open any of them in Maps.',
                tip:
                    'A small radius keeps you close to the centre. Widen it to find quieter neighbourhoods.',
                search: SearchCard(child: _buildSearchFields()),
              ),
              const SizedBox(height: 22),
              CityChips(
                  cities: _popularCities,
                  selected: _cityCtrl.text,
                  onPick: (city) {
                    _cityCtrl.text = city;
                    _search();
                  }),
              const SizedBox(height: 22),
              const HowToSteps(steps: [
                ('Choose a city', 'Type one or tap a popular pick.'),
                ('Set how far to look', 'From 3 to 15 km around the centre.'),
                (
                  'Open a location',
                  'See it on the map before you book elsewhere.'
                ),
              ]),
              const SizedBox(height: 40),
              _buildResultsSection(context, cityPhoto),
              const SizedBox(height: 28),
              PhotoCredits(photos: [
                DiscoverContent.stays,
                if (_hotels.isNotEmpty) cityPhoto
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchFields() {
    final city = SearchField(
        label: 'Destination city',
        child: TextField(
            controller: _cityCtrl,
            style: searchValueStyle,
            decoration: const InputDecoration.collapsed(
                hintText: 'e.g. Paris, Tokyo, London'),
            onSubmitted: (_) => _search()));
    final radius = SearchField(
        label: 'Search radius',
        child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
                value: _radiusKm,
                isDense: true,
                isExpanded: true,
                style: searchValueStyle.copyWith(
                    fontSize: 18, fontWeight: FontWeight.w500),
                icon: const Icon(Icons.expand_more_rounded,
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
                })));
    final button = ElevatedButton.icon(
        onPressed: _isLoading ? null : _search,
        icon: const Icon(Icons.search_rounded, size: 20),
        label: const Text('Find Hotels'),
        style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)));
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth >= 700) {
        return Row(children: [
          Expanded(flex: 3, child: city),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: radius),
          const SizedBox(width: 12),
          button,
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        city,
        const SizedBox(height: 12),
        radius,
        const SizedBox(height: 16),
        button,
      ]);
    });
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
                'Locating hotels near city center...',
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

    if (_error != null) {
      return _statusCard([
        const Icon(Icons.cloud_off_rounded, color: AppTheme.primary, size: 32),
        const SizedBox(height: 10),
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        TextButton(onPressed: _search, child: const Text('Retry')),
      ]);
    }

    if (_hotels.isEmpty) {
      return _statusCard(const [
        Icon(Icons.hotel_outlined, color: AppTheme.primary, size: 32),
        SizedBox(height: 10),
        Text(
          'No hotels found for this city. Try expanding the radius or searching another city.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResultsBanner(
          photo: cityPhoto,
          photoAlignment: const Alignment(0, -.3),
          title:
              '${_hotels.length} stay${_hotels.length == 1 ? '' : 's'} in $_resultCity',
          subtitle: 'Within $_resultRadius km of the city centre',
        ),
        const SizedBox(height: 16),
        const InfoChips(notes: [
          'Listings from Geoapify',
          'Prices, ratings and amenities unavailable.',
        ]),
        const SizedBox(height: 18),
        ResponsiveGrid(children: [
          for (var i = 0; i < _hotels.length; i++)
            _buildHotelCard(_hotels[i], i + 1),
        ]),
      ],
    );
  }

  Widget _buildHotelCard(HotelItem hotel, int number) => HoverCard(
      builder: (active) => Padding(
          padding: const EdgeInsets.all(22),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                      color: AppTheme.skyMint,
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.bed_outlined,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              ExcludeSemantics(
                  child: Text(number.toString().padLeft(2, '0'),
                      style: tripHeading.copyWith(
                          fontSize: 24, color: const Color(0xFFEEE8DA)))),
            ]),
            const SizedBox(height: 14),
            Text(hotel.name,
                style: tripHeading.copyWith(
                    fontSize: 16, height: 1.35, color: AppTheme.textPrimary)),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: AnimatedSlide(
                      offset: active ? const Offset(0, -.3) : Offset.zero,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      child: const Icon(Icons.place_outlined,
                          size: 18, color: AppTheme.primary))),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(hotel.address,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, height: 1.5))),
            ]),
            const SizedBox(height: 14),
            PillButtonTheme(child: MapAction(lat: hotel.lat, lon: hotel.lon)),
          ])));
}
