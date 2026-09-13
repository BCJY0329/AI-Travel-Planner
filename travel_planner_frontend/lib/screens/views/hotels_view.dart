import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/travel_models.dart';
import '../../services/travel_api_service.dart';

class HotelsView extends StatefulWidget {
  const HotelsView({super.key});

  @override
  State<HotelsView> createState() => _HotelsViewState();
}

class _HotelsViewState extends State<HotelsView> {
  final TravelApiService _apiService = TravelApiService();
  final TextEditingController _cityCtrl = TextEditingController(text: 'Paris');
  int _radiusKm = 5;

  bool _isLoading = false;
  List<HotelItem> _hotels = [];

  final List<String> _popularCities = ['Paris', 'Tokyo', 'Rome', 'London', 'Kyoto', 'Bali'];

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

    setState(() => _isLoading = true);
    final results = await _apiService.searchHotels(city: city, radiusKm: _radiusKm);
    if (mounted) {
      setState(() {
        _hotels = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
            color: AppTheme.primary.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
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
                width: 260,
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: DropdownButton<int>(
                    value: _radiusKm,
                    icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primary),
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
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            final isSelected = _cityCtrl.text.toLowerCase() == city.toLowerCase();
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
                style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
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
        Row(
          children: [
            Text(
              '${_hotels.length} Stays in ${_cityCtrl.text}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            const Text(
              'Curated accommodations & guest ratings',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 750;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _hotels.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 2 : 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 190,
              ),
              itemBuilder: (context, index) {
                final hotel = _hotels[index];
                return _buildHotelCard(context, hotel);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildHotelCard(BuildContext context, HotelItem hotel) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hotel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            hotel.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.lavenderTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 16, color: Color(0xFFEAB308)),
                    const SizedBox(width: 4),
                    Text(
                      hotel.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: hotel.amenities.take(3).map((amenity) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  amenity,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              );
            }).toList(),
          ),
          const Spacer(),
          Row(
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '\$${hotel.pricePerNight} ',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const TextSpan(
                      text: '/ night',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Selected ${hotel.name}!'),
                      backgroundColor: AppTheme.primary,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('View Deal', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
