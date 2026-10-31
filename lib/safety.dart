// First-line crisis detector & emergency hotline directory.
// Safety NET: Designed to catch explicit and implicit distress signals.
// Review with mental health professionals and local crisis hotlines.

class Hotline {
  final String label;
  final String number;
  final String country;
  final String description;
  final String? url;

  const Hotline({
    required this.label,
    required this.number,
    required this.country,
    this.description = '',
    this.url,
  });
}

const List<Hotline> allHotlines = [
  // Tunisia
  Hotline(
    label: 'Tunisie – SAMU Urgences',
    number: '190',
    country: 'TN',
    description: 'Secours médicaux et psychiatriques 24/7',
  ),
  Hotline(
    label: 'Tunisie – Protection Civile',
    number: '198',
    country: 'TN',
    description: 'Secours d\'urgence',
  ),
  Hotline(
    label: 'Tunisie – Allô Écoute',
    number: '80105050',
    country: 'TN',
    description: 'Ligne verte d\'écoute psychologique',
  ),

  // Algeria
  Hotline(
    label: 'Algérie – SAMU Urgences',
    number: '1021',
    country: 'DZ',
    description: 'Urgences médicales 24/7',
  ),
  Hotline(
    label: 'Algérie – Protection Civile',
    number: '14',
    country: 'DZ',
    description: 'Secours d\'urgence',
  ),

  // Morocco
  Hotline(
    label: 'Maroc – Urgences Médicales SAMU',
    number: '141',
    country: 'MA',
    description: 'Secours et urgences médicales',
  ),
  Hotline(
    label: 'Maroc – Protection Civile',
    number: '15',
    country: 'MA',
    description: 'Secours d\'urgence',
  ),
  Hotline(
    label: 'Maroc – SOS Amitié & Écoute',
    number: '0522262626',
    country: 'MA',
    description: 'Écoute et soutien psychologique',
  ),

  // Egypt
  Hotline(
    label: 'مصر – الأمانة العامة للصحة النفسية',
    number: '08008880700',
    country: 'EG',
    description: 'الخط الساخن للدعم النفسي والاستشارات',
  ),
  Hotline(
    label: 'مصر – الإسعاف والطوارئ',
    number: '123',
    country: 'EG',
    description: 'طوارئ الإسعاف الطبي',
  ),

  // Saudi Arabia
  Hotline(
    label: 'السعودية – مركز تعزيز الصحة النفسية',
    number: '920033360',
    country: 'SA',
    description: 'استشارات نفسية هاتفية مجانية وسرية',
  ),
  Hotline(
    label: 'السعودية – الهلال الأحمر',
    number: '997',
    country: 'SA',
    description: 'الإسعاف والطوارئ الطبية 24/7',
  ),

  // UAE
  Hotline(
    label: 'الإمارات – خط الأمل للصحة النفسية',
    number: '8004673',
    country: 'AE',
    description: 'الدعم النفسي المجاني من وزارة تنمية المجتمع',
  ),
  Hotline(
    label: 'الإمارات – الإسعاف الوطني',
    number: '998',
    country: 'AE',
    description: 'طوارئ الإسعاف',
  ),

  // Lebanon
  Hotline(
    label: 'لبنان – خط الحياة Embrace LifeLine',
    number: '1564',
    country: 'LB',
    description: 'دعم نفسي للوقاية من الانتحار 24/7',
  ),
  Hotline(
    label: 'لبنان – الصليب الأحمر',
    number: '140',
    country: 'LB',
    description: 'إسعاف وطوارئ',
  ),

  // Jordan
  Hotline(
    label: 'الأردن – الخط الوطني للدعم النفسي',
    number: '111',
    country: 'JO',
    description: 'استشارات الدعم النفسي والاجتماعي',
  ),
  Hotline(
    label: 'الأردن – طوارئ الدفاع المدني',
    number: '911',
    country: 'JO',
    description: 'رقم الطوارئ الموحد',
  ),

  // Qatar
  Hotline(
    label: 'قطر – خط المساعدة للصحة النفسية',
    number: '16000',
    country: 'QA',
    description: 'مؤسسة حمد الطبية - اختيار الدعم النفسي',
  ),

  // France
  Hotline(
    label: 'France – 3114 Prévention Suicide',
    number: '3114',
    country: 'FR',
    description: 'Ligne nationale gratuite et confidentielle 24/7',
  ),
  Hotline(
    label: 'France – SAMU Urgences',
    number: '15',
    country: 'FR',
    description: 'Urgences médicales (ou 112 en Europe)',
  ),
  Hotline(
    label: 'France – SOS Amitié',
    number: '0972394050',
    country: 'FR',
    description: 'Écoute bienveillante 24/7',
  ),

  // Belgium
  Hotline(
    label: 'Belgique – Centre Prévention Suicide',
    number: '1813',
    country: 'BE',
    description: 'Numéro gratuit 24/7',
  ),
  Hotline(
    label: 'Belgique – Urgences Européennes',
    number: '112',
    country: 'BE',
    description: 'Secours médicaux',
  ),

  // Switzerland
  Hotline(
    label: 'Suisse – La Main Tendue',
    number: '143',
    country: 'CH',
    description: 'Écoute et soutien anonyme 24/7',
  ),
  Hotline(
    label: 'Suisse – Urgences Médicales',
    number: '144',
    country: 'CH',
    description: 'Ambulances et secours d\'urgence',
  ),

  // Canada
  Hotline(
    label: 'Canada – 9-8-8 Ligne de crise suicide',
    number: '988',
    country: 'CA',
    description: 'Appel ou SMS gratuit 24/7 en français et anglais',
  ),
  Hotline(
    label: 'Canada – Jeunesse, J\'écoute',
    number: '18006686868',
    country: 'CA',
    description: 'Soutien 24/7 pour les jeunes',
  ),

  // USA
  Hotline(
    label: 'USA – 988 Suicide & Crisis Lifeline',
    number: '988',
    country: 'US',
    description: 'Free, confidential 24/7 call or text',
  ),
  Hotline(
    label: 'USA – Crisis Text Line',
    number: '741741',
    country: 'US',
    description: 'Text HOME to 741741 to connect with a Crisis Counselor',
  ),

  // UK
  Hotline(
    label: 'UK – Samaritans',
    number: '116123',
    country: 'GB',
    description: 'Free emotional support 24/7',
  ),
  Hotline(
    label: 'UK – NHS Emergency',
    number: '111',
    country: 'GB',
    description: 'Urgent medical and mental health support',
  ),

  // Global / International fallback
  Hotline(
    label: 'International – Find A Helpline',
    number: '',
    country: 'GLOBAL',
    description: 'Free, confidential support from local crisis centers worldwide',
    url: 'https://findahelpline.com',
  ),
  Hotline(
    label: 'International – Befrienders Worldwide',
    number: '',
    country: 'GLOBAL',
    description: 'Global emotional support and suicide prevention network',
    url: 'https://www.befrienders.org',
  ),
];

