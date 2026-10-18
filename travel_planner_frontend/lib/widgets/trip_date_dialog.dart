import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// End-date edits keep the start anchored until explicitly changed.
class TripDateDialog extends StatefulWidget {
  final DateTime today;
  final DateTimeRange? initial;
  const TripDateDialog({super.key, required this.today, this.initial});
  @override
  State<TripDateDialog> createState() => _TripDateDialogState();
}

class _TripDateDialogState extends State<TripDateDialog> {
  DateTime? start, end;
  late DateTime visibleMonth;
  bool changingStart = false;
  String? error;

  @override
  void initState() {
    super.initState();
    start = widget.initial?.start;
    end = widget.initial?.end;
    final shown = widget.initial?.start ?? widget.today;
    visibleMonth = DateTime(shown.year, shown.month);
  }

  int days(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day)
          .difference(DateTime.utc(a.year, a.month, a.day))
          .inDays +
      1;

  void select(DateTime value) => setState(() {
        error = null;
        if (start == null || changingStart) {
          start = value;
          end = null;
          changingStart = false;
        } else if (value.isBefore(start!)) {
          error = 'Choose an end on or after your start, or tap Change start.';
        } else if (days(start!, value) > 30) {
          error = 'Choose up to 30 days for one trip.';
        } else {
          end = value;
        }
      });

  bool _same(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _calendar(BuildContext context) {
    final local = MaterialLocalizations.of(context);
    final monthStart = DateTime(visibleMonth.year, visibleMonth.month);
    final offset = (monthStart.weekday % 7 - local.firstDayOfWeekIndex + 7) % 7;
    final first = monthStart.subtract(Duration(days: offset));
    final lastDay = DateUtils.addDaysToDate(widget.today, 730);
    final weekdays = local.narrowWeekdays;
    return Column(children: [
      Row(children: [
        Expanded(
            child: Text(local.formatMonthYear(visibleMonth),
                style: const TextStyle(
                    fontFamily: AppTheme.headingFont,
                    fontSize: 18,
                    fontWeight: FontWeight.w700))),
        IconButton(
            tooltip: 'Previous month',
            onPressed: visibleMonth.year == widget.today.year &&
                    visibleMonth.month == widget.today.month
                ? null
                : () => setState(() => visibleMonth =
                    DateTime(visibleMonth.year, visibleMonth.month - 1)),
            icon: const Icon(Icons.chevron_left_rounded)),
        IconButton(
            tooltip: 'Next month',
            onPressed: visibleMonth.year == lastDay.year &&
                    visibleMonth.month == lastDay.month
                ? null
                : () => setState(() => visibleMonth =
                    DateTime(visibleMonth.year, visibleMonth.month + 1)),
            icon: const Icon(Icons.chevron_right_rounded)),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        for (var i = 0; i < 7; i++)
          Expanded(
              child: Center(
                  child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(weekdays[(local.firstDayOfWeekIndex + i) % 7],
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                    fontSize: 12)),
          ))),
      ]),
      for (var week = 0; week < 6; week++)
        Row(children: [
          for (var weekday = 0; weekday < 7; weekday++)
            Expanded(
                child: _dateCell(
                    first.add(Duration(days: week * 7 + weekday)), lastDay)),
        ]),
    ]);
  }

  Widget _dateCell(DateTime date, DateTime lastDay) {
    final inMonth = date.month == visibleMonth.month;
    final enabled =
        inMonth && !date.isBefore(widget.today) && !date.isAfter(lastDay);
    final isStart = _same(start, date);
    final isEnd = _same(end, date);
    final inRange = start != null &&
        end != null &&
        !date.isBefore(start!) &&
        !date.isAfter(end!);
    final endpoint = isStart || isEnd;
    final radius = BorderRadius.horizontal(
      left: Radius.circular(isStart ? 22 : 6),
      right: Radius.circular(isEnd ? 22 : 6),
    );
    final isToday = _same(widget.today, date);
    return Semantics(
      button: enabled,
      selected: endpoint,
      label: MaterialLocalizations.of(context).formatFullDate(date),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: inRange ? AppTheme.mint : Colors.transparent,
            borderRadius: radius,
          ),
          child: SizedBox(
              height: 44,
              child: Center(
                  child: Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: enabled ? () => select(date) : null,
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: endpoint ? AppTheme.primary : Colors.transparent,
                      shape: BoxShape.circle,
                      border: isToday && !endpoint
                          ? Border.all(color: AppTheme.primary, width: 1.5)
                          : null,
                    ),
                    child: Text('${date.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: endpoint || isToday
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: endpoint
                              ? Colors.white
                              : enabled
                                  ? AppTheme.textPrimary
                                  : AppTheme.textMuted,
                        )),
                  ),
                ),
              ))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final local = MaterialLocalizations.of(context);
    String label(DateTime? date) =>
        date == null ? 'Choose date' : local.formatMediumDate(date);
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: 480, maxHeight: MediaQuery.sizeOf(context).height * .9),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Make time for an adventure',
                      style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          height: 1.2)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: AppTheme.mint,
                        borderRadius: BorderRadius.circular(16)),
                    child: Wrap(spacing: 12, runSpacing: 10, children: [
                      _dateSummary(
                          'START', label(start), Icons.flight_takeoff_rounded),
                      _dateSummary(
                          'END', label(end), Icons.flight_land_rounded),
                      if (start != null && end != null)
                        Chip(
                            avatar: const Icon(Icons.nights_stay_outlined,
                                size: 16),
                            label: Text('${days(start!, end!)} days'),
                            backgroundColor: Colors.white),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Text(
                      start == null || changingStart
                          ? 'Choose your arrival date to get started.'
                          : 'Choose your return date. The full trip will light up as you select it.',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, height: 1.4)),
                  Wrap(spacing: 6, children: [
                    if (start != null)
                      TextButton.icon(
                          onPressed: () => setState(() {
                                changingStart = true;
                                error = null;
                              }),
                          icon: const Icon(Icons.edit_calendar_outlined),
                          label: const Text('Change start')),
                    if (start != null && !changingStart)
                      TextButton(
                          onPressed: () => setState(() {
                                end = start;
                                error = null;
                              }),
                          child: const Text('Just one day')),
                  ]),
                  const SizedBox(height: 4),
                  _calendar(context),
                  if (error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(error!,
                            style: const TextStyle(color: AppTheme.error))),
                  const SizedBox(height: 12),
                  Wrap(alignment: WrapAlignment.end, spacing: 12, children: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    ElevatedButton.icon(
                        onPressed: start == null || end == null || changingStart
                            ? null
                            : () => Navigator.pop(context,
                                DateTimeRange(start: start!, end: end!)),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Use these dates')),
                  ]),
                ]),
          ),
        ),
      ),
    );
  }

  Widget _dateSummary(String title, String value, IconData icon) => Container(
        constraints: const BoxConstraints(minWidth: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 17, color: AppTheme.teal),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ]),
      );
}
