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
        elevation: 8,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          Column(children: [
            Container(
                padding: EdgeInsets.fromLTRB(
                    widget.onResize == null ? 16 : 34, 12, 8, 12),
                color: AppTheme.mint,
                child: Row(children: [
                  const LemonAvatarImage(radius: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Lemon.ai',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        Text('Your personal travel companion',
                            style: TextStyle(
                                color: AppTheme.textPrimary, fontSize: 12)),
                      ])),
                  IconButton(
                      onPressed: widget.onClose,
                      tooltip: 'Close assistant',
                      icon:
                          const Icon(Icons.close, color: AppTheme.textPrimary)),
                ])),
            Expanded(
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
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(c.phase == ChatPhase.generating
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.error!),
                              TextButton.icon(
                                  onPressed: c.isBusy ? null : c.retry,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry')),
                              TextButton(
                                  onPressed: c.isBusy
                                      ? null
                                      : () => c.editField(c.canRetryPlan
                                          ? 'confirm'
                                          : 'destination'),
                                  child: Text(c.canRetryPlan
                                      ? 'Edit trip details'
                                      : 'Change destination')),
                            ])),
                  if (!c.isBusy && c.error == null) ..._controls(),
                ])),
            if (c.nextField == 'destination')
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                  decoration: const InputDecoration(
                                      labelText: 'Where would you like to go?',
                                      hintText:
                                          'For example, Kyoto or a beach trip in Bali',
                                      counterText: ''),
                                ))),
                        IconButton(
                            onPressed:
                                c.isBusy || c.error != null ? null : _send,
                            tooltip: 'Send message',
                            icon: const Icon(Icons.send_rounded)),
                      ])),
          ]),
          if (widget.onResize != null)
            Positioned(
              top: 0,
              left: 0,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpLeft,
                child: Semantics(
                  label: 'Drag this corner to resize the chat',
                  child: GestureDetector(
                    onPanUpdate: (details) => widget.onResize!(details.delta),
                    child: Tooltip(
                      message: 'Drag to resize chat',
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: AppTheme.mint,
                          borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              bottomRight: Radius.circular(10)),
                        ),
                        child: const Icon(Icons.drag_indicator_rounded,
                            size: 18, color: AppTheme.teal),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      );
  List<Widget> _controls() {
    switch (c.nextField) {
      case 'dates':
        return [
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: _pickDates,
              icon: const Icon(Icons.date_range),
              label: const Text('Choose travel dates')),
          if (_dateError != null)
            Text(_dateError!, style: const TextStyle(color: AppTheme.error))
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
          const SizedBox(height: 10),
          ElevatedButton(
              onPressed: _submitTravelers, child: const Text('Continue'))
        ];
      case 'budget_level':
        return [
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final choice in [
              ('low', 'Budget-friendly'),
              ('medium', 'Comfortable'),
              ('high', 'Premium')
            ])
              ActionChip(
                  label: Text(choice.$2),
                  onPressed: () => c.setBudget(choice.$1)),
          ])
        ];
      case 'interests':
        return [
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
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
          const SizedBox(height: 8),
          ElevatedButton(
              onPressed: c.selectedInterests.isEmpty &&
                      _other.text.trim().isEmpty
                  ? null
                  : () {
                      c.setInterests([
                        ...c.selectedInterests,
                        if (_other.text.trim().isNotEmpty) _other.text.trim()
                      ]);
                      _other.clear();
                    },
              child: const Text('Continue with these interests')),
          OutlinedButton.icon(
              onPressed: () {
                c.setInterests([]);
                _other.clear();
              },
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Surprise me'))
        ];
      case 'confirm':
        return [
          _brief(),
          const SizedBox(height: 12),
          ElevatedButton.icon(
              onPressed: c.confirmTrip,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate my itinerary'))
        ];
      default:
        return [
          if (c.latestItinerary != null) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
                onPressed: widget.onViewItinerary,
                icon: const Icon(Icons.map_outlined),
                label: const Text('View itinerary')),
            if (c.latestItinerary!.providerUsed == 'mock')
              TextButton(
                  onPressed: c.retry,
                  child: const Text('Retry personalized generation')),
            TextButton(
                onPressed: () => c.editField('confirm'),
                child: const Text('Edit trip details')),
            TextButton(
                onPressed: c.startOver, child: const Text('Plan another trip')),
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
