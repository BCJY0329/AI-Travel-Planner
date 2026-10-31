import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../chat/lemon_chat_controller.dart';
import '../config/app_theme.dart';
import 'chat_bubble.dart';
import 'trip_date_dialog.dart';
import 'lemon_avatar_image.dart';

class LemonChatPanel extends StatefulWidget {
  final LemonChatController controller;
  final VoidCallback onClose;
  final VoidCallback? onViewItinerary;
  final ValueChanged<Offset>? onResize;
  const LemonChatPanel(
      {super.key,
      required this.controller,
      required this.onClose,
      this.onViewItinerary,
      this.onResize});
  @override
  State<LemonChatPanel> createState() => _LemonChatPanelState();
}

class _LemonChatPanelState extends State<LemonChatPanel> {
  late final TextEditingController _text;
  late final TextEditingController _other;
  final _scroll = ScrollController();
  LemonChatController get c => widget.controller;
  late final TextEditingController _travelers;
  String? _travelerError;
  String? _dateError;
  String? _lastField;
  bool _gripHover = false;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: c.draft);
    _travelers = TextEditingController(text: '${c.travelers ?? 1}');
    _other = TextEditingController(text: c.otherInterests);
    _lastField = c.nextField;
    c.addListener(_update);
  }

  @override
  void dispose() {
    c.removeListener(_update);
    _text.dispose();
    _travelers.dispose();
    _other.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _update() {
    if (_lastField != c.nextField) {
      _lastField = c.nextField;
      _other.text = c.otherInterests;
      _travelers.text = '${c.travelers ?? 1}';
      _travelerError = null;
    }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
      }
    });
  }

  void _send() {
    if (c.isBusy || c.error != null || _text.text.trim().isEmpty) return;
    if (_text.value.composing.isValid && !_text.value.composing.isCollapsed) {
      return;
    }
    if (_text.text.length > 600) return;
    final value = _text.text;
    _text.clear();
    c.draft = '';
    c.handleUserInput(value);
  }

  void _submitTravelers() {
    final raw = _travelers.text.trim();
    final value = int.tryParse(raw);
    if (!RegExp(r'^\d+$').hasMatch(raw) ||
        value == null ||
        value < 1 ||
        value > 20) {
      setState(() => _travelerError = 'Enter a whole number from 1 to 20.');
      return;
    }
    setState(() => _travelerError = null);
    c.setTravelers(value);
  }

  Future<void> _pickDates() async {
    if (c.isBusy) return;
    final now = DateUtils.dateOnly(DateTime.now());
    final start = DateTime.tryParse(c.startDate ?? '');
    final end = DateTime.tryParse(c.endDate ?? '');
    final last = DateUtils.addDaysToDate(now, 730);
    final valid = start != null &&
        end != null &&
        !start.isBefore(now) &&
        !end.isBefore(start) &&
        !end.isAfter(last);
    final picked = await showDialog<DateTimeRange>(
        context: context,
        builder: (_) => TripDateDialog(
            today: now,
            initial: valid ? DateTimeRange(start: start, end: end) : null));
    if (!mounted || picked == null) return;
    if (picked.duration.inDays >= 30) {
      setState(() => _dateError = 'Choose a trip of 30 days or fewer.');
      return;
    }
    setState(() => _dateError = null);
    c.setDates(picked.start, picked.end);
  }

  @override
  Widget build(BuildContext context) => Material(
        color: AppTheme.surface,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppTheme.skyBlue, width: 1.5)),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          Column(children: [
            Container(
                padding: EdgeInsets.fromLTRB(
                    widget.onResize == null ? 16 : 30, 14, 8, 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [AppTheme.skyBlue, AppTheme.surface],
                      stops: [0, .75],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  border: Border(
                      bottom: BorderSide(color: AppTheme.border, width: 1)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [
                          AppTheme.accentLemon,
                          AppTheme.accentLemonDark
                        ])),
                    child: const CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.surface,
                        child: LemonAvatarImage(radius: 22)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Lemon.ai',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontFamily: AppTheme.headingFont,
                                fontSize: 19,
                                height: 1.2,
                                letterSpacing: -0.4,
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: 3),
                        Row(children: [
                          _OnlineDot(),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text('Your personal travel companion',
                                overflow: TextOverflow.ellipsis,
                                // Darker than primary: sits on the skyBlue end
                                // of the header gradient (6.8:1).
                                style: TextStyle(
                                    color: AppTheme.primaryDark,
                                    fontSize: 12,
                                    letterSpacing: 0.2,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ]),
                      ])),
                  IconButton(
                      onPressed: widget.onClose,
                      tooltip: 'Close assistant',
                      style: IconButton.styleFrom(
                          backgroundColor:
                              AppTheme.surface.withValues(alpha: 0.7)),
                      icon: const Icon(Icons.close_rounded,
                          size: 20, color: AppTheme.textPrimary)),
                ])),
            _StepProgress(field: c.nextField),
            Expanded(
                child: DecoratedBox(
                    decoration: const BoxDecoration(
                        gradient: LinearGradient(
                            colors: [
                          AppTheme.lavenderSubtle,
                          Color(0xFFFFFCF1)
                        ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter)),
                    child: ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final message in c.messages)
                            ChatBubbleWidget(
                                message: message,
                                onQuickReply: c.handleQuickReply,
                                onPickDate: (_) => _pickDates()),
                          if (c.isBusy)
                            Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(children: [
                                  const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Text(c.phase ==
                                              ChatPhase.generating
                                          ? 'Building your itinerary. Longer trips can take over a minute.'
                                          : 'Finding your destination…')),
                                ])),
                          if (c.error != null)
                            Container(
                                padding: const EdgeInsets.all(14),
                                margin: const EdgeInsets.only(top: 12),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFFFF0E9),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(c.error!),
                                      const SizedBox(height: 12),
                                      ..._spaced([
                                        _primaryAction(
                                            'Retry',
                                            Icons.refresh_rounded,
                                            c.isBusy ? null : c.retry),
                                        _secondaryAction(
                                            c.canRetryPlan
                                                ? 'Edit trip details'
                                                : 'Change destination',
                                            Icons.edit_outlined,
                                            c.isBusy
                                                ? null
                                                : () => c.editField(
                                                    c.canRetryPlan
                                                        ? 'confirm'
                                                        : 'destination')),
                                      ]),
                                    ])),
                          if (!c.isBusy && c.error == null) ..._controls(),
                        ]))),
            if (c.nextField == 'destination')
              Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),
                  decoration: const BoxDecoration(
                      color: AppTheme.surface,
                      border:
                          Border(top: BorderSide(color: AppTheme.borderLight))),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                            child: CallbackShortcuts(
                                bindings: {
                              const SingleActivator(LogicalKeyboardKey.enter):
                                  _send,
                              const SingleActivator(
                                  LogicalKeyboardKey.numpadEnter): _send,
                            },
                                child: TextField(
                                  controller: _text,
                                  textInputAction: TextInputAction.send,
                                  maxLength: 600,
                                  buildCounter: (context,
                                          {required currentLength,
                                          required isFocused,
                                          maxLength}) =>
                                      null,
                                  minLines: 1,
                                  maxLines: 3,
                                  onChanged: (v) => c.draft = v,
                                  onSubmitted: (_) => _send(),
                                  decoration: InputDecoration(
                                      labelText: 'Where would you like to go?',
                                      hintText:
                                          'For example, Kyoto or a beach trip in Bali',
                                      counterText: '',
                                      fillColor: AppTheme.lavenderSubtle,
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                              color: AppTheme.fieldBorder)),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                              color: AppTheme.primary,
                                              width: 1.6))),
                                ))),
                        const SizedBox(width: 8),
                        IconButton.filled(
                            onPressed:
                                c.isBusy || c.error != null ? null : _send,
                            tooltip: 'Send message',
                            style: IconButton.styleFrom(
                                backgroundColor: AppTheme.cta,
                                foregroundColor: AppTheme.ctaInk,
                                fixedSize: const Size(46, 46)),
                            icon: const Icon(Icons.send_rounded, size: 20)),
                      ])),
          ]),
          if (widget.onResize != null)
            Positioned(
              top: 0,
              left: 0,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpLeft,
                onEnter: (_) => setState(() => _gripHover = true),
                onExit: (_) => setState(() => _gripHover = false),
                child: Semantics(
                  label: 'Drag this corner to resize the chat',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) => widget.onResize!(details.delta),
                    child: Tooltip(
                      message: 'Drag to resize chat',
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: CustomPaint(
                            painter: _CornerGripPainter(
                                color: AppTheme.primary.withValues(
                                    alpha: _gripHover ? 0.95 : 0.55))),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      );

  /// The step's main action: bold sky blue with a soft glow so it stands out.
  Widget _primaryAction(String label, IconData icon, VoidCallback? onPressed) =>
      ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          label: Text(label),
          style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shadowColor: const Color(0xFF6EA0DC).withValues(alpha: .5),
                  textStyle: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .1))
              .copyWith(
                  elevation: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.disabled)
                          ? 0
                          : states.contains(WidgetState.hovered)
                              ? 6
                              : 3)));

  /// Other choices: the same sky blue family, paler, so the pair reads as one
  /// set rather than two competing colours.
  Widget _secondaryAction(
          String label, IconData icon, VoidCallback? onPressed) =>
      OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 19),
          label: Text(label),
          style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  backgroundColor: AppTheme.ctaSoft,
                  foregroundColor: AppTheme.ctaInk,
                  textStyle: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w700))
              .copyWith(
                  side: AppTheme.focusOutline(
                      const BorderSide(color: AppTheme.cta, width: 1.5))));

  /// Puts a 10px gap between stacked buttons so they never touch.
  List<Widget> _spaced(List<Widget> buttons) => [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          buttons[i],
        ]
      ];

  List<Widget> _controls() {
    switch (c.nextField) {
      case 'dates':
        return [
          const SizedBox(height: 14),
          _primaryAction(
              'Pick my travel dates', Icons.calendar_month_rounded, _pickDates),
          if (_dateError != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_dateError!,
                    style: const TextStyle(color: AppTheme.error)))
        ];
      case 'travelers':
        return [
          const SizedBox(height: 12),
          TextField(
              controller: _travelers,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitTravelers(),
              decoration: InputDecoration(
                  labelText: 'Number of travelers',
                  helperText: 'Enter a whole number from 1 to 20',
                  errorText: _travelerError)),
          const SizedBox(height: 14),
          _primaryAction(
              'Continue', Icons.arrow_forward_rounded, _submitTravelers)
        ];
      case 'budget_level':
        return [
          const SizedBox(height: 14),
          ..._spaced([
            for (final choice in [
              ('low', 'Budget-friendly', Icons.savings_outlined),
              ('medium', 'Comfortable', Icons.weekend_outlined),
              ('high', 'Premium', Icons.diamond_outlined)
            ])
              _secondaryAction(
                  choice.$2, choice.$3, () => c.setBudget(choice.$1)),
          ])
        ];
      case 'interests':
        final ready =
            c.selectedInterests.isNotEmpty || _other.text.trim().isNotEmpty;
        return [
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final interest in [
              'Food',
              'Culture & history',
              'Nature',
              'Beaches',
              'Shopping',
              'Adventure',
              'Nightlife',
              'Relaxation'
            ])
              FilterChip(
                  label: Text(interest),
                  // Picked interests turn pale blue, matching the buttons.
                  selectedColor: AppTheme.ctaSoft,
                  checkmarkColor: AppTheme.ctaInk,
                  side: WidgetStateBorderSide.resolveWith((states) =>
                      states.contains(WidgetState.focused) && AppTheme.showFocus
                          ? AppTheme.focusSide
                          : BorderSide(
                              color: states.contains(WidgetState.selected)
                                  ? AppTheme.cta
                                  : AppTheme.border,
                              width: states.contains(WidgetState.selected)
                                  ? 1.5
                                  : 1)),
                  selected: c.selectedInterests.contains(interest),
                  onSelected: (selected) => setState(() {
                        if (selected) {
                          c.selectedInterests.add(interest);
                        } else {
                          c.selectedInterests.remove(interest);
                        }
                      })),
          ]),
          const SizedBox(height: 12),
          TextField(
              controller: _other,
              maxLength: 120,
              onChanged: (v) {
                c.otherInterests = v;
                setState(() {});
              },
              decoration: const InputDecoration(
                  labelText: 'Other interests or preferences',
                  hintText: 'For example, vegetarian food or gentle walks')),
          if (!ready)
            const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Pick at least one, or let Lemon surprise you.',
                    style: TextStyle(color: AppTheme.textSecondary))),
          ..._spaced([
            _primaryAction(
                'Go with these interests',
                Icons.check_rounded,
                ready
                    ? () {
                        c.setInterests([
                          ...c.selectedInterests,
                          if (_other.text.trim().isNotEmpty) _other.text.trim()
                        ]);
                        _other.clear();
                      }
                    : null),
            _secondaryAction('Surprise me', Icons.casino_rounded, () {
              c.setInterests([]);
              _other.clear();
            }),
          ])
        ];
      case 'confirm':
        return [
          _brief(),
          const SizedBox(height: 14),
          _primaryAction('Generate my itinerary', Icons.route_rounded,
              c.confirmTrip)
        ];
      default:
        return [
          if (c.latestItinerary != null) ...[
            const SizedBox(height: 14),
            ..._spaced([
              _primaryAction('View my itinerary', Icons.map_outlined,
                  widget.onViewItinerary),
              if (c.latestItinerary!.providerUsed == 'mock')
                // Wording matches the mock itinerary's own note.
                _secondaryAction('Retry personalized generation',
                    Icons.refresh_rounded, c.retry),
              _secondaryAction('Edit trip details', Icons.edit_outlined,
                  () => c.editField('confirm')),
              _secondaryAction(
                  'Plan another trip', Icons.add_location_alt, c.startOver),
            ]),
          ]
        ];
    }
  }

  Widget _brief() => Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppTheme.lavenderSubtle,
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('YOUR TRIP BRIEF',
            style: TextStyle(
                fontFamily: AppTheme.headingFont,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary)),
        for (final item in [
          ('destination', 'Destination', c.destination ?? ''),
          ('dates', 'Dates', '${c.startDate} → ${c.endDate}'),
          ('travelers', 'Travelers', '${c.travelers}'),
          ('budget_level', 'Budget', _budgetName(c.budgetLevel)),
          (
            'interests',
            'Interests',
            c.interests.isEmpty ? 'Surprise me' : c.interests.join(', ')
          ),
        ])
          ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.$2,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary)),
              subtitle: Text(item.$3,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600)),
              trailing: IconButton(
                  tooltip: 'Edit ${item.$2.toLowerCase()}',
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => c.editField(item.$1))),
      ]));

  String _budgetName(String? value) => switch (value) {
        'low' => 'Budget-friendly',
        'medium' => 'Comfortable',
        'high' => 'Premium',
        _ => value ?? '',
      };
}

