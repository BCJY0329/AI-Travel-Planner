import '../models/itinerary_models.dart';
import '../models/media_models.dart';

enum ChatSender { bot, user }

enum ChatMessageType {
  text,
  quickReplies,
  datePicker,
  itinerary,
  loading,

  /// Lemon's popular spots as buttons (DECISIONS 069).
  spots,

  /// A changed day to accept or turn down (DECISIONS 069).
  editPreview,

  /// Places found in photos or links, as a checklist (DECISIONS 073).
  media,
}

/// Places Lemon found in photos or links, waiting for "Add selected"
/// (DECISIONS 073). Nothing joins the trip without that tap.
class MediaFinding {
  final List<MediaCandidate> candidates;

  /// With no destination yet: the city Lemon offers to plan ("Kyoto, Japan").
  final String? suggestedDestination;

  /// Indexes of the ticked candidates.
  final Set<int> selected;

  /// 'pending', 'added' or 'dismissed'. Only a pending finding has buttons.
  String state = 'pending';

  /// The "Plan a trip to …?" question was answered.
  bool offerAnswered = false;

  MediaFinding(this.candidates, {this.suggestedDestination, bool hasDestination = true})
      : selected = {
          for (final (i, c) in candidates.indexed)
            if (_startsTicked(c, suggestedDestination, hasDestination)) i
        };

  /// Map-confirmed places in the destination start ticked; places in another
  /// city (a day trip), unchecked and maybe-places wait for a tap.
  static bool _startsTicked(MediaCandidate c, String? suggested, bool hasDestination) {
    if (c.status != 'verified') return false;
    if (hasDestination) return c.inDestination != false;
    final city = suggested?.split(',').first.trim().toLowerCase();
    return city != null && (c.city ?? '').trim().toLowerCase() == city;
  }

  String? get suggestedCity => suggestedDestination?.split(',').first.trim();
}

/// A changed day waiting for "Use this" / "Keep old" (DECISIONS 069).
class EditPreview {
  final PlanEdit edit;
  final ItineraryDay oldDay;
  final ItineraryDay newDay;
  final String providerUsed;

  /// Must-visits this day no longer has (DECISIONS 070).
  final List<String> missingMustVisits;

  /// 'pending', 'accepted' or 'kept'. Only a pending preview has buttons.
  String state = 'pending';

  EditPreview(
      {required this.edit,
      required this.oldDay,
      required this.newDay,
      required this.providerUsed,
      this.missingMustVisits = const []});

  bool get isDemo => providerUsed == 'mock';
}

class ChatMessage {
  final ChatSender sender;
  final ChatMessageType type;
  final String? text;
  final List<String>? quickReplies;
  final ItineraryResponse? itinerary;

  /// [ChatMessageType.spots]: the spots shown as buttons.
  final List<PopularSpot> spots;

  /// [ChatMessageType.editPreview]: the day to accept or turn down.
  final EditPreview? preview;

  /// A traveller's message with photos (shown in the bubble, never stored).
  final List<PickedPhoto> photos;

  /// [ChatMessageType.media]: the places to choose from.
  final MediaFinding? finding;

  /// Only used for [ChatMessageType.datePicker]: the earliest date the user
  /// should be allowed to pick. Null means "no lower bound beyond today"
  /// (used for the first/departure date). When asking for the return date,
  /// this is set to the day after the already-chosen departure date so the
  /// calendar can't show dates before it.
  final DateTime? minDate;

  ChatMessage._({
    required this.sender,
    required this.type,
    this.text,
    this.quickReplies,
    this.itinerary,
    this.minDate,
    this.spots = const [],
    this.preview,
    this.photos = const [],
    this.finding,
  });

  factory ChatMessage.text(ChatSender sender, String text) =>
      ChatMessage._(sender: sender, type: ChatMessageType.text, text: text);

  factory ChatMessage.quickReplies(String prompt, List<String> options) =>
      ChatMessage._(
        sender: ChatSender.bot,
        type: ChatMessageType.quickReplies,
        text: prompt,
        quickReplies: options,
      );

  factory ChatMessage.datePickerPrompt(String prompt, {DateTime? minDate}) =>
      ChatMessage._(
        sender: ChatSender.bot,
        type: ChatMessageType.datePicker,
        text: prompt,
        minDate: minDate,
      );

  factory ChatMessage.itineraryResult(ItineraryResponse itinerary) =>
      ChatMessage._(
          sender: ChatSender.bot,
          type: ChatMessageType.itinerary,
          itinerary: itinerary);

  factory ChatMessage.loading([String label = 'Lemon is thinking...']) =>
      ChatMessage._(
        sender: ChatSender.bot,
        type: ChatMessageType.loading,
        text: label,
      );

  factory ChatMessage.spotList(String prompt, List<PopularSpot> spots) =>
      ChatMessage._(
          sender: ChatSender.bot,
          type: ChatMessageType.spots,
          text: prompt,
          spots: List.unmodifiable(spots));

  factory ChatMessage.userPhotos(String text, List<PickedPhoto> photos) =>
      ChatMessage._(
          sender: ChatSender.user,
          type: ChatMessageType.text,
          text: text,
          photos: List.unmodifiable(photos));

  factory ChatMessage.mediaResult(String prompt, MediaFinding finding) =>
      ChatMessage._(
          sender: ChatSender.bot,
          type: ChatMessageType.media,
          text: prompt,
          finding: finding);

  factory ChatMessage.editPreview(String prompt, EditPreview preview) =>
      ChatMessage._(
          sender: ChatSender.bot,
          type: ChatMessageType.editPreview,
          text: prompt,
          preview: preview);
}
