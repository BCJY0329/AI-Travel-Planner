import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/discover_content.dart';
import '../../models/travel_models.dart';
import '../../services/travel_api_service.dart';
import '../../widgets/page_parts.dart';

class FlightsView extends StatefulWidget {
  const FlightsView({super.key, this.apiService, this.now, this.onOpenLemon});

  final TravelApiService? apiService;
  final DateTime Function()? now;
  final VoidCallback? onOpenLemon;

  @override
  State<FlightsView> createState() => _FlightsViewState();
}

class _FlightsViewState extends State<FlightsView> {
  late final TravelApiService _apiService;

  final TextEditingController _originCtrl = TextEditingController(text: 'KUL');
  final TextEditingController _destCtrl = TextEditingController(text: 'NRT');
  late DateTime _departure;
  String get _departureDate =>
      '${_departure.year.toString().padLeft(4, '0')}-${_departure.month.toString().padLeft(2, '0')}-${_departure.day.toString().padLeft(2, '0')}';

  DateTime get _today => DateUtils.dateOnly((widget.now ?? DateTime.now)());

  DateTime _validDeparture(DateTime today) {
    final lastDate = DateUtils.addDaysToDate(today, 365);
    if (_departure.isBefore(today)) return today;
    if (_departure.isAfter(lastDate)) return lastDate;
    return _departure;
  }

  int _adults = 1;

  bool _isLoading = false;
  String? _error;
  int _searchId = 0;
  List<FlightOffer> _offers = [];
  // What the current results were searched for, for the results banner.
  String _resultFrom = '', _resultTo = '';
  DateTime? _resultDate;
  int _resultAdults = 1;

  final List<Map<String, String>> _popularRoutes = [
    {'from': 'KUL', 'to': 'NRT', 'fromCity': 'Kuala Lumpur', 'toCity': 'Tokyo'},
    {'from': 'SIN', 'to': 'HND', 'fromCity': 'Singapore', 'toCity': 'Tokyo'},
    {'from': 'JFK', 'to': 'LHR', 'fromCity': 'New York', 'toCity': 'London'},
    {'from': 'CDG', 'to': 'FCO', 'fromCity': 'Paris', 'toCity': 'Rome'},
    {'from': 'SYD', 'to': 'DPS', 'fromCity': 'Sydney', 'toCity': 'Bali'},
  ];

  // Airports whose city has a photo in DiscoverContent.
  static const _airportCities = {
    'NRT': 'Tokyo',
    'HND': 'Tokyo',
    'CDG': 'Paris',
    'ORY': 'Paris',
    'FCO': 'Rome',
    'CIA': 'Rome',
    'DPS': 'Bali',
  };

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? TravelApiService();
    _departure = DateUtils.addDaysToDate(_today, 14);
    _search();
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final searchId = ++_searchId;
    setState(() {
      _departure = _validDeparture(_today);
      _isLoading = true;
      _error = null;
      _offers = [];
      _resultFrom = _originCtrl.text.trim().toUpperCase();
      _resultTo = _destCtrl.text.trim().toUpperCase();
      _resultDate = _departure;
      _resultAdults = _adults;
    });
    try {
      final results = await _apiService.searchFlights(
        origin: _originCtrl.text,
        destination: _destCtrl.text,
        departureDate: _departureDate,
        adults: _adults,
      );
      if (!mounted || searchId != _searchId) return;
      setState(() {
        _offers = results;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || searchId != _searchId) return;
      setState(() {
        _isLoading = false;
        _error = 'Unable to load flights. Please try again.';
      });
    }
  }

  Future<void> _pickDate() async {
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _validDeparture(today),
      firstDate: today,
      lastDate: DateUtils.addDaysToDate(today, 365),
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
    if (!mounted) return;
    if (picked != null) {
      setState(() {
        _departure = picked;
      });
      _search();
    }
  }

  DiscoverPhoto get _resultPhoto {
    final city = _airportCities[_resultTo];
    return (city == null ? null : DiscoverContent.photoForPlace(city)) ??
        DiscoverContent.flights;
  }