/// Where / When / Who / Budget / Loves, filled up to the current guided step.
class _StepProgress extends StatelessWidget {
  final String? field;
  const _StepProgress({required this.field});
  static const _steps = [
    ('destination', 'Where'),
    ('dates', 'When'),
    ('travelers', 'Who'),
    ('budget_level', 'Budget'),
    ('interests', 'Loves'),
  ];
  @override
  Widget build(BuildContext context) {
    final index = _steps.indexWhere((step) => step.$1 == field);
    final current = index < 0 ? _steps.length : index;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppTheme.motionStandard;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(bottom: BorderSide(color: AppTheme.borderLight))),
      child: Row(children: [
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
              child: Semantics(
            label:
                '${_steps[i].$2}: ${i < current ? 'done' : i == current ? 'current step' : 'to do'}',
            excludeSemantics: true,
            child: Column(children: [
              AnimatedContainer(
                  duration: duration,
                  height: 6,
                  decoration: BoxDecoration(
                      color: i < current
                          ? AppTheme.primary
                          : i == current
                              ? AppTheme.cta
                              : AppTheme.border,
                      borderRadius: BorderRadius.circular(99))),
              const SizedBox(height: 5),
              Text(_steps[i].$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: i <= current
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary)),
            ]),
          )),
        ],
      ]),
    );
  }
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot();
  @override
  Widget build(BuildContext context) => Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
          color: AppTheme.success,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: AppTheme.success.withValues(alpha: 0.45),
                blurRadius: 4,
                spreadRadius: 1)
          ]));
}

/// Six dots stacked as a triangle that tucks into the panel's rounded
/// top-left corner, so every dot stays inside the 24px corner radius.
class _CornerGripPainter extends CustomPainter {
  final Color color;
  const _CornerGripPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const origin = 9.0, step = 5.0;
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3 - row; col++) {
        canvas.drawCircle(
            Offset(origin + col * step, origin + row * step), 1.6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CornerGripPainter old) => old.color != color;
}