const Map<String, String> supportedCountries = {
  'TN': 'Tunisie (تونس)',
  'DZ': 'Algérie (الجزائر)',
  'MA': 'Maroc (المغرب)',
  'EG': 'Egypt (مصر)',
  'SA': 'Saudi Arabia (السعودية)',
  'AE': 'UAE (الإمارات)',
  'LB': 'Lebanon (لبنان)',
  'JO': 'Jordan (الأردن)',
  'QA': 'Qatar (قطر)',
  'FR': 'France',
  'BE': 'Belgique / België',
  'CH': 'Suisse / Schweiz',
  'CA': 'Canada',
  'US': 'United States',
  'GB': 'United Kingdom',
  'GLOBAL': 'International / Other',
};

// Backwards compatibility alias
List<Hotline> get hotlines => allHotlines;

List<Hotline> hotlinesForCountry(String countryCode) {
  final filtered = allHotlines.where((h) => h.country == countryCode).toList();
  if (filtered.isEmpty) {
    return allHotlines.where((h) => h.country == 'GLOBAL' || h.country == 'TN' || h.country == 'FR').toList();
  }
  // Append global help directories
  final global = allHotlines.where((h) => h.country == 'GLOBAL').toList();
  return [...filtered, ...global];
}

final List<RegExp> _patterns = [
  // English
  RegExp(
    r"\b(kill myself|end my life|want to die|suicid|don'?t want to live|better off dead|hang myself|overdose|cut my wrists|take my life|tired of living|end(?:ing)? it all|can'?t go on anymore)\b",
    caseSensitive: false,
  ),
  // French
  RegExp(
    r"(me tuer|en finir|veux mourir|envie de mourir|suicid|plus envie de vivre|mettre fin à mes jours|m'ôter la vie|disparaître à jamais|me foutre en l'air|en terminer|plus la force de vivre)",
    caseSensitive: false,
  ),
  // Arabic (Standard & Dialects)
  RegExp(
    r"(انتحار|أنتحر|انتحر|اقتل نفسي|أقتل نفسي|أريد أن أموت|اريد ان اموت|بدي موت|بدي اموت|عاوز اموت|عايز اموت|ابغي نموت|نحب نموت|نقتل روحي|نموت ونرتاح|حياتي ملهاش لازمة|كرهت حياتي|أنهي حياتي|انهي حياتي|مش قادر اعيش|ماليش لازمة|ما عاد فيني عيش)",
  ),
  // Arabizi / Latinized dialect transcriptions
  RegExp(
    r"\b(nheb nmout|n9atel rouhi|nektel rouhi|nmout w nertah|baddi mout|3ayez amout|kareht hyati|mabghitsh n3ich|krahit 7yati|mout)\b",
    caseSensitive: false,
  ),
];

bool isCrisis(String text) => _patterns.any((p) => p.hasMatch(text));