  @override
  Widget build(BuildContext context) {
    final showResults = !_isLoading && _error == null && _offers.isNotEmpty;
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
                photo: DiscoverContent.flights,
                photoAlignment: const Alignment(0, .24),
                eyebrow: 'Flights',
                title: 'Find your flight',
                subtitle:
                    'Compare routes, schedules and prices in one place, then let Lemon plan the days around them.',
                tip:
                    'Use 3-letter airport codes, like KUL for Kuala Lumpur or NRT for Tokyo Narita.',
                search: SearchCard(child: _buildSearchFields()),
              ),
              const SizedBox(height: 20),
              _buildQuickRouteChips(),
              const SizedBox(height: 22),
              const HowToSteps(steps: [
                ('Enter airport codes', 'From and to, like KUL and NRT.'),
                ('Pick a date and travelers', 'Up to 6 adults on one search.'),
                (
                  'Compare the offers',
                  'Prices are totals for your whole party.'
                ),
              ]),
              const SizedBox(height: 40),
              _buildResultsSection(context),
              if (widget.onOpenLemon != null) ...[
                const SizedBox(height: 40),
                LemonPromptBand(
                    title: 'Found a flight you like?',
                    text:
                        "Tell Lemon your dates and she'll plan what to do once you land.",
                    action: 'Plan with Lemon',
                    onPressed: widget.onOpenLemon!),
              ],
              const SizedBox(height: 28),
              PhotoCredits(photos: [
                DiscoverContent.flights,
                if (showResults) _resultPhoto
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchFields() {
    final from = SearchField(
        label: 'From (IATA)',
        child: TextField(
            controller: _originCtrl,
            textCapitalization: TextCapitalization.characters,
            style: searchValueStyle,
            decoration: const InputDecoration.collapsed(hintText: 'e.g. KUL'),
            onSubmitted: (_) => _search()));
    final to = SearchField(
        label: 'To (IATA)',
        child: TextField(
            controller: _destCtrl,
            textCapitalization: TextCapitalization.characters,
            style: searchValueStyle,
            decoration: const InputDecoration.collapsed(hintText: 'e.g. NRT'),
            onSubmitted: (_) => _search()));
    final swap = IconButton(
        tooltip: 'Swap airports',
        style: IconButton.styleFrom(backgroundColor: AppTheme.sky),
        icon: const Icon(Icons.swap_horiz_rounded, color: AppTheme.primary),
        onPressed: () {
          final tmp = _originCtrl.text;
          _originCtrl.text = _destCtrl.text;
          _destCtrl.text = tmp;
          _search();
        });
    final date = SearchField(
        label: 'Departure',
        onTap: _pickDate,
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded,
              size: 18, color: AppTheme.primary),
          const SizedBox(width: 8),
          Flexible(
              child: Text(_departureDate,
                  style: searchValueStyle.copyWith(
                      fontSize: 18, fontWeight: FontWeight.w500))),
        ]));
    final travelers = SearchField(
        label: 'Travelers',
        child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
                value: _adults,
                isDense: true,
                isExpanded: true,
                style: searchValueStyle.copyWith(
                    fontSize: 18, fontWeight: FontWeight.w500),
                icon: const Icon(Icons.expand_more_rounded,
                    color: AppTheme.primary),
                items: [1, 2, 3, 4, 5, 6]
                    .map((n) => DropdownMenuItem<int>(
                        value: n, child: Text('$n adult${n > 1 ? "s" : ""}')))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _adults = val);
                    _search();
                  }
                })));
    final button = ElevatedButton.icon(
        onPressed: _isLoading ? null : _search,
        icon: const Icon(Icons.search_rounded, size: 20),
        label: const Text('Find Flights'),
        style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)));
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth >= 900) {
        return Row(children: [
          Expanded(flex: 3, child: from),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6), child: swap),
          Expanded(flex: 3, child: to),
          const SizedBox(width: 12),
          Expanded(flex: 4, child: date),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: travelers),
          const SizedBox(width: 12),
          button,
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: from),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4), child: swap),
          Expanded(child: to),
        ]),
        const SizedBox(height: 12),
        date,
        const SizedBox(height: 12),
        travelers,
        const SizedBox(height: 16),
        button,
      ]);
    });
  }

  Widget _buildQuickRouteChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Quick routes:',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          ),
        ),
        ..._popularRoutes.map((r) {
          final isSelected = _originCtrl.text.toUpperCase() == r['from'] &&
              _destCtrl.text.toUpperCase() == r['to'];
          // The arrow is an icon: '➔' is missing from the bundled fonts, and
          // the web fallback font shifted and clipped some labels.
          return ChoiceChip(
            label: Semantics(
              label: '${r['fromCity']} to ${r['toCity']}',
              excludeSemantics: true,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(r['fromCity']!),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 14, color: AppTheme.textSecondary),
                ),
                Text(r['toCity']!),
              ]),
            ),
            selected: isSelected,
            showCheckmark: false,
            labelStyle: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
            onSelected: (_) {
              _originCtrl.text = r['from']!;
              _destCtrl.text = r['to']!;
              _search();
            },
          );
        }),
      ],
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

  Widget _buildResultsSection(BuildContext context) {
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
                'Searching available flights...',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                'Searches can take up to 45 seconds.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (_offers.isEmpty) {
      return _statusCard(const [
        Icon(Icons.flight_outlined, color: AppTheme.primary, size: 32),
        SizedBox(height: 10),
        Text(
          'No flight offers found for this route. Try changing airports or dates.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      ]);
    }

    final travelers = '$_resultAdults traveler${_resultAdults == 1 ? '' : 's'}';
    final date = _resultDate == null
        ? ''
        : ' · ${MaterialLocalizations.of(context).formatMediumDate(_resultDate!)}';
    final cheapest = _cheapestIndex();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResultsBanner(
          photo: _resultPhoto,
          photoAlignment: const Alignment(0, -.1),
          title: '$_resultFrom → $_resultTo',
          subtitle:
              '${_offers.length} offer${_offers.length == 1 ? '' : 's'}$date · $travelers',
        ),
        const SizedBox(height: 16),
        const InfoChips(notes: [
          'Prices are totals for all travelers',
          'Offers from Duffel (test mode)',
          'Searches can take up to 45 seconds',
        ]),
        const SizedBox(height: 18),
        ResponsiveGrid(maxColumns: 1, children: [
          for (var i = 0; i < _offers.length; i++)
            _buildFlightCard(_offers[i], cheapest == i, travelers),
        ]),
      ],
    );
  }

  /// The single cheapest offer, when there is more than one to compare.
  int? _cheapestIndex() {
    if (_offers.length < 2) return null;
    int? best;
    double? low;
    for (var i = 0; i < _offers.length; i++) {
      final price = double.tryParse(_offers[i].price.replaceAll(',', ''));
      if (price == null || _offers[i].currency != _offers.first.currency) {
        return null;
      }
      if (low == null || price < low) {
        low = price;
        best = i;
      }
    }
    return best;
  }

  Widget _buildFlightCard(FlightOffer offer, bool cheapest, String travelers) {
    return HoverCard(
      builder: (active) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 850 ||
                MediaQuery.textScalerOf(context).scale(14) > 18;
            return isCompact
                ? _buildCompactCard(offer, cheapest, travelers, active)
                : _buildWideCard(offer, cheapest, travelers, active);
          },
        ),
      ),
    );
  }

  Widget _carrier(FlightOffer offer, double size) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
            color: AppTheme.skyMint, shape: BoxShape.circle),
        child: Text(offer.carrier,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
      );

  Widget _stopsPill(FlightOffer offer) {
    final direct = offer.stops == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
          color: direct ? AppTheme.sky : AppTheme.lemon,
          borderRadius: BorderRadius.circular(999)),
      child: Text(direct ? 'Direct' : offer.stopsText,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: direct ? AppTheme.primary : const Color(0xFF6B4E00))),
    );
  }

  Widget _cheapestTag() => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
            color: AppTheme.lemon, borderRadius: BorderRadius.circular(999)),
        child: const Text('Lowest price',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B4E00))),
      );

  Widget _details(FlightOffer offer) => OutlinedButton(
      onPressed: () => _showDetails(offer),
      style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700)),
      child: const Text('View details'));

  Widget _clock(String time, String airport, CrossAxisAlignment align) =>
      Column(crossAxisAlignment: align, children: [
        Text(time,
            style: tripHeading.copyWith(
                fontSize: 22, color: AppTheme.textPrimary)),
        Text(airport,
            style: const TextStyle(
                fontSize: 13,
                letterSpacing: .8,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary)),
      ]);

  Widget _buildWideCard(
      FlightOffer offer, bool cheapest, String travelers, bool active) {
    return Row(
      children: [
        _carrier(offer, 52),
        const SizedBox(width: 28),
        Expanded(
          flex: 3,
          child: Row(children: [
            _clock(offer.departureClock, offer.departure,
                CrossAxisAlignment.start),
            const SizedBox(width: 18),
            Expanded(
                child: Column(children: [
              Text(offer.readableDuration,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              _FlightPath(flying: active),
              const SizedBox(height: 8),
              _stopsPill(offer),
            ])),
            const SizedBox(width: 18),
            _clock(offer.arrivalClock, offer.arrival, CrossAxisAlignment.end),
          ]),
        ),
        const SizedBox(width: 28),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (cheapest) _cheapestTag(),
            Text(
              '${offer.currency} ${offer.price}',
              style: tripHeading.copyWith(
                fontSize: 19,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              'total for $travelers',
              style: const TextStyle(
                  fontSize: 12.5, color: AppTheme.textSecondary),
            ),
          ],
        ),
        const SizedBox(width: 16),
        _details(offer),
      ],
    );
  }

  void _showDetails(FlightOffer offer) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
            title: Text('${offer.departure} → ${offer.arrival}'),
            content: SingleChildScrollView(
                child: Text(
                    'Carrier: ${offer.carrier}\nDeparture: ${offer.departureTime}\nArrival: ${offer.arrivalTime}\n${offer.readableDuration} · ${offer.stopsText}\n\n${offer.currency} ${offer.price} total for all travelers\n\nFor comparison only. Booking is not available in LemonTrip.')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'))
            ],
          ));

  Widget _buildCompactCard(
          FlightOffer offer, bool cheapest, String travelers, bool active) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _carrier(offer, 44),
          const SizedBox(width: 12),
          Expanded(
              child: Text('${offer.departureClock} → ${offer.arrivalClock}',
                  style: tripHeading.copyWith(
                      fontSize: 19, color: AppTheme.textPrimary))),
        ]),
        const SizedBox(height: 10),
        Text(
            '${offer.departure} → ${offer.arrival} · ${offer.readableDuration}',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        _FlightPath(flying: active),
        const SizedBox(height: 10),
        _stopsPill(offer),
        const SizedBox(height: 14),
        if (cheapest) _cheapestTag(),
        Text('${offer.currency} ${offer.price}',
            style: tripHeading.copyWith(
                fontSize: 18, color: AppTheme.textPrimary)),
        Text('Total for $travelers',
            style:
                const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
        const SizedBox(height: 12),
        _details(offer),
      ]);
}

/// A dashed route line; the plane glides to the far end while [flying].
class _FlightPath extends StatelessWidget {
  final bool flying;
  const _FlightPath({required this.flying});
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 18,
      child: LayoutBuilder(
          builder: (context, box) => Stack(children: [
                Positioned(
                    left: 0,
                    right: 0,
                    top: 8,
                    child: CustomPaint(
                        size: const Size(double.infinity, 2),
                        painter: _DashPainter())),
                AnimatedPositioned(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 900),
                    curve: Curves.easeInOutCubic,
                    left: flying ? box.maxWidth - 18 : 0,
                    top: 0,
                    child: const RotatedBox(
                        quarterTurns: 1,
                        child: Icon(Icons.flight,
                            size: 18, color: AppTheme.primary))),
              ])));
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.skyMint
      ..strokeWidth = 2;
    for (double x = 0; x < size.width; x += 14) {
      canvas.drawLine(Offset(x, 1),
          Offset((x + 8).clamp(0, size.width).toDouble(), 1), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => false;
}
