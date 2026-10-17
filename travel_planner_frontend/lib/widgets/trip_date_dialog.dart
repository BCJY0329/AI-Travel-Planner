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
  bool changingStart = false;
  String? error;
  @override
  void initState() {
    super.initState();
    start = widget.initial?.start;
    end = widget.initial?.end;
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
  @override
  Widget build(BuildContext context) {
    final local = MaterialLocalizations.of(context);
    String label(DateTime? date) =>
        date == null ? 'Choose date' : local.formatMediumDate(date);
    return Dialog(
        child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: 460,
                maxHeight: MediaQuery.sizeOf(context).height * .9),
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Make time for an adventure',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: AppTheme.mint,
                                  borderRadius: BorderRadius.circular(14)),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Start: ${label(start)}'),
                                    const SizedBox(height: 6),
                                    Text('End: ${label(end)}'),
                                    if (start != null && end != null)
                                      Text(
                                          '${days(start!, end!)} days, including arrival and departure',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                  ])),
                          const SizedBox(height: 8),
                          Text(start == null || changingStart
                              ? 'Choose your start date.'
                              : 'Choose an end date. Tap another day to adjust it.'),
                          if (start != null)
                            Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                    onPressed: () => setState(() {
                                          changingStart = true;
                                          error = null;
                                        }),
                                    icon: const Icon(
                                        Icons.edit_calendar_outlined),
                                    label: const Text('Change start'))),
                          if (start != null && !changingStart)
                            TextButton(
                                onPressed: () => setState(() {
                                      end = start;
                                      error = null;
                                    }),
                                child: const Text('Just this day')),
                          CalendarDatePicker(
                              initialDate: widget.initial?.end,
                              currentDate: widget.today,
                              firstDate: widget.today,
                              lastDate:
                                  DateUtils.addDaysToDate(widget.today, 730),
                              onDateChanged: select),
                          if (error != null)
                            Text(error!,
                                style: const TextStyle(color: AppTheme.error)),
                          Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 12,
                              children: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel')),
                                ElevatedButton(
                                    onPressed: start == null ||
                                            end == null ||
                                            changingStart
                                        ? null
                                        : () => Navigator.pop(
                                            context,
                                            DateTimeRange(
                                                start: start!, end: end!)),
                                    child: const Text('Use these dates')),
                              ]),
                        ])))));
  }
}
