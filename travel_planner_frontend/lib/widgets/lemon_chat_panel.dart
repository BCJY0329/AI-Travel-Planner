import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../chat/chat_message.dart';
import '../chat/lemon_chat_controller.dart';
import '../config/app_theme.dart';
import 'chat_bubble.dart';
import 'chat_parts.dart';
import 'trip_date_dialog.dart';
import 'lemon_avatar_image.dart';
import 'lemon_brand.dart';

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
  // Messages already shown appear at once; later ones rise in (057).
  late int _seen;
  final _textFocus = FocusNode();
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: c.draft);
    _travelers = TextEditingController(text: '${c.travelers ?? 1}');
    _other = TextEditingController(text: c.otherInterests);
    _lastField = c.nextField;
    _seen = c.messages.length;
    _textFocus.addListener(() => setState(() {}));
    c.addListener(_update);
  }

  @override
  void dispose() {
    c.removeListener(_update);
    _text.dispose();
    _travelers.dispose();
    _other.dispose();
    _scroll.dispose();
    _textFocus.dispose();
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
            side: const BorderSide(color: AppTheme.sandBorder, width: 1.5)),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          Column(children: [
            // Warm sorbet header with a thin lemon ring and the wordmark's
            // lemon as a badge (halo options A + C, DECISIONS 045).
            Container(
                padding: EdgeInsets.fromLTRB(
                    widget.onResize == null ? 16 : 30, 14, 8, 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Color(0xFFF6EBD4),
                    AppTheme.sorbet,
                    AppTheme.surface
                  ], stops: [
                    0,
                    .45,
                    .9
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  border: Border(
                      bottom: BorderSide(color: AppTheme.sandBorder, width: 1)),
                ),
                child: Row(children: [
                  SizedBox(
                    width: 58,
                    height: 56,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Container(
                        width: 53,
                        height: 53,
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.accentLemon,
                            boxShadow: [
                              BoxShadow(
                                  color: AppTheme.accentLemon
                                      .withValues(alpha: .22),
                                  spreadRadius: 4)
                            ]),
                        child: const CircleAvatar(
                            radius: 25,
                            backgroundColor: AppTheme.surface,
                            child: LemonAvatarImage(radius: 23.5)),
                      ),
                      Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                        color: AppTheme.ctaInk
                                            .withValues(alpha: .2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1))
                                  ]),
                              child: const LemonMark(size: 20))),
                    ]),
                  ),
                  const SizedBox(width: 8),
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
                                // 7.9:1 on the sorbet header.
                                style: TextStyle(
                                    color: AppTheme.sorbetInk,
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
                        // Pale cream so both bubble fades stand out.
                        color: Color(0xFFFFFCF5)),
                    child: ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final (i, message) in c.messages.indexed)
                            RiseIn(
                                key: ObjectKey(message),
                                play: i >= _seen,
                                origin: message.sender == ChatSender.bot
                                    ? Alignment.topLeft
                                    : Alignment.bottomRight,
                                child: ChatBubbleWidget(
                                    message: message,
                                    onQuickReply: c.handleQuickReply,
                                    onPickDate: (_) => _pickDates())),
                          if (c.isBusy)
                            RiseIn(
                                key: ValueKey(c.phase),
                                child: c.phase == ChatPhase.generating
                                    ? const PlanningCard()
                                    : const Align(
                                        alignment: Alignment.centerLeft,
                                        child: TypingDots(
                                            label:
                                                'Lemon is finding your destination…'))),
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
                          if (!c.isBusy && c.error == null)
                            RiseIn(
                                key: ValueKey('controls-${c.nextField}'),
                                delay: const Duration(milliseconds: 120),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: _controls())),
                        ]))),
            if (c.nextField == 'destination') _chatBox(),
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

  /// The typing box: a white pill with the send button inside it and a soft
  /// sky glow while focused (DECISIONS 057).
  Widget _chatBox() {
    final focused = _textFocus.hasFocus;
    final canSend = !c.isBusy && c.error == null;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppTheme.motionFast;
    return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.borderLight))),
        child: AnimatedContainer(
            duration: duration,
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.fromLTRB(18, 5, 6, 5),
            decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: focused ? AppTheme.primary : AppTheme.ctaEdge,
                    width: 1.5),
                boxShadow: [
                  if (focused)
                    BoxShadow(
                        color: AppTheme.cta.withValues(alpha: .7),
                        spreadRadius: 4),
                  BoxShadow(
                      color: AppTheme.ctaShadow
                          .withValues(alpha: focused ? .25 : .18),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ]),
            child: Row(children: [
              Expanded(
                  child: CallbackShortcuts(
                      bindings: {
                    const SingleActivator(LogicalKeyboardKey.enter): _send,
                    const SingleActivator(LogicalKeyboardKey.numpadEnter):
                        _send,
                  },
                      child: _ChatTyping(
                          child: TextField(
                        controller: _text,
                        focusNode: _textFocus,
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
                        decoration: const InputDecoration(
                            isCollapsed: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                            counterText: '',
                            semanticCounterText: '',
                            hintText: 'Try Kyoto, or a beach trip in Bali'),
                      )))),
              const SizedBox(width: 6),
              IconButton(
                  // An empty box sends nothing (see _send).
                  onPressed: canSend ? _send : null,
                  tooltip: 'Send message',
                  style: IconButton.styleFrom(
                          backgroundColor: AppTheme.cta,
                          foregroundColor: AppTheme.ctaInk,
                          disabledBackgroundColor: AppTheme.ctaSoft,
                          disabledForegroundColor: AppTheme.fieldBorder,
                          shadowColor: AppTheme.ctaShadow,
                          fixedSize: const Size(40, 40),
                          minimumSize: const Size(40, 40))
                      .copyWith(
                          elevation:
                              AppTheme.solidElevation(rest: 2, hover: 4)),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 21)),
            ])));
  }

  /// The step's main action: bold sky blue with a soft glow so it stands out.
  Widget _primaryAction(String label, IconData icon, VoidCallback? onPressed) =>
      ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          label: Text(label),
          style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
              textStyle: AppTheme.buttonText(size: 15.5)));

  /// Other choices: the same sky blue family, paler, so the pair reads as one
  /// set rather than two competing colours.
  Widget _secondaryAction(
          String label, IconData icon, VoidCallback? onPressed) =>
      OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 19),
          label: Text(label),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              textStyle:
                  AppTheme.buttonText(size: 14.5, weight: FontWeight.w700)));

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
          _ChatTyping(
              child: TextField(
                  controller: _travelers,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitTravelers(),
                  decoration: InputDecoration(
                      labelText: 'Number of travelers',
                      helperText: 'Enter a whole number from 1 to 20',
                      errorText: _travelerError))),
          const SizedBox(height: 14),
          _primaryAction(
              'Continue', Icons.arrow_forward_rounded, _submitTravelers)
        ];
      case 'budget_level':
        return [
          const SizedBox(height: 14),
          // Solid option pills with a hint each (DECISIONS 057).
          ..._spaced([
            for (final (value, label, hint, icon) in const [
              (
                'low',
                'Budget-friendly',
                'Simple stays, local food, free sights',
                Icons.savings_outlined
              ),
              (
                'medium',
                'Comfortable',
                'Mid-range stays and a few treats',
                Icons.weekend_outlined
              ),
              (
                'high',
                'Premium',
                'Top hotels and special experiences',
                Icons.diamond_outlined
              ),
            ])
              OptionPill(
                  label: label,
                  hint: hint,
                  icon: icon,
                  selected: c.budgetLevel == value,
                  onPressed: () => c.setBudget(value)),
          ])
        ];
      case 'interests':
        final ready =
            c.selectedInterests.isNotEmpty || _other.text.trim().isNotEmpty;
        return [
          const SizedBox(height: 12),
          // Icon pills that fill sky blue when picked (DECISIONS 057).
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (interest, icon) in const [
              ('Food', Icons.restaurant_rounded),
              ('Culture & history', Icons.account_balance_outlined),
              ('Nature', Icons.eco_outlined),
              ('Beaches', Icons.beach_access_outlined),
              ('Shopping', Icons.shopping_bag_outlined),
              ('Adventure', Icons.terrain_outlined),
              ('Nightlife', Icons.nightlife_rounded),
              ('Relaxation', Icons.spa_outlined),
            ])
              InterestPill(
                  label: interest,
                  icon: icon,
                  selected: c.selectedInterests.contains(interest),
                  onChanged: (selected) => setState(() {
                        if (selected) {
                          c.selectedInterests.add(interest);
                        } else {
                          c.selectedInterests.remove(interest);
                        }
                      })),
          ]),
          if (c.selectedInterests.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                    '${c.selectedInterests.length} picked · tap again to remove',
                    style: const TextStyle(
                        fontFamily: AppTheme.chatFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary))),
          const SizedBox(height: 12),
          // Keyed so it keeps focus when the picked count and the hint
          // above and below it come and go.
          _ChatTyping(
              key: const ValueKey('other-interests'),
              child: TextField(
                  controller: _other,
                  maxLength: 120,
                  onChanged: (v) {
                    c.otherInterests = v;
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                      labelText: 'Other interests or preferences',
                      hintText:
                          'For example, vegetarian food or gentle walks'))),
          if (!ready)
            const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Pick at least one, or let Lemon surprise you.',
                    style: TextStyle(
                        fontFamily: AppTheme.chatFont,
                        color: AppTheme.textSecondary))),
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
          _primaryAction(
              'Generate my itinerary', Icons.route_rounded, c.confirmTrip)
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
/// Puts a chat typing box in the chat font, Lexend (DECISIONS 057): the
/// typed text at 600 so it never looks slim, and its label, hint, helper and
/// error text.
class _ChatTyping extends StatelessWidget {
  final Widget child;
  const _ChatTyping({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    TextStyle? nunito(TextStyle? s) =>
        (s ?? const TextStyle()).copyWith(fontFamily: AppTheme.chatFont);
    final typed = nunito(theme.textTheme.bodyLarge)!
        .copyWith(fontWeight: FontWeight.w600);
    final input = theme.inputDecorationTheme;
    return Theme(
        data: theme.copyWith(
            // TextField draws typed text in bodyLarge (Material 3) and its
            // label and hint from the decoration theme.
            textTheme:
                theme.textTheme.copyWith(bodyLarge: typed, titleMedium: typed),
            inputDecorationTheme: input.copyWith(
                labelStyle: nunito(input.labelStyle),
                floatingLabelStyle: nunito(input.floatingLabelStyle),
                hintStyle: nunito(input.hintStyle),
                helperStyle: nunito(input.helperStyle),
                errorStyle: nunito(input.errorStyle))),
        child: child);
  }
}

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
                          ? AppTheme.accentLemon
                          : i == current
                              ? AppTheme.stepCurrent
                              : AppTheme.stepTodo,
                      borderRadius: BorderRadius.circular(99))),
              const SizedBox(height: 5),
              // Grey and sand sit close in lightness, so answered steps also
              // carry a tick and the current one is bold.
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (i < current) ...[
                  const Icon(Icons.check_rounded,
                      size: 12, color: AppTheme.lemonDeep),
                  const SizedBox(width: 2),
                ],
                Flexible(
                    child: Text(_steps[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: i == current
                                ? FontWeight.w800
                                : i < current
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                            color: i == current
                                ? AppTheme.sandInk
                                : i < current
                                    ? AppTheme.textPrimary
                                    : AppTheme.textSecondary))),
              ]),
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
