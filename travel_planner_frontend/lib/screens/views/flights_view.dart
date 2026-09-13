import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../models/travel_models.dart';
import '../../services/travel_api_service.dart';

class FlightsView extends StatefulWidget {
  const FlightsView({super.key});

  @override
  State<FlightsView> createState() => _FlightsViewState();
}

class _FlightsViewState extends State<FlightsView> {
  final TravelApiService _apiService = TravelApiService();

  final TextEditingController _originCtrl = TextEditingController(text: 'KUL');
  final TextEditingController _destCtrl = TextEditingController(text: 'NRT');
  String _departureDate = '2026-10-01';
  int _adults = 1;

  bool _isLoading = false;
  List<FlightOffer> _offers = [];

  final List<Map<String, String>> _popularRoutes = [
    {'from': 'KUL', 'to': 'NRT', 'label': 'Kuala Lumpur ➔ Tokyo'},
    {'from': 'SIN', 'to': 'HND', 'label': 'Singapore ➔ Tokyo'},
    {'from': 'JFK', 'to': 'LHR', 'label': 'New York ➔ London'},
    {'from': 'CDG', 'to': 'FCO', 'label': 'Paris ➔ Rome'},
    {'from': 'SYD', 'to': 'DPS', 'label': 'Sydney ➔ Bali'},
  ];

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _isLoading = true);
    final results = await _apiService.searchFlights(
      origin: _originCtrl.text,
      destination: _destCtrl.text,
      departureDate: _departureDate,
      adults: _adults,
    );
    if (mounted) {
      setState(() {
        _offers = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_departureDate) ?? now.add(const Duration(days: 14)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _departureDate =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
      _search();
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
          const SizedBox(height: 20),
          _buildQuickRouteChips(),
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
          const Row(
            children: [
              Icon(Icons.flight_takeoff_rounded, color: AppTheme.primary, size: 22),
              SizedBox(width: 8),
              Text(
                'Search Live Flight Offers',
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
              // Origin
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _originCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'From (IATA)',
                    hintText: 'e.g. KUL',
                    prefixIcon: Icon(Icons.flight_takeoff, size: 18),
                  ),
                ),
              ),
              // Swap icon
              IconButton(
                icon: const Icon(Icons.swap_horiz_rounded, color: AppTheme.primary),
                onPressed: () {
                  final tmp = _originCtrl.text;
                  _originCtrl.text = _destCtrl.text;
                  _destCtrl.text = tmp;
                  _search();
                },
              ),
              // Destination
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _destCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'To (IATA)',
                    hintText: 'e.g. NRT',
                    prefixIcon: Icon(Icons.flight_land, size: 18),
                  ),
                ),
              ),
              // Date
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        _departureDate,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
              ),
              // Passengers
              DropdownButtonHideUnderline(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: DropdownButton<int>(
                    value: _adults,
                    icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primary),
                    items: [1, 2, 3, 4, 5, 6].map((n) {
                      return DropdownMenuItem<int>(
                        value: n,
                        child: Text('$n Adult${n > 1 ? "s" : ""}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _adults = val);
                        _search();
                      }
                    },
                  ),
                ),
              ),
              // Search Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _search,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Find Flights'),
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

  Widget _buildQuickRouteChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const Text(
            'Quick Routes: ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          ..._popularRoutes.map((r) {
            final isSelected = _originCtrl.text.toUpperCase() == r['from'] &&
                _destCtrl.text.toUpperCase() == r['to'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(r['label']!),
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
                  _originCtrl.text = r['from']!;
                  _destCtrl.text = r['to']!;
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
                'Searching available flights...',
                style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    if (_offers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Center(
          child: Text(
            'No flight offers found for this route. Try changing airports or dates.',
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
              '${_offers.length} Flights Available',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            const Text(
              'Prices include estimated taxes & fees',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _offers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final offer = _offers[index];
            return _buildFlightCard(context, offer);
          },
        ),
      ],
    );
  }

  Widget _buildFlightCard(BuildContext context, FlightOffer offer) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 650;
          return isCompact ? _buildCompactCard(offer) : _buildWideCard(offer);
        },
      ),
    );
  }

  Widget _buildWideCard(FlightOffer offer) {
    return Row(
      children: [
        // Carrier Badge
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.lavenderTint,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            offer.carrier,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppTheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 24),

        // Route details
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Departure
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.departureClock,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    offer.departure,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),

              // Duration & stops diagram
              Column(
                children: [
                  Text(
                    offer.readableDuration,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryLight)),
                      Container(width: 70, height: 2, color: AppTheme.border),
                      const Icon(Icons.flight, size: 16, color: AppTheme.primary),
                      Container(width: 70, height: 2, color: AppTheme.border),
                      Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: offer.stops == 0 ? const Color(0xFFE0F2FE) : AppTheme.lavenderSubtle,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      offer.stopsText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: offer.stops == 0 ? const Color(0xFF0369A1) : AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),

              // Arrival
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    offer.arrivalClock,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    offer.arrival,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 28),
        Container(width: 1, height: 50, color: AppTheme.border),
        const SizedBox(width: 28),

        // Price and Action
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${offer.price}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const Text(
              'per traveler',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Selected flight ${offer.carrier} ${offer.departure} ➔ ${offer.arrival}!'),
                    backgroundColor: AppTheme.primary,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('View Deal', style: TextStyle(fontSize: 12.5)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactCard(FlightOffer offer) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.lavenderTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                offer.carrier,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ),
            const Spacer(),
            Text(
              '\$${offer.price}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${offer.departureClock} (${offer.departure})', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${offer.readableDuration} • ${offer.stopsText}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            Text('${offer.arrivalClock} (${offer.arrival})', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
