/// Photos shown on the Discover page.
///
/// To use your own picture, put the file in `assets/images/photos/` (the whole
/// folder is bundled by pubspec.yaml), point [DiscoverPhoto.asset] at it and
/// update or clear its [DiscoverPhoto.credit].
class DiscoverPhoto {
  final String asset;
  final String description;
  final String credit;
  const DiscoverPhoto(
      {required this.asset, required this.description, this.credit = ''});
}

class DiscoverDestination {
  final String name;
  final String country;
  final String tagline;
  final DiscoverPhoto photo;
  const DiscoverDestination(
      {required this.name,
      required this.country,
      required this.tagline,
      required this.photo});
}

class DiscoverContent {
  static const hero = DiscoverPhoto(
      asset: 'assets/images/photos/hero.jpg',
      description: 'Positano on the Amalfi Coast, Italy',
      credit: 'Positano: Wiki.Bianco, CC BY-SA 4.0');
  static const flights = DiscoverPhoto(
      asset: 'assets/images/photos/flight.jpg',
      description: 'Sunset over clouds from an airplane window',
      credit: 'Airplane window: Salwa Farwaneh Dameh, CC0');
  static const stays = DiscoverPhoto(
      asset: 'assets/images/photos/santorini.jpg',
      description: 'A terrace overlooking the sea in Oia, Santorini',
      credit: 'Oia, Santorini: Anna.Tsolidou, CC BY-SA 4.0');
  static const sights = DiscoverPhoto(
      asset: 'assets/images/photos/kyoto.jpg',
      description: 'Torii gate paths at Fushimi Inari Taisha, Kyoto',
      credit: 'Fushimi Inari: Basile Morin, CC BY-SA 4.0');

  static const destinations = [
    DiscoverDestination(
        name: 'Tokyo',
        country: 'Japan',
        tagline: 'Culture & food',
        photo: DiscoverPhoto(
            asset: 'assets/images/photos/tokyo.jpg',
            description: 'Shibuya Crossing at night, Tokyo',
            credit: 'Shibuya Crossing: David Kernan, CC BY 4.0')),
    DiscoverDestination(
        name: 'Bali',
        country: 'Indonesia',
        tagline: 'Beaches & nature',
        photo: DiscoverPhoto(
            asset: 'assets/images/photos/bali.jpg',
            description: 'Tegallalang rice terraces, Bali',
            credit: 'Bali rice terraces: Vyacheslav Argenberg, CC BY 4.0')),
    DiscoverDestination(
        name: 'Paris',
        country: 'France',
        tagline: 'Art & city walks',
        photo: DiscoverPhoto(
            asset: 'assets/images/photos/paris.jpg',
            description: 'The Eiffel Tower seen from the Trocadéro, Paris',
            credit: 'Eiffel Tower: NonOmnisMoriar, CC BY-SA 3.0')),
    DiscoverDestination(
        name: 'Rome',
        country: 'Italy',
        tagline: 'History & discovery',
        photo: DiscoverPhoto(
            asset: 'assets/images/photos/rome.jpg',
            description: 'The Colosseum, Rome',
            credit: 'Colosseum: Acediscovery, CC BY 4.0')),
  ];

  /// A photo of [place] when one of the pictures above shows it, else null.
  /// Other pages use this so a city never gets someone else's photo.
  static DiscoverPhoto? photoForPlace(String place) {
    final name = place.trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final destination in destinations) {
      if (name.contains(destination.name.toLowerCase())) {
        return destination.photo;
      }
    }
    if (name.contains('kyoto')) return sights;
    if (name.contains('santorini')) return stays;
    return null;
  }

  /// Credits for every photo above, shown at the foot of Discover.
  static List<String> get credits => [
        for (final photo in [
          hero,
          flights,
          stays,
          sights,
          for (final place in destinations) place.photo
        ])
          if (photo.credit.isNotEmpty) photo.credit
      ];
}
