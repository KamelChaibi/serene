/// Personalization profile collected once during first-launch onboarding.
///
/// Everything here lives in memory for the current session (see
/// [Store.profile]) and disappears when the app closes. Only
/// the derived age — never the raw birthday — is shared with the AI so it can
/// adapt its words without learning the exact date.
class Profile {
  static const styleWarm = 'warm';
  static const styleFriend = 'friend';
  static const styleDirect = 'direct';

  static const lengthShort = 'short';
  static const lengthBalanced = 'balanced';
  static const lengthDeep = 'deep';

  /// Focus areas the user can ask support for. Keys map to l10n strings
  /// (`focusAnxiety`, `focusMood`, …).
  static const focusKeys = <String>[
    'anxiety',
    'mood',
    'sleep',
    'relationships',
    'selfEsteem',
    'grief',
    'stress',
    'purpose',
  ];

  final String name;
  final DateTime? birthday;
  final String style;
  final String length;
  final List<String> focuses;
  final bool inTherapy;
  final String notes;

  const Profile({
    this.name = '',
    this.birthday,
    this.style = styleWarm,
    this.length = lengthBalanced,
    this.focuses = const [],
    this.inTherapy = false,
    this.notes = '',
  });

  static const empty = Profile();

  String get trimmedName => name.trim();

  /// Age in whole years, or null when no birthday was provided.
  int? get age {
    final b = birthday;
    if (b == null) return null;
    final now = DateTime.now();
    var years = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) {
      years--;
    }
    if (years < 0 || years > 120) return null;
    return years;
  }

  bool get isMinor => age != null && age! < 18;

  /// True when the user actually shared something worth personalizing.
  /// A skipped onboarding leaves all of this at its defaults.
  bool get hasPreferences =>
      trimmedName.isNotEmpty ||
      birthday != null ||
      style != styleWarm ||
      length != lengthBalanced ||
      focuses.isNotEmpty ||
      inTherapy ||
      notes.trim().isNotEmpty;

  Profile copyWith({
    String? name,
    DateTime? birthday,
    bool clearBirthday = false,
    String? style,
    String? length,
    List<String>? focuses,
    bool? inTherapy,
    String? notes,
  }) {
    return Profile(
      name: name ?? this.name,
      birthday: clearBirthday ? null : (birthday ?? this.birthday),
      style: style ?? this.style,
      length: length ?? this.length,
      focuses: focuses ?? this.focuses,
      inTherapy: inTherapy ?? this.inTherapy,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'birthday': birthday?.toIso8601String().substring(0, 10),
        'style': style,
        'length': length,
        'focuses': focuses,
        'in_therapy': inTherapy,
        'notes': notes,
      };

  factory Profile.fromJson(Map<String, dynamic> json) {
    final rawStyle = json['style'];
    final rawLength = json['length'];
    final rawFocuses = json['focuses'];

    return Profile(
      name: (json['name'] as String? ?? '').trim(),
      birthday: DateTime.tryParse(json['birthday'] as String? ?? ''),
      style: rawStyle == styleFriend || rawStyle == styleDirect
          ? rawStyle as String
          : styleWarm,
      length: rawLength == lengthShort || rawLength == lengthDeep
          ? rawLength as String
          : lengthBalanced,
      focuses: rawFocuses is List
          ? rawFocuses
              .whereType<String>()
              .where(focusKeys.contains)
              .toList(growable: false)
          : const [],
      inTherapy: json['in_therapy'] == true,
      notes: (json['notes'] as String? ?? '').trim(),
    );
  }

  /// Payload sent to the AI proxy. Deliberately omits the raw birthday.
  Map<String, dynamic> toPromptMap() => {
        if (trimmedName.isNotEmpty) 'name': trimmedName,
        if (age != null) 'age': age,
        'style': style,
        'length': length,
        if (focuses.isNotEmpty) 'focuses': focuses,
        if (inTherapy) 'in_therapy': true,
        if (notes.trim().isNotEmpty) 'notes': notes.trim(),
      };
}
