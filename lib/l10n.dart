import 'package:flutter/material.dart';

const Map<String, Map<String, String>> _strings = {
  'en': {
    'title': 'Serene',
    'tagline': 'Your safe, private mental wellness companion',
    'chat': 'Chat',
    'checkin': 'Mood',
    'breathe': 'Breathe',
    'grounding': 'Grounding',
    'journal': 'Journal',
    'settings': 'Emergency & Privacy',

    // Chat
    'hint': 'Write what is on your mind…',
    'send': 'Send',
    'stopGenerating': 'Stop generating',
    'disclaimer': 'I am an AI companion, not a therapist or doctor. In a medical or psychiatric crisis, please connect with a human immediately.',
    'error': 'Connection problem. Please try again in a moment.',
    'empty': 'Nothing saved yet.',
    'thinking': 'Serene is reflecting…',
    'privacyShield': 'Quick Privacy Shield',
    'shieldActivated': 'Privacy Shield Active. Tap anywhere to unlock.',
    'shieldQuote': 'Take a breath. You are safe here.',

    // Icebreakers
    'promptOverwhelmed': 'I feel completely overwhelmed right now',
    'promptSleep': 'I cannot sleep and my thoughts are racing',
    'promptLonely': 'I feel deeply lonely today',
    'promptCalm': 'Can you guide me through a calming exercise?',

    // Crisis
    'crisisTitle': 'You are not alone. Your life matters.',
    'crisisSubtitle': 'We care deeply about your safety. Please connect with someone who can support you right now.',
    'call': 'Call',
    'trustedContact': 'Call My Trusted Contact',
    'noTrustedContact': 'No trusted contact set. You can add one in Emergency & Privacy settings.',
    'selectCountry': 'Country hotlines:',
    'visitWebsite': 'Visit Support Website',
    'crisisBreathing': 'Take a gentle breath with me',
    'close': 'I am safe for now',

    // Onboarding Gate
    'welcomeTitle': 'Welcome to Serene',
    'welcomeBody': 'Serene is a 100% free, private wellness companion.\n\n• It is an AI listener, not a therapist, and cannot manage emergency crises.\n• Chats are held in temporary memory and are never saved to your device or logged on our servers.\n• Your memories, mood check-ins, and journal entries are strictly encrypted on your phone using Android Keystore.\n• You maintain 100% ownership and can delete your data at any time.\n\nIf you ever feel unsafe or have thoughts of self-harm, please reach out to emergency services or someone you trust.',
    'accept': 'I understand & wish to enter',

    // Security & Lock
    'securityLock': 'App Security & PIN Lock',
    'securityDesc': 'Secure Serene with a 4-digit PIN and biometrics (Fingerprint / Face ID).',
    'pinLock': '4-Digit PIN Lock',
    'enablePin': 'Set PIN',
    'changePin': 'Change PIN',
    'disablePin': 'Remove PIN',
    'biometrics': 'Biometric Unlock',
    'biometricsDesc': 'Unlock using your fingerprint or face recognition.',
    'enterNewPin': 'Enter a 4-digit PIN',
    'confirmPin': 'Confirm your PIN',
    'pinMismatch': 'PINs do not match. Please try again.',
    'pinSetSuccess': 'PIN lock enabled successfully.',
    'pinRemoved': 'PIN lock disabled.',

    // Reminders & Notifications
    'reminders': 'Mindful Reminders',
    'remindersDesc': 'Receive gentle, soothing daily check-ins on your phone.',
    'dailyReminder': 'Daily Wellness Check-in',
    'reminderTime': 'Reminder Time',
    'testNotification': 'Send Test Affirmation',
    'notificationSent': 'Notification sent! Check your notification bar.',

    // Automatic Memory Suggestions
    'memorySuggestionTitle': '💡 Would you like Serene to remember this?',
    'remember': 'Remember',
    'dismiss': 'Not now',
    'memorySaved': 'Saved to your private encrypted memories.',

    // Memories
    'memories': 'Saved Memories',
    'memHint': 'Add something you want Serene to remember (e.g. "I love painting")',
    'useMem': 'Allow Serene to remember these details',
    'wipe': 'Delete all my data permanently',
    'wipeConfirm': 'Are you sure you want to permanently delete all local encrypted memories, mood logs, and journal entries? This cannot be undone.',
    'confirm': 'Delete All',
    'cancel': 'Cancel',

    // Trusted contact
    'trustedTitle': 'Emergency Trusted Contact',
    'trustedDesc': 'Save a close friend, family member, or counselor you can instantly call during distress.',
    'contactName': 'Contact Name',
    'contactPhone': 'Phone Number',
    'saveContact': 'Save Contact',
    'removeContact': 'Remove Contact',

    // Mood & Wellness
    'howFeel': 'How are you feeling right now?',
    'note': 'Add a note or reflection (optional)',
    'save': 'Save Check-in',
    'last': 'Your Last 14 Check-ins',
    'moodTags': 'What is contributing to how you feel?',
    'tagAnxiety': 'Anxiety',
    'tagWork': 'Work / School',
    'tagFamily': 'Relationships',
    'tagSleep': 'Sleep',
    'tagLoneliness': 'Loneliness',
    'tagHope': 'Hopeful',
    'tagBurnout': 'Exhaustion',

    // Breathing Studio
    'breathingStudio': 'Guided Breathing Studio',
    'modeCalm': 'Calming Pace (4-6)',
    'modeBox': 'Box Breathing (4-4-4-4)',
    'mode478': 'Deep Rest (4-7-8)',
    'inhale': 'Breathe In…',
    'hold': 'Hold gently…',
    'exhale': 'Breathe Out slowly…',
    'start': 'Begin Breathing',
    'stop': 'Stop',

    // 5-4-3-2-1 Grounding
    'groundingTitle': '5-4-3-2-1 Grounding Exercise',
    'groundingIntro': 'When panic, dissociation, or racing thoughts overwhelm you, this evidence-based sensory technique brings you safely back to the present moment.',
    'step5': 'Look around and name 5 things you can SEE.',
    'step5Hint': 'A pattern on the floor, the light on the wall, your shoes, a plant, a shadow…',
    'step4': 'Notice 4 things you can physically TOUCH.',
    'step4Hint': 'The fabric of your clothes, the coolness of a desk, your feet firmly on the ground…',
    'step3': 'Listen carefully for 3 things you can HEAR.',
    'step3Hint': 'A distant car, the hum of air, your own breathing, birds outside…',
    'step2': 'Identify 2 things you can SMELL.',
    'step2Hint': 'Fresh air, coffee, your shampoo, or imagine your favorite comforting aroma…',
    'step1': 'Notice 1 thing you can TASTE or say 1 kind truth to yourself.',
    'step1Hint': 'Take a sip of cool water, or repeat: "I am safe right now. This feeling will pass."',
    'nextStep': 'Next Step',
    'prevStep': 'Previous',
    'groundingDone': 'I Feel More Grounded',
    'groundingComplete': 'Well done. Take a gentle breath. You made it back to the present moment.',

    // Journal
    'writeHere': 'Write freely. This space is encrypted and only for your eyes.',
    'noEntries': 'No entries yet. Write your thoughts whenever you need to release them.',
    'journalPrompt1': 'What is one heavy thought you want to let go of today?',
    'journalPrompt2': 'What is something small that brought you a sliver of peace?',
    'journalPrompt3': 'What do you need most from yourself right now?',
  },

  'fr': {
    'title': 'Serene',
    'tagline': 'Votre compagnon bienveillant de bien-être mental',
    'chat': 'Discussion',
    'checkin': 'Humeur',
    'breathe': 'Respirer',
    'grounding': 'Ancrage',
    'journal': 'Journal',
    'settings': 'Urgence & Vie Privée',

    // Chat
    'hint': 'Écris ce que tu as sur le cœur…',
    'send': 'Envoyer',
    'stopGenerating': 'Arrêter',
    'disclaimer': 'Je suis une IA de soutien, pas un thérapeute ni un médecin. En cas d\'urgence vitale ou psychiatrique, contacte immédiatement un humain.',
    'error': 'Problème de connexion. Merci de réessayer dans un instant.',
    'empty': 'Rien d\'enregistré pour le moment.',
    'thinking': 'Serene prend le temps de te répondre…',
    'privacyShield': 'Bouclier de confidentialité rapide',
    'shieldActivated': 'Écran de confidentialité actif. Touche n\'importe où pour déverrouiller.',
    'shieldQuote': 'Prends une grande inspiration. Tu es en sécurité ici.',

    // Icebreakers
    'promptOverwhelmed': 'Je me sens complètement submergé(e) en ce moment',
    'promptSleep': 'Je n\'arrive pas à dormir et mes pensées tournent en boucle',
    'promptLonely': 'Je ressens une profonde solitude aujourd\'hui',
    'promptCalm': 'Peux-tu me guider dans un exercice pour me calmer ?',

    // Crisis
    'crisisTitle': 'Tu n\'es pas seul(e). Ta vie compte.',
    'crisisSubtitle': 'Ta sécurité nous tient profondément à cœur. Contacte quelqu\'un qui peut t\'aider dès maintenant.',
    'call': 'Appeler',
    'trustedContact': 'Appeler mon contact de confiance',
    'noTrustedContact': 'Aucun contact de confiance défini. Tu peux en ajouter un dans les paramètres.',
    'selectCountry': 'Lignes d\'écoute par pays :',
    'visitWebsite': 'Consulter le site de soutien',
    'crisisBreathing': 'Respirer doucement ensemble',
    'close': 'Je me sens en sécurité pour l\'instant',

    // Onboarding Gate
    'welcomeTitle': 'Bienvenue dans Serene',
    'welcomeBody': 'Serene est un compagnon de bien-être 100 % gratuit et respectueux de ta vie privée.\n\n• C\'est une présence d\'écoute bienveillante par IA, pas un thérapeute, et il ne traite pas les urgences.\n• Les discussions sont éphémères en mémoire vive : elles ne sont jamais sauvegardées sur ton téléphone ni enregistrées sur nos serveurs.\n• Tes souvenirs, humeurs et entrées de journal restent chiffrés sur ton téléphone grâce à l\'Android Keystore.\n• Tu conserves le contrôle absolu et peux supprimer tes données à tout instant.\n\nSi tu es en danger ou si tu as des pensées sombres, appelle les secours ou une personne de confiance.',
    'accept': 'J\'ai compris et je souhaite entrer',

    // Security & Lock
    'securityLock': 'Sécurité & Verrouillage PIN',
    'securityDesc': 'Protégez Serene avec un code PIN à 4 chiffres et la biométrie.',
    'pinLock': 'Code PIN à 4 chiffres',
    'enablePin': 'Configurer le code PIN',
    'changePin': 'Modifier le code PIN',
    'disablePin': 'Désactiver le code PIN',
    'biometrics': 'Déverrouillage biométrique',
    'biometricsDesc': 'Déverrouiller avec votre empreinte digitale ou reconnaissance faciale.',
    'enterNewPin': 'Entrez un code PIN à 4 chiffres',
    'confirmPin': 'Confirmez votre code PIN',
    'pinMismatch': 'Les codes PIN ne correspondent pas.',
    'pinSetSuccess': 'Code PIN configuré avec succès.',
    'pinRemoved': 'Verrouillage PIN désactivé.',

    // Reminders & Notifications
    'reminders': 'Rappels Bien-être',
    'remindersDesc': 'Recevez un rappel quotidien apaisant pour prendre soin de vous.',
    'dailyReminder': 'Rappel quotidien bienveillant',
    'reminderTime': 'Heure du rappel',
    'testNotification': 'Envoyer un rappel test',
    'notificationSent': 'Notification envoyée ! Regardez vos notifications.',

    // Automatic Memory Suggestions
    'memorySuggestionTitle': '💡 Serene doit-elle se souvenir de cela ?',
    'remember': 'Mémoriser',
    'dismiss': 'Pas maintenant',
    'memorySaved': 'Enregistré dans vos souvenirs chiffrés.',

    // Memories
    'memories': 'Souvenirs enregistrés',
    'memHint': 'Ajoute ce que tu veux que Serene retienne (ex: "J\'aime peindre")',
    'useMem': 'Permettre à Serene d\'utiliser ces souvenirs',
    'wipe': 'Supprimer toutes mes données définitivement',
    'wipeConfirm': 'Es-tu sûr(e) de vouloir effacer définitivement tous tes souvenirs, humeurs et notes chiffrés ? Cette action est irréversible.',
    'confirm': 'Tout supprimer',
    'cancel': 'Annuler',

    // Trusted contact
    'trustedTitle': 'Contact d\'urgence de confiance',
    'trustedDesc': 'Enregistre un proche ou un thérapeute que tu peux appeler d\'un geste en cas de détresse.',
    'contactName': 'Nom du contact',
    'contactPhone': 'Numéro de téléphone',
    'saveContact': 'Enregistrer le contact',
    'removeContact': 'Supprimer le contact',

    // Mood & Wellness
    'howFeel': 'Comment te sens-tu en cet instant ?',
    'note': 'Ajouter une note ou une pensée (facultatif)',
    'save': 'Enregistrer mon humeur',
    'last': 'Tes 14 derniers enregistrements',
    'moodTags': 'Qu\'est-ce qui influence ton humeur ?',
    'tagAnxiety': 'Anxiété',
    'tagWork': 'Travail / Études',
    'tagFamily': 'Relations',
    'tagSleep': 'Sommeil',
    'tagLoneliness': 'Solitude',
    'tagHope': 'Espoir',
    'tagBurnout': 'Épuisement',

    // Breathing Studio
    'breathingStudio': 'Studio de Respiration Guidée',
    'modeCalm': 'Rythme Apaisant (4-6)',
    'modeBox': 'Respiration Carrée (4-4-4-4)',
    'mode478': 'Repos Profond (4-7-8)',
    'inhale': 'Inspire…',
    'hold': 'Retiens doucement…',
    'exhale': 'Expire lentement…',
    'start': 'Commencer la respiration',
    'stop': 'Arrêter',

    // 5-4-3-2-1 Grounding
    'groundingTitle': 'Exercice d\'Ancrage 5-4-3-2-1',
    'groundingIntro': 'Quand l\'angoisse ou la panique te submergent, cette technique sensorielle reconnue te ramène en douceur dans l\'instant présent.',
    'step5': 'Regarde autour de toi et nomme 5 choses que tu peux VOIR.',
    'step5Hint': 'Le motif du sol, la lumière sur le mur, tes chaussures, une plante, une ombre…',
    'step4': 'Remarque 4 choses que tu peux TOUCHER.',
    'step4Hint': 'Le tissu de tes vêtements, la fraîcheur d\'une table, tes pieds bien ancrés au sol…',
    'step3': 'Écoute attentivement 3 sons que tu peux ENTENDRE.',
    'step3Hint': 'Une voiture au loin, le souffle de l\'air, ta propre respiration, des oiseaux…',
    'step2': 'Identifie 2 choses que tu peux SENTIR.',
    'step2Hint': 'L\'air frais, un café, ton parfum, ou visualise ton odeur réconfortante préférée…',
    'step1': 'Constate 1 chose que tu peux GOÛTER ou dis-toi 1 vérité bienveillante.',
    'step1Hint': 'Bois une gorgée d\'eau fraîche, ou répète : "Je suis en sécurité. Cette sensation va passer."',
    'nextStep': 'Étape suivante',
    'prevStep': 'Précédente',
    'groundingDone': 'Je me sens plus ancré(e)',
    'groundingComplete': 'Bravo. Respire doucement. Tu es revenu(e) dans le moment présent.',

    // Journal
    'writeHere': 'Écris librement. Cet espace est chiffré et strictement réservé à tes yeux.',
    'noEntries': 'Aucune entrée pour l\'instant. Écris chaque fois que tu as besoin de déposer tes pensées.',
    'journalPrompt1': 'Quelle est la pensée pesante que tu aimerais déposer aujourd\'hui ?',
    'journalPrompt2': 'Quelle petite chose t\'a apporté un instant de calme ou de paix ?',
    'journalPrompt3': 'De quoi as-tu le plus besoin pour toi-même en ce moment ?',
  },

  'ar': {
    'title': 'سكينة',
    'tagline': 'رفيقك الخاص والآمن للعافية النفسية',
    'chat': 'محادثة',
    'checkin': 'المزاج',
    'breathe': 'تنفّس',
    'grounding': 'تثبيت الحواس',
    'journal': 'يوميات',
    'settings': 'الطوارئ والخصوصية',

    // Chat
    'hint': 'اكتب ما يدور في خاطرك أو يثقل قلبك…',
    'send': 'إرسال',
    'stopGenerating': 'إيقاف التوليد',
    'disclaimer': 'أنا رفيق ذكاء اصطناعي للدعم، ولست معالجًا نفسيًا أو طبيبًا. في الأزمات النفسية أو الطبية الطارئة، يرجى التواصل مع إنسان مختص فورًا.',
    'error': 'تعذّر الاتصال. يرجى المحاولة بعد لحظات.',
    'empty': 'لا توجد عناصر محفوظة حتى الآن.',
    'thinking': 'سكينة تفكر وتستمع إليك…',
    'privacyShield': 'درع الخصوصية السريع',
    'shieldActivated': 'شاشة الخصوصية مفعّلة. اضغط في أي مكان لإلغاء القفل.',
    'shieldQuote': 'خذ نفسًا هادئًا. أنت بأمان هنا.',

    // Icebreakers
    'promptOverwhelmed': 'أشعر بضياع وضغط شديد يفوق طاقتي الآن',
    'promptSleep': 'لا أستطيع النوم وأفكاري تتسارع بشكل مؤلم',
    'promptLonely': 'أشعر بوحدة شديدة وثقل في داخلي اليوم',
    'promptCalm': 'هل يمكنك مساعدتي في تمرين هادئ لتخفيف التوتر؟',

    // Crisis
    'crisisTitle': 'لست وحدك أبدًا. حياتك غالية ومهمة.',
    'crisisSubtitle': 'سلامتك هي أهم أولوياتنا. أرجوك تواصل مع شخص يمكنه مساندتك الآن.',
    'call': 'اتصال',
    'trustedContact': 'الاتصال بالشخص المقرّب للطوارئ',
    'noTrustedContact': 'لم تقم بتحديد شخص موثوق بعد. يمكنك إضافته من إعدادات الطوارئ والخصوصية.',
    'selectCountry': 'أرقام الدعم النفسي والطوارئ حسب البلد:',
    'visitWebsite': 'زيارة موقع الدعم والمساعدة',
    'crisisBreathing': 'تنفّس معي بهدوء الآن',
    'close': 'أنا بأمان في الوقت الحالي',

    // Onboarding Gate
    'welcomeTitle': 'مرحبًا بك في سكينة',
    'welcomeBody': 'سكينة رفيق عافية نفسية مجاني بنسبة 100% ومصمم لحماية خصوصيتك التامة.\n\n• هو مستمع بالذكاء الاصطناعي وليس طبيبًا أو معالجًا، ولا يمكنه معالجة الطوارئ الحادة.\n• المحادثات مؤقتة في ذاكرة الجهاز ولا يتم حفظها على هاتفك أو في سجلات خوادمنا مطلقًا.\n• ذكرياتك وتسجيلات مزاجك ويومياتك مشفّرة تمامًا داخل هاتفك عبر نظام الأمان المشفر للأندرويد.\n• لديك السيطرة المطلقة ويمكنك حذف جميع بياناتك في أي لحظة.\n\nإذا كنت في خطر أو تراودك أفكار لإيذاء نفسك، فنرجو منك الاتصال الفوري بخدمات الإسعاف أو شخص تثق به.',
    'accept': 'فهمت ذلك وأود الدخول',

    // Security & Lock
    'securityLock': 'قفل وأمان التطبيق',
    'securityDesc': 'احمِ خصوصيتك برمز PIN مكوّن من 4 أرقام والبصمة.',
    'pinLock': 'رمز PIN من 4 أرقام',
    'enablePin': 'تعيين رمز PIN',
    'changePin': 'تغيير رمز PIN',
    'disablePin': 'إلغاء قفل PIN',
    'biometrics': 'فتح القفل بالبصمة أو الوجه',
    'biometricsDesc': 'افتح التطبيق بسرعة عبر البصمة الحيوية المسجلة في هاتفك.',
    'enterNewPin': 'أدخل رمز PIN من 4 أرقام',
    'confirmPin': 'أكّد رمز PIN',
    'pinMismatch': 'الرمزان غير متطابقين، حاول مجددًا.',
    'pinSetSuccess': 'تم تفعيل قفل PIN بنجاح.',
    'pinRemoved': 'تم إلغاء قفل PIN.',

    // Reminders & Notifications
    'reminders': 'تنبيهات اليقظة والاطمئنان',
    'remindersDesc': 'تلقَّ تذكيرًا يوميًا هادئًا للاطمئنان على نفسك والتنفس.',
    'dailyReminder': 'تذكير يومي لطيف',
    'reminderTime': 'وقت التذكير',
    'testNotification': 'إرسال تذكير تجريبي الآن',
    'notificationSent': 'تم إرسال التنبيه! تفقّد شريط الإشعارات.',

    // Automatic Memory Suggestions
    'memorySuggestionTitle': '💡 هل ترغب أن تتذكر سكينة هذه المعلومة؟',
    'remember': 'تذكّر هذا',
    'dismiss': 'ليس الآن',
    'memorySaved': 'تم حفظها في ذكرياتك المشفرة الخاصة.',

    // Memories
    'memories': 'الذكريات المحفوظة',
    'memHint': 'أضف ما تحب أن تتذكره سكينة عنك (مثل: "أحب الرسم عندما أكون قلقًا")',
    'useMem': 'السماح لسكينة بتذكّر هذه التفاصيل في الحديث',
    'wipe': 'حذف جميع بياناتي نهائيًا',
    'wipeConfirm': 'هل أنت متأكد من حذف جميع الذكريات والمزاج واليوميات المشفّرة نهائيًا من جهازك؟ لا يمكن التراجع عن هذا الإجراء.',
    'confirm': 'حذف كل شيء',
    'cancel': 'إلغاء',

    // Trusted contact
    'trustedTitle': 'شخص موثوق للطوارئ',
    'trustedDesc': 'احفظ رقم شخص قريب أو صديق أو معالج يمكنك الاتصال به بنقرة واحدة عند اشتداد الأزمة.',
    'contactName': 'اسم الشخص',
    'contactPhone': 'رقم الهاتف',
    'saveContact': 'حفظ جهة الاتصال',
    'removeContact': 'حذف جهة الاتصال',

    // Mood & Wellness
    'howFeel': 'كيف تشعر في هذه اللحظة؟',
    'note': 'أضف ملاحظة أو شعورًا راودك (اختياري)',
    'save': 'حفظ تسجيل المزاج',
    'last': 'آخر 14 تسجيلًا لمزاجك',
    'moodTags': 'ما الذي أثّر على شعورك اليوم؟',
    'tagAnxiety': 'قلق وتوتر',
    'tagWork': 'العمل / الدراسة',
    'tagFamily': 'العلاقات والأسرة',
    'tagSleep': 'النوم والراحة',
    'tagLoneliness': 'الشعور بالوحدة',
    'tagHope': 'أمل وتفاؤل',
    'tagBurnout': 'إرهاق واستنزاف',

    // Breathing Studio
    'breathingStudio': 'مساحة التنفّس الإرشادي',
    'modeCalm': 'التنفّس المهدئ (4-6)',
    'modeBox': 'التنفّس المربّع (4-4-4-4)',
    'mode478': 'الاسترخاء العميق والنوم (4-7-8)',
    'inhale': 'شهيق عميق…',
    'hold': 'احبس نفسك بهدوء…',
    'exhale': 'زفير بطيء…',
    'start': 'بدء التنفّس',
    'stop': 'إيقاف',

    // 5-4-3-2-1 Grounding
    'groundingTitle': 'تمرين تثبيت الحواس 5-4-3-2-1',
    'groundingIntro': 'عندما يجتاحك الهلع أو تتسارع نبضاتك وأفكارك، يساعدك هذا الأسلوب الحسي المعتمد على استعادة الهدوء والعودة الآمنة للحظة الحالية.',
    'step5': 'انظر حولك ولاحظ 5 أشياء يمكنك رُؤيتها بالعين.',
    'step5Hint': 'شكل الإضاءة على الحائط، حذاؤك، نبتة، قطعة أثاث، يديك…',
    'step4': 'انتبه لـ 4 أشياء يمكنك لَمْسها أو الإحساس بها.',
    'step4Hint': 'ملمس قماش ملابسك، برودة الطاولة، ثبات قدميك على الأرض…',
    'step3': 'أصغِ باهتمام لـ 3 أصوات يمكنك سَمَاعها.',
    'step3Hint': 'صوت سيارة بعيدة، صوت جهاز التكييف، صوت تنفسك، طيور في الخارج…',
    'step2': 'ميّز شيئين (2) يمكنك شَمَّهما.',
    'step2Hint': 'رائحة الهواء، فنجان قهوة، عطرك، أو تخيّل رائحة مهدئة تحبها…',
    'step1': 'لاحظ شيئًا (1) يمكنك تذوّقه أو قل كلمة طمأنينة لنفسك.',
    'step1Hint': 'اشرب رشفة ماء بارد، أو ردّد: "أنا هنا الآن بأمان. هذه المشاعر ستمضي."',
    'nextStep': 'الخطوة التالية',
    'prevStep': 'الخطوة السابقة',
    'groundingDone': 'أشعر بالهدوء والاتزان الآن',
    'groundingComplete': 'أحسنت صنعًا. خذ نفسًا هادئًا؛ لقد عدت إلى هنا والآن.',

    // Journal
    'writeHere': 'اكتب بكل حرية. هذه المساحة مشفرة تمامًا ولا يطّلع عليها أحد سواك.',
    'noEntries': 'لا توجد كتابات بعد. دوّن ما تشعر به متى أردت تفريغ ما في داخلك.',
    'journalPrompt1': 'ما هو الفكر الثقيل الذي تود إفراغه وتركه اليوم؟',
    'journalPrompt2': 'ما هو الشيء البسيط الذي منحك بصيصًا من الطمأنينة أو السلام؟',
    'journalPrompt3': 'ما الذي تحتاجه نفسك منك بلطف في هذا الوقت؟',
  },
};

class S {
  final String code;
  S(this.code);

  String t(String key) {
    return _strings[code]?[key] ?? _strings['en']?[key] ?? key;
  }

  static S of(BuildContext context) {
    return S(Localizations.localeOf(context).languageCode);
  }
}
