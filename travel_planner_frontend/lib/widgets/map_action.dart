import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'map_link.dart';

class MapAction extends StatelessWidget {
  final double? lat, lon;
  const MapAction({super.key, this.lat, this.lon});
  @override
  Widget build(BuildContext context) {
    if (lat == null ||
        lon == null ||
        !lat!.isFinite ||
        !lon!.isFinite ||
        lat!.abs() > 90 ||
        lon!.abs() > 180) {
      return const SizedBox.shrink();
    }
    final url = Uri.https('www.google.com', '/maps/search/',
        {'api': '1', 'query': '$lat,$lon'}).toString();
    return TextButton.icon(
        icon: const Icon(Icons.map_outlined, size: 18),
        label: const Text('View location'),
        onPressed: () {
          if (!openMapUrl(url)) {
            showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                        title: const Text('Location on Google Maps'),
                        content: SelectableText(url),
                        actions: [
                          TextButton(
                              onPressed: () async {
                                try {
                                  await Clipboard.setData(
                                      ClipboardData(text: url));
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('Map link copied')));
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Could not copy the link. Select the address to copy it.')));
                                  }
                                }
                              },
                              child: const Text('Copy map link')),
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'))
                        ]));
          }
        });
  }
}
