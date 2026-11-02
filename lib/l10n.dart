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
    'disclaimer':
        'I am an AI companion, not a therapist or doctor. In a medical or psychiatric crisis, please connect with a human immediately.',
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
    'crisisSubtitle':
        'We care deeply about your safety. Please connect with someone who can support you right now.',
    'call': 'Call',
    'trustedContact': 'Call My Trusted Contact',
    'noTrustedContact':
        'No trusted contact set. You can add one in Emergency & Privacy settings.',
    'selectCountry': 'Country hotlines:',
    'visitWebsite': 'Visit Support Website',
    'crisisBreathing': 'Take a gentle breath with me',
    'close': 'I am safe for now',

    // Onboarding Gate
    'welcomeTitle': 'Welcome to Serene',
    'welcomeBody':
        'Serene is a 100% free, private wellness companion.\n\n• It is an AI listener, not a therapist, and cannot manage emergency crises.\n• Everything you share — chats, memories, mood check-ins, journal entries and your profile — is held in temporary memory and is never written to your phone or logged on our servers.\n• It all disappears when you close Serene, and nothing is left behind for anyone else to find.\n\nIf you ever feel unsafe or have thoughts of self-harm, please reach out to emergency services or someone you trust.',
    'accept': 'I understand & wish to enter',

    // Personalization onboarding
    'profileSetup': 'Make this space yours',
    'skipForNow': 'Skip for now',
    'next': 'Continue',
    'back': 'Back',
    'getStarted': 'Start talking',
    'saveChanges': 'Save changes',
    'done': 'Done',
    'aboutYouTitle': 'First, a little about you',
    'aboutYouSubtitle':
        'A few gentle questions so I can speak with you the way that feels right. Answer only what feels comfortable.',
    'yourName': 'Your name (optional)',
    'yourNameHint': 'What should I call you?',
    'birthday': 'Your birthday',
    'birthdayPrivacy':
        'Used only to know your age. The date itself never leaves your phone.',
    'chooseBirthday': 'Choose your birthday',
    'ageYears': '{age} years old',
    'birthdayRequired': 'Choose your birthday to continue, or skip for now.',
    'onboardingPrivacy':
        'Your answers stay in memory for this session only. Nothing is written to your phone.',
    'styleTitle': 'How should I talk with you?',
    'styleSubtitle': 'There is no wrong answer — you can change this later.',
    'styleWarm': 'Warm & gentle',
    'styleWarmDesc': 'Soft, patient words. I listen first and move slowly.',
    'styleFriend': 'Like a close friend',
    'styleFriendDesc':
        'Natural and familiar, with a little lightness when it helps.',
    'styleDirect': 'Direct & practical',
    'styleDirectDesc':
        'Clear, honest words and concrete steps, without circling around.',
    'lengthTitle': 'How much would you like me to say?',
    'lengthShort': 'Short',
    'lengthShortDesc': 'A few sentences, easy to absorb.',
    'lengthBalanced': 'Balanced',
    'lengthBalancedDesc': 'Enough space to feel heard, without a wall of text.',
    'lengthDeep': 'Deep',
    'lengthDeepDesc': 'Longer, reflective replies when you want to go deeper.',
    'focusTitle': 'What would you like support with?',
    'focusSubtitle':
        'Choose any that resonate. This shapes what I pay attention to.',
    'focusAnxiety': 'Anxiety & panic',
    'focusMood': 'Low mood',
    'focusSleep': 'Sleep',
    'focusRelationships': 'Relationships',
    'focusSelfEsteem': 'Self-esteem',
    'focusGrief': 'Grief & loss',
    'focusStress': 'Stress & burnout',
    'focusPurpose': 'Meaning & direction',
    'therapyTitle': 'I am seeing a therapist or counselor',
    'therapyDesc': 'I will support that work, never replace it.',
    'notesTitle': 'Anything else I should know? (optional)',
    'notesHint': 'e.g. "Please keep replies very short when I panic."',
    'profileLater':
        'You can update all of this later in Emergency & Privacy settings.',
    'greetName': 'Hello, {name}. I am here with you.',
    'welcomeBack': 'Welcome back, {name}',
    'profileCardTitle': 'Personal profile',
    'profileCardDesc': 'Your name, age, and how you prefer to be spoken to.',
    'editProfile': 'Edit profile',
    'saveError': 'Could not save your profile. Please try again.',

    // Appearance
    'appearance': 'Appearance',
    'appearanceDesc': 'Choose how Serene looks on this device.',
    'themeSystem': 'System',
    'themeLight': 'Light',
    'themeDark': 'Dark',

    // Voice call (self-hosted LiveKit; audio is never recorded by Serene)
    'voiceCall': 'Voice call',
    'voiceConnecting': 'Connecting…',
    'voiceReady': 'I\'m here — just talk whenever you\'re ready',
    'voiceListening': 'I\'m listening…',
    'voiceThinking': 'Thinking…',
    'voiceSpeaking': 'Speaking…',
    'voiceReconnecting': 'Reconnecting…',
    'voiceLive': 'Connected',
    'voiceAgentMissing':
        'Connected, but Serene is not answering. Check that the voice agent is running on your server.',
    'voiceEnded': 'Call ended',
    'voiceTapToTalk': 'You can start talking any time',
    'voiceTalkNow': 'Speak now',
    'voiceInterrupt': 'Interrupt',
    'voiceMute': 'Mute microphone',
    'voiceUnmute': 'Turn microphone on',
    'voiceEnd': 'End call',
    'voiceError': 'The call dropped. Please try again.',
    'voiceUnavailable':
        'Voice calls need a connection to your Serene voice server and microphone access. Check the server address in voice settings.',
    'voicePermissionDenied':
        'Serene needs microphone access for a voice call. You can allow it in Android settings.',
    'voiceOpenSettings': 'Open settings',
    'voiceRetry': 'Try again',
    'voiceAuthFailed':
        'This device is no longer recognised by the voice server. Check the enrolment code in voice settings.',
    'voiceRateLimited': 'Too many call attempts. Wait a minute and try again.',
    'voicePrivacyNote':
        'Audio goes straight to your own Serene server for speech recognition. It is not recorded or stored.',
    'voiceCrisisBody':
        'You deserve support from a real person right now. These lines are free and confidential.',
    'voiceCrisisContinue': 'I\'m safe for now, let\'s keep talking',

    // Voice settings
    'voiceSettings': 'Voice call settings',
    'voiceServerUrl': 'Voice server address',
    'voiceServerUrlDesc':
        'The address of your self-hosted Serene voice backend, for example http://192.168.1.10:8788.',
    'voiceServerUrlInvalid': 'Enter a valid http:// or https:// address.',
    'voiceEnrollmentCode': 'Enrolment code',
    'voiceEnrollmentCodeDesc':
        'Only needed if your server was set up with one. It is asked once per install.',
    'voiceLanguage': 'Call language',
    'voiceLanguageAuto': 'Same as the app',
    'voiceLanguageTunisian': 'Tunisian Arabic',
    'voiceCaptions': 'Show captions',
    'voiceCaptionsDesc':
        'Display what you and Serene say during the call. Captions are not saved.',
    'voiceTestConnection': 'Test connection',
    'voiceTesting': 'Testing…',
    'voiceTestOk': 'Server reachable. LiveKit and the language model are up.',
    'voiceTestDegraded':
        'Server reachable, but LiveKit or the language model is not ready.',
    'voiceTestFail': 'Could not reach the voice server.',
    'voiceResetDevice': 'Forget this device',
    'voiceResetDeviceDesc':
        'Removes this install\'s enrolment. The next call will enrol again.',
    'voiceResetDone': 'Device enrolment removed.',
    'voiceSaved': 'Voice settings saved.',
    'voiceNotConfigured': 'Check the voice server address in voice settings.',
    'voiceSave': 'Save',

    // Security & Lock
    'securityLock': 'App Security & PIN Lock',
    'securityDesc':
        'Lock Serene with a 4-digit PIN and biometrics. Only a scrambled fingerprint of your PIN is stored on this phone — never the PIN itself.',
    'pinLock': '4-Digit PIN Lock',
    'pinActive': 'Active',
    'pinDisabled': 'Disabled',
    'enablePin': 'Set PIN',
    'changePin': 'Change PIN',
    'disablePin': 'Remove PIN',
    'biometrics': 'Biometric Unlock',
    'biometricsDesc': 'Unlock using your fingerprint or face recognition.',
    'biometricsUnavailable': 'This device has no biometric sensor.',
    'biometricsNotEnrolled':
        'Set up a fingerprint or face in your phone settings first.',
    'biometricsPrompt': 'Confirm it is you',
    'biometricsFailed':
        'Biometric unlock could not be enabled. Please try again.',
    'enterNewPin': 'Enter a 4-digit PIN',
    'confirmPin': 'Confirm your PIN',
    'pinMismatch': 'PINs do not match. Please try again.',
    'pinSetSuccess': 'PIN lock enabled successfully.',
    'pinRemoved': 'PIN lock disabled.',

    // Lock screen
    'lockEnterPin': 'Enter your 4-digit PIN',
    'lockIncorrectPin': 'Incorrect PIN',
    'lockTooManyAttempts': 'Too many attempts. Wait {seconds}s',
    'lockBiometricReason': 'Authenticate to access Serene',
    'lockBiometricFailed': 'Biometric unlock failed. Enter your PIN.',
    'lockBiometricTooltip': 'Unlock with biometrics',
    'lockSos': 'SOS Help',
    'lockEmergencyTitle': 'Emergency Crisis Hotlines',
    'lockEmergencyBody':
        'Help is available 24/7. You do not have to carry this alone.',
    'lockClose': 'Close',

    // Reminders & Notifications
    'reminders': 'Mindful Reminders',
    'remindersDesc': 'Receive gentle, soothing daily check-ins on your phone.',
    'dailyReminder': 'Daily Wellness Check-in',
    'reminderTime': 'Reminder Time',
    'testNotification': 'Send Test Affirmation',
    'notificationSent': 'Notification sent! Check your notification bar.',
    'notificationsBlocked':
        'Notifications are turned off for Serene. Enable them in your phone settings.',
    'notificationsFailed': 'Could not schedule the reminder. Please try again.',

    // Automatic Memory Suggestions
    'memorySuggestionTitle': '💡 Would you like Serene to remember this?',
    'remember': 'Remember',
    'dismiss': 'Not now',
    'memorySaved': 'Saved to your memories for this session.',

    // Memories
    'memories': 'Memories for this session',
    'memHint':
        'Add something you want Serene to remember (e.g. "I love painting")',
    'useMem': 'Allow Serene to remember these details',
    'wipe': 'Clear this session\'s data',
    'wipeConfirm':
        'Clear everything Serene is holding in memory — memories, mood logs, journal entries and your profile — and reset the saved language, theme and reminder settings? Nothing personal is stored on your phone, so this only affects the current session.',
    'wipeDone': 'This session\'s data has been cleared.',
    'confirm': 'Clear',
    'cancel': 'Cancel',

    // Trusted contact
    'trustedTitle': 'Emergency Trusted Contact',
    'trustedDesc':
        'Save a close friend, family member, or counselor you can instantly call during distress.',
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
    'groundingIntro':
        'When panic, dissociation, or racing thoughts overwhelm you, this evidence-based sensory technique brings you safely back to the present moment.',
    'step5': 'Look around and name 5 things you can SEE.',
    'step5Hint':
        'A pattern on the floor, the light on the wall, your shoes, a plant, a shadow…',
    'step4': 'Notice 4 things you can physically TOUCH.',
    'step4Hint':
        'The fabric of your clothes, the coolness of a desk, your feet firmly on the ground…',
    'step3': 'Listen carefully for 3 things you can HEAR.',
    'step3Hint':
        'A distant car, the hum of air, your own breathing, birds outside…',
    'step2': 'Identify 2 things you can SMELL.',
    'step2Hint':
        'Fresh air, coffee, your shampoo, or imagine your favorite comforting aroma…',
    'step1': 'Notice 1 thing you can TASTE or say 1 kind truth to yourself.',
    'step1Hint':
        'Take a sip of cool water, or repeat: "I am safe right now. This feeling will pass."',
    'nextStep': 'Next Step',
    'prevStep': 'Previous',
    'groundingDone': 'I Feel More Grounded',
    'groundingComplete':
        'Well done. Take a gentle breath. You made it back to the present moment.',
    'senseSight': 'Sight',
    'senseTouch': 'Touch',
    'senseHearing': 'Sound',
    'senseSmell': 'Smell',
    'senseTaste': 'Taste & Presence',
    'groundingTapHint': 'Tap each anchor as you identify an item around you:',
    'allFound': 'All items acknowledged. Take a slow, grounding breath.',
    'groundingBreatheBtn': 'Guided Breathing',
    'restartExercise': 'Start Over',

    // Journal
    'writeHere':
        'Write freely. This space lives in memory only and disappears when you close the app.',
    'noEntries':
        'No entries yet. Write your thoughts whenever you need to release them.',
    'journalPrompt1': 'What is one heavy thought you want to let go of today?',
    'journalPrompt2':
        'What is something small that brought you a sliver of peace?',
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
    'disclaimer':
        'Je suis une IA de soutien, pas un thérapeute ni un médecin. En cas d\'urgence vitale ou psychiatrique, contacte immédiatement un humain.',
    'error': 'Problème de connexion. Merci de réessayer dans un instant.',
    'empty': 'Rien d\'enregistré pour le moment.',
    'thinking': 'Serene prend le temps de te répondre…',
    'privacyShield': 'Bouclier de confidentialité rapide',
    'shieldActivated':
        'Écran de confidentialité actif. Touche n\'importe où pour déverrouiller.',
    'shieldQuote': 'Prends une grande inspiration. Tu es en sécurité ici.',

    // Icebreakers
    'promptOverwhelmed': 'Je me sens complètement submergé(e) en ce moment',
    'promptSleep':
        'Je n\'arrive pas à dormir et mes pensées tournent en boucle',
    'promptLonely': 'Je ressens une profonde solitude aujourd\'hui',
    'promptCalm': 'Peux-tu me guider dans un exercice pour me calmer ?',

    // Crisis
    'crisisTitle': 'Tu n\'es pas seul(e). Ta vie compte.',
    'crisisSubtitle':
        'Ta sécurité nous tient profondément à cœur. Contacte quelqu\'un qui peut t\'aider dès maintenant.',
    'call': 'Appeler',
    'trustedContact': 'Appeler mon contact de confiance',
    'noTrustedContact':
        'Aucun contact de confiance défini. Tu peux en ajouter un dans les paramètres.',
    'selectCountry': 'Lignes d\'écoute par pays :',
    'visitWebsite': 'Consulter le site de soutien',
    'crisisBreathing': 'Respirer doucement ensemble',
    'close': 'Je me sens en sécurité pour l\'instant',

    // Onboarding Gate
    'welcomeTitle': 'Bienvenue dans Serene',
    'welcomeBody':
        'Serene est un compagnon de bien-être 100 % gratuit et respectueux de ta vie privée.\n\n• C\'est une présence d\'écoute bienveillante par IA, pas un thérapeute, et il ne traite pas les urgences.\n• Tout ce que tu partages — discussions, souvenirs, humeurs, journal et profil — reste en mémoire vive : rien n\'est écrit sur ton téléphone ni enregistré sur nos serveurs.\n• Tout disparaît quand tu fermes Serene, et il ne reste rien que quelqu\'un d\'autre pourrait retrouver.\n\nSi tu es en danger ou si tu as des pensées sombres, appelle les secours ou une personne de confiance.',
    'accept': 'J\'ai compris et je souhaite entrer',

    // Personalization onboarding
    'profileSetup': 'Fais de cet espace le tien',
    'skipForNow': 'Passer pour l\'instant',
    'next': 'Continuer',
    'back': 'Retour',
    'getStarted': 'Commencer à parler',
    'saveChanges': 'Enregistrer',
    'done': 'Terminé',
    'aboutYouTitle': 'D\'abord, un peu de toi',
    'aboutYouSubtitle':
        'Quelques questions douces pour que je te parle de la façon qui te convient. Réponds seulement à ce qui te met à l\'aise.',
    'yourName': 'Ton prénom (facultatif)',
    'yourNameHint': 'Comment puis-je t\'appeler ?',
    'birthday': 'Ta date de naissance',
    'birthdayPrivacy':
        'Utilisée uniquement pour connaître ton âge. La date reste sur ton téléphone.',
    'chooseBirthday': 'Choisis ta date de naissance',
    'ageYears': '{age} ans',
    'birthdayRequired':
        'Choisis ta date de naissance pour continuer, ou passe pour l\'instant.',
    'onboardingPrivacy':
        'Tes réponses restent en mémoire pour cette session uniquement. Rien n\'est écrit sur ton téléphone.',
    'styleTitle': 'Comment veux-tu que je te parle ?',
    'styleSubtitle':
        'Il n\'y a pas de mauvaise réponse — tu pourras changer plus tard.',
    'styleWarm': 'Chaleureux et doux',
    'styleWarmDesc':
        'Des mots tendres et patients. J\'écoute d\'abord et j\'avance doucement.',
    'styleFriend': 'Comme un ami proche',
    'styleFriendDesc':
        'Naturel et familier, avec un peu de légèreté quand cela aide.',
    'styleDirect': 'Direct et pratique',
    'styleDirectDesc':
        'Des mots clairs et honnêtes, des étapes concrètes, sans tourner autour.',
    'lengthTitle': 'Combien veux-tu que je dise ?',
    'lengthShort': 'Court',
    'lengthShortDesc': 'Quelques phrases, faciles à accueillir.',
    'lengthBalanced': 'Équilibré',
    'lengthBalancedDesc':
        'Assez d\'espace pour te sentir écouté(e), sans mur de texte.',
    'lengthDeep': 'Approfondi',
    'lengthDeepDesc':
        'Des réponses plus longues et réflexives quand tu veux aller plus loin.',
    'focusTitle': 'Sur quoi aimerais-tu être soutenu(e) ?',
    'focusSubtitle': 'Choisis ce qui résonne. Cela oriente mon attention.',
    'focusAnxiety': 'Anxiété et panique',
    'focusMood': 'Baisse de moral',
    'focusSleep': 'Sommeil',
    'focusRelationships': 'Relations',
    'focusSelfEsteem': 'Estime de soi',
    'focusGrief': 'Deuil et perte',
    'focusStress': 'Stress et épuisement',
    'focusPurpose': 'Sens et direction',
    'therapyTitle': 'Je suis suivi(e) par un thérapeute ou un conseiller',
    'therapyDesc': 'Je soutiendrai ce travail, sans jamais le remplacer.',
    'notesTitle': 'Autre chose que je devrais savoir ? (facultatif)',
    'notesHint': 'ex. « Garde des réponses très courtes quand je panique. »',
    'profileLater':
        'Tu pourras tout modifier plus tard dans les paramètres Urgence & Vie Privée.',
    'greetName': 'Bonjour {name}. Je suis là avec toi.',
    'welcomeBack': 'Bon retour, {name}',
    'profileCardTitle': 'Profil personnel',
    'profileCardDesc':
        'Ton prénom, ton âge et la façon dont tu préfères qu\'on te parle.',
    'editProfile': 'Modifier le profil',
    'saveError': 'Impossible d\'enregistrer ton profil. Réessaie.',

    // Appearance
    'appearance': 'Apparence',
    'appearanceDesc': 'Choisissez l\'apparence de Serene sur cet appareil.',
    'themeSystem': 'Système',
    'themeLight': 'Clair',
    'themeDark': 'Sombre',

    // Appel vocal (LiveKit auto-hébergé ; l'audio n'est jamais enregistré)
    'voiceCall': 'Appel vocal',
    'voiceConnecting': 'Connexion…',
    'voiceReady': 'Je suis là — parle quand tu veux',
    'voiceListening': 'Je t\'écoute…',
    'voiceThinking': 'Je réfléchis…',
    'voiceSpeaking': 'Je parle…',
    'voiceReconnecting': 'Reconnexion…',
    'voiceLive': 'Connecté',
    'voiceAgentMissing':
        'Connecté, mais Serene ne répond pas. Vérifie que l\'agent vocal tourne sur ton serveur.',
    'voiceEnded': 'Appel terminé',
    'voiceTapToTalk': 'Tu peux commencer à parler quand tu veux',
    'voiceTalkNow': 'Parler maintenant',
    'voiceInterrupt': 'Interrompre',
    'voiceMute': 'Couper le micro',
    'voiceUnmute': 'Réactiver le micro',
    'voiceEnd': 'Terminer l\'appel',
    'voiceError': 'L\'appel a été interrompu. Réessaie.',
    'voiceUnavailable':
        'Les appels vocaux ont besoin de ton serveur Serene et du micro. Vérifie l\'adresse du serveur dans les réglages vocaux.',
    'voicePermissionDenied':
        'Serene a besoin du micro pour un appel vocal. Tu peux l\'autoriser dans les réglages Android.',
    'voiceOpenSettings': 'Ouvrir les réglages',
    'voiceRetry': 'Réessayer',
    'voiceAuthFailed':
        'Cet appareil n\'est plus reconnu par le serveur vocal. Vérifie le code d\'inscription dans les réglages vocaux.',
    'voiceRateLimited':
        'Trop de tentatives d\'appel. Attends une minute puis réessaie.',
    'voicePrivacyNote':
        'L\'audio va directement à ton propre serveur Serene pour la reconnaissance vocale. Il n\'est ni enregistré ni conservé.',
    'voiceCrisisBody':
        'Tu mérites le soutien d\'une vraie personne, tout de suite. Ces lignes sont gratuites et confidentielles.',
    'voiceCrisisContinue': 'Je suis en sécurité, continuons',

    // Réglages vocaux
    'voiceSettings': 'Réglages de l\'appel vocal',
    'voiceServerUrl': 'Adresse du serveur vocal',
    'voiceServerUrlDesc':
        'L\'adresse de ton serveur vocal Serene auto-hébergé, par exemple http://192.168.1.10:8788.',
    'voiceServerUrlInvalid': 'Entre une adresse http:// ou https:// valide.',
    'voiceEnrollmentCode': 'Code d\'inscription',
    'voiceEnrollmentCodeDesc':
        'Nécessaire seulement si ton serveur a été configuré avec. Il est demandé une fois par installation.',
    'voiceLanguage': 'Langue de l\'appel',
    'voiceLanguageAuto': 'Comme l\'application',
    'voiceLanguageTunisian': 'Arabe tunisien',
    'voiceCaptions': 'Afficher les sous-titres',
    'voiceCaptionsDesc':
        'Affiche ce que toi et Serene dites pendant l\'appel. Les sous-titres ne sont pas enregistrés.',
    'voiceTestConnection': 'Tester la connexion',
    'voiceTesting': 'Test en cours…',
    'voiceTestOk':
        'Serveur joignable. LiveKit et le modèle de langage sont prêts.',
    'voiceTestDegraded':
        'Serveur joignable, mais LiveKit ou le modèle de langage n\'est pas prêt.',
    'voiceTestFail': 'Impossible de joindre le serveur vocal.',
    'voiceResetDevice': 'Oublier cet appareil',
    'voiceResetDeviceDesc':
        'Supprime l\'inscription de cette installation. Le prochain appel s\'inscrira à nouveau.',
    'voiceResetDone': 'Inscription de l\'appareil supprimée.',
    'voiceSaved': 'Réglages vocaux enregistrés.',
    'voiceNotConfigured':
        'Vérifie l\'adresse du serveur vocal dans les réglages vocaux.',
    'voiceSave': 'Enregistrer',

    // Security & Lock
    'securityLock': 'Sécurité & Verrouillage PIN',
    'securityDesc':
        'Protégez Serene avec un code PIN à 4 chiffres et la biométrie. Seule une empreinte chiffrée du code est conservée sur ce téléphone, jamais le code lui-même.',
    'pinLock': 'Code PIN à 4 chiffres',
    'pinActive': 'Activé',
    'pinDisabled': 'Désactivé',
    'enablePin': 'Configurer le code PIN',
    'changePin': 'Modifier le code PIN',
    'disablePin': 'Désactiver le code PIN',
    'biometrics': 'Déverrouillage biométrique',
    'biometricsDesc':
        'Déverrouiller avec votre empreinte digitale ou reconnaissance faciale.',
    'biometricsUnavailable':
        'Cet appareil ne possède pas de capteur biométrique.',
    'biometricsNotEnrolled':
        'Configurez d\'abord une empreinte ou un visage dans les réglages de votre téléphone.',
    'biometricsPrompt': 'Confirmez votre identité',
    'biometricsFailed':
        'Impossible d\'activer le déverrouillage biométrique. Réessayez.',
    'enterNewPin': 'Entrez un code PIN à 4 chiffres',
    'confirmPin': 'Confirmez votre code PIN',
    'pinMismatch': 'Les codes PIN ne correspondent pas.',
    'pinSetSuccess': 'Code PIN configuré avec succès.',
    'pinRemoved': 'Verrouillage PIN désactivé.',

    // Écran de verrouillage
    'lockEnterPin': 'Entrez votre code PIN à 4 chiffres',
    'lockIncorrectPin': 'Code PIN incorrect',
    'lockTooManyAttempts': 'Trop de tentatives. Attendez {seconds} s',
    'lockBiometricReason': 'Authentifiez-vous pour accéder à Serene',
    'lockBiometricFailed':
        'Déverrouillage biométrique échoué. Entrez votre code PIN.',
    'lockBiometricTooltip': 'Déverrouiller par biométrie',
    'lockSos': 'Aide SOS',
    'lockEmergencyTitle': 'Lignes d\'urgence',
    'lockEmergencyBody':
        'Une aide est disponible 24 h/24 et 7 j/7. Tu n\'as pas à porter cela seul(e).',
    'lockClose': 'Fermer',

    // Reminders & Notifications
    'reminders': 'Rappels Bien-être',
    'remindersDesc':
        'Recevez un rappel quotidien apaisant pour prendre soin de vous.',
    'dailyReminder': 'Rappel quotidien bienveillant',
    'reminderTime': 'Heure du rappel',
    'testNotification': 'Envoyer un rappel test',
    'notificationSent': 'Notification envoyée ! Regardez vos notifications.',
    'notificationsBlocked':
        'Les notifications sont désactivées pour Serene. Activez-les dans les réglages de votre téléphone.',
    'notificationsFailed': 'Impossible de programmer le rappel. Réessayez.',

    // Automatic Memory Suggestions
    'memorySuggestionTitle': '💡 Serene doit-elle se souvenir de cela ?',
    'remember': 'Mémoriser',
    'dismiss': 'Pas maintenant',
    'memorySaved': 'Enregistré dans tes souvenirs pour cette session.',

    // Memories
    'memories': 'Souvenirs de cette session',
    'memHint':
        'Ajoute ce que tu veux que Serene retienne (ex: "J\'aime peindre")',
    'useMem': 'Permettre à Serene d\'utiliser ces souvenirs',
    'wipe': 'Effacer les données de cette session',
    'wipeConfirm':
        'Effacer tout ce que Serene garde en mémoire — souvenirs, humeurs, journal et profil — et réinitialiser la langue, le thème et les rappels enregistrés ? Rien de personnel n\'est stocké sur ton téléphone : cela n\'affecte que la session en cours.',
    'wipeDone': 'Les données de cette session ont été effacées.',
    'confirm': 'Effacer',
    'cancel': 'Annuler',

    // Trusted contact
    'trustedTitle': 'Contact d\'urgence de confiance',
    'trustedDesc':
        'Enregistre un proche ou un thérapeute que tu peux appeler d\'un geste en cas de détresse.',
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
    'groundingIntro':
        'Quand l\'angoisse ou la panique te submergent, cette technique sensorielle reconnue te ramène en douceur dans l\'instant présent.',
    'step5': 'Regarde autour de toi et nomme 5 choses que tu peux VOIR.',
    'step5Hint':
        'Le motif du sol, la lumière sur le mur, tes chaussures, une plante, une ombre…',
    'step4': 'Remarque 4 choses que tu peux TOUCHER.',
    'step4Hint':
        'Le tissu de tes vêtements, la fraîcheur d\'une table, tes pieds bien ancrés au sol…',
    'step3': 'Écoute attentivement 3 sons que tu peux ENTENDRE.',
    'step3Hint':
        'Une voiture au loin, le souffle de l\'air, ta propre respiration, des oiseaux…',
    'step2': 'Identifie 2 choses que tu peux SENTIR.',
    'step2Hint':
        'L\'air frais, un café, ton parfum, ou visualise ton odeur réconfortante préférée…',
    'step1':
        'Constate 1 chose que tu peux GOÛTER ou dis-toi 1 vérité bienveillante.',
    'step1Hint':
        'Bois une gorgée d\'eau fraîche, ou répète : "Je suis en sécurité. Cette sensation va passer."',
    'nextStep': 'Étape suivante',
    'prevStep': 'Précédente',
    'groundingDone': 'Je me sens plus ancré(e)',
    'groundingComplete':
        'Bravo. Respire doucement. Tu es revenu(e) dans le moment présent.',
    'senseSight': 'Vue',
    'senseTouch': 'Toucher',
    'senseHearing': 'Ouïe',
    'senseSmell': 'Odorat',
    'senseTaste': 'Goût & Présence',
    'groundingTapHint': 'Touche chaque bulle au fur et à mesure que tu observes un élément :',
    'allFound': 'Tous les éléments ont été repérés. Prends une douce inspiration.',
    'groundingBreatheBtn': 'Respiration Guidée',
    'restartExercise': 'Recommencer',

    // Journal
    'writeHere':
        'Écris librement. Cet espace vit en mémoire et disparaît quand tu fermes l\'application.',
    'noEntries':
        'Aucune entrée pour l\'instant. Écris chaque fois que tu as besoin de déposer tes pensées.',
    'journalPrompt1':
        'Quelle est la pensée pesante que tu aimerais déposer aujourd\'hui ?',
    'journalPrompt2':
        'Quelle petite chose t\'a apporté un instant de calme ou de paix ?',
    'journalPrompt3':
        'De quoi as-tu le plus besoin pour toi-même en ce moment ?',
  },
  'ar': {
    'title': 'Serene',
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
    'disclaimer':
        'أنا رفيق ذكاء اصطناعي للدعم، ولست معالجًا نفسيًا أو طبيبًا. في الأزمات النفسية أو الطبية الطارئة، يرجى التواصل مع إنسان مختص فورًا.',
    'error': 'تعذّر الاتصال. يرجى المحاولة بعد لحظات.',
    'empty': 'لا توجد عناصر محفوظة حتى الآن.',
    'thinking': 'Serene تفكر وتستمع إليك…',
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
    'crisisSubtitle':
        'سلامتك هي أهم أولوياتنا. أرجوك تواصل مع شخص يمكنه مساندتك الآن.',
    'call': 'اتصال',
    'trustedContact': 'الاتصال بالشخص المقرّب للطوارئ',
    'noTrustedContact':
        'لم تقم بتحديد شخص موثوق بعد. يمكنك إضافته من إعدادات الطوارئ والخصوصية.',
    'selectCountry': 'أرقام الدعم النفسي والطوارئ حسب البلد:',
    'visitWebsite': 'زيارة موقع الدعم والمساعدة',
    'crisisBreathing': 'تنفّس معي بهدوء الآن',
    'close': 'أنا بأمان في الوقت الحالي',

    // Onboarding Gate
    'welcomeTitle': 'مرحبًا بك في Serene',
    'welcomeBody':
        'Serene رفيق عافية نفسية مجاني بنسبة 100% ومصمم لحماية خصوصيتك التامة.\n\n• هو مستمع بالذكاء الاصطناعي وليس طبيبًا أو معالجًا، ولا يمكنه معالجة الطوارئ الحادة.\n• كل ما تشاركه — المحادثات والذكريات وتسجيلات المزاج واليوميات والملف الشخصي — يبقى في الذاكرة المؤقتة فقط، ولا يُكتب على هاتفك ولا يُسجَّل في خوادمنا.\n• كل ذلك يختفي عند إغلاق Serene، ولا يبقى أي أثر يمكن لأحد آخر أن يجده.\n\nإذا كنت في خطر أو تراودك أفكار لإيذاء نفسك، فنرجو منك الاتصال الفوري بخدمات الإسعاف أو شخص تثق به.',
    'accept': 'فهمت ذلك وأود الدخول',

    // Personalization onboarding
    'profileSetup': 'اجعل هذه المساحة مساحتك',
    'skipForNow': 'تخطّي الآن',
    'next': 'متابعة',
    'back': 'رجوع',
    'getStarted': 'لنبدأ الحديث',
    'saveChanges': 'حفظ التغييرات',
    'done': 'تم',
    'aboutYouTitle': 'أولًا، أخبرني قليلًا عنك',
    'aboutYouSubtitle':
        'بعض الأسئلة اللطيفة حتى أحدّثك بالطريقة التي تريحك. أجب عمّا تشعر بالراحة تجاهه فقط.',
    'yourName': 'اسمك (اختياري)',
    'yourNameHint': 'بماذا تحب أن أناديك؟',
    'birthday': 'تاريخ ميلادك',
    'birthdayPrivacy': 'يُستخدم فقط لمعرفة عمرك. التاريخ نفسه يبقى على هاتفك.',
    'chooseBirthday': 'اختر تاريخ ميلادك',
    'ageYears': '{age} سنة',
    'birthdayRequired': 'اختر تاريخ ميلادك للمتابعة، أو تخطَّ الآن.',
    'onboardingPrivacy':
        'إجاباتك تبقى في الذاكرة لهذه الجلسة فقط، ولا يُكتب شيء على هاتفك.',
    'styleTitle': 'كيف تحب أن أحدّثك؟',
    'styleSubtitle': 'لا توجد إجابة خاطئة — يمكنك تغيير هذا لاحقًا.',
    'styleWarm': 'دافئ ولطيف',
    'styleWarmDesc': 'كلمات هادئة وصبورة. أستمع أولًا وأتقدم ببطء.',
    'styleFriend': 'كصديق مقرّب',
    'styleFriendDesc': 'عفوي ومألوف، مع قليل من الخفة عندما يساعد ذلك.',
    'styleDirect': 'مباشر وعملي',
    'styleDirectDesc': 'كلمات واضحة وصادقة وخطوات عملية، دون لفّ ودوران.',
    'lengthTitle': 'كم تحب أن أطيل في الحديث؟',
    'lengthShort': 'قصير',
    'lengthShortDesc': 'بضع جمل سهلة الاستيعاب.',
    'lengthBalanced': 'متوازن',
    'lengthBalancedDesc': 'مساحة كافية لتشعر بأنك مسموع، دون نص طويل.',
    'lengthDeep': 'عميق',
    'lengthDeepDesc': 'ردود أطول وتأملية عندما ترغب في التعمّق.',
    'focusTitle': 'في أي شيء تحب أن أدعمك؟',
    'focusSubtitle': 'اختر ما يلامسك. هذا يوجّه انتباهي.',
    'focusAnxiety': 'القلق والهلع',
    'focusMood': 'انخفاض المزاج',
    'focusSleep': 'النوم',
    'focusRelationships': 'العلاقات',
    'focusSelfEsteem': 'تقدير الذات',
    'focusGrief': 'الفقد والحزن',
    'focusStress': 'التوتر والإنهاك',
    'focusPurpose': 'المعنى والاتجاه',
    'therapyTitle': 'أتابع حاليًا مع معالج أو مستشار نفسي',
    'therapyDesc': 'سأدعم هذا العمل، ولن أحلّ محلّه أبدًا.',
    'notesTitle': 'هل من شيء آخر تودّ أن أعرفه؟ (اختياري)',
    'notesHint': 'مثال: «اجعل ردودك قصيرة جدًا عندما أُصاب بالهلع».',
    'profileLater': 'يمكنك تعديل كل هذا لاحقًا من إعدادات الطوارئ والخصوصية.',
    'greetName': 'مرحبًا {name}. أنا هنا معك.',
    'welcomeBack': 'مرحبًا بعودتك، {name}',
    'profileCardTitle': 'الملف الشخصي',
    'profileCardDesc': 'اسمك وعمرك والطريقة التي تحب أن أحدّثك بها.',
    'editProfile': 'تعديل الملف',
    'saveError': 'تعذّر حفظ ملفك. حاول مرة أخرى.',

    // Appearance
    'appearance': 'المظهر',
    'appearanceDesc': 'اختر شكل Serene على هذا الجهاز.',
    'themeSystem': 'النظام',
    'themeLight': 'فاتح',
    'themeDark': 'داكن',

    // مكالمة صوتية (LiveKit مستضاف ذاتيًا؛ لا تُسجَّل الأصوات أبدًا)
    'voiceCall': 'مكالمة صوتية',
    'voiceConnecting': 'جارٍ الاتصال…',
    'voiceReady': 'أنا هنا — تحدّث متى شئت',
    'voiceListening': 'أنا أسمعك…',
    'voiceThinking': 'أفكر…',
    'voiceSpeaking': 'أتحدث…',
    'voiceReconnecting': 'جارٍ إعادة الاتصال…',
    'voiceLive': 'متصل',
    'voiceAgentMissing':
        'متصل، لكن Serene لا تستجيب. تحقّق من أن وكيل الصوت يعمل على خادمك.',
    'voiceEnded': 'انتهت المكالمة',
    'voiceTapToTalk': 'يمكنك البدء بالحديث في أي وقت',
    'voiceTalkNow': 'تحدّث الآن',
    'voiceInterrupt': 'قاطع',
    'voiceMute': 'كتم الميكروفون',
    'voiceUnmute': 'تشغيل الميكروفون',
    'voiceEnd': 'إنهاء المكالمة',
    'voiceError': 'انقطعت المكالمة. حاول مرة أخرى.',
    'voiceUnavailable':
        'تحتاج المكالمات الصوتية إلى خادم Serene الخاص بك وإلى الميكروفون. تحقّق من عنوان الخادم في إعدادات الصوت.',
    'voicePermissionDenied':
        'تحتاج Serene إلى الميكروفون لإجراء مكالمة صوتية. يمكنك السماح به من إعدادات أندرويد.',
    'voiceOpenSettings': 'فتح الإعدادات',
    'voiceRetry': 'إعادة المحاولة',
    'voiceAuthFailed':
        'لم يعد الخادم الصوتي يتعرّف على هذا الجهاز. تحقّق من رمز التسجيل في إعدادات الصوت.',
    'voiceRateLimited': 'محاولات اتصال كثيرة. انتظر دقيقة ثم حاول مجددًا.',
    'voicePrivacyNote':
        'يذهب الصوت مباشرة إلى خادم Serene الخاص بك للتعرّف على الكلام. لا يُسجَّل ولا يُحتفظ به.',
    'voiceCrisisBody': 'أنت تستحق دعم شخص حقيقي الآن. هذه الخطوط مجانية وسرية.',
    'voiceCrisisContinue': 'أنا بأمان الآن، لنكمل',

    // إعدادات الصوت
    'voiceSettings': 'إعدادات المكالمة الصوتية',
    'voiceServerUrl': 'عنوان الخادم الصوتي',
    'voiceServerUrlDesc':
        'عنوان خادم Serene الصوتي المستضاف ذاتيًا، مثل http://192.168.1.10:8788.',
    'voiceServerUrlInvalid': 'أدخل عنوانًا صالحًا يبدأ بـ http:// أو https://.',
    'voiceEnrollmentCode': 'رمز التسجيل',
    'voiceEnrollmentCodeDesc':
        'مطلوب فقط إذا أُعدّ خادمك به. يُطلب مرة واحدة لكل تثبيت.',
    'voiceLanguage': 'لغة المكالمة',
    'voiceLanguageAuto': 'مثل التطبيق',
    'voiceLanguageTunisian': 'العربية التونسية',
    'voiceCaptions': 'إظهار النصوص',
    'voiceCaptionsDesc':
        'يعرض ما تقوله أنت وSerene أثناء المكالمة. لا تُحفظ النصوص.',
    'voiceTestConnection': 'اختبار الاتصال',
    'voiceTesting': 'جارٍ الاختبار…',
    'voiceTestOk': 'الخادم متاح. LiveKit ونموذج اللغة جاهزان.',
    'voiceTestDegraded': 'الخادم متاح، لكن LiveKit أو نموذج اللغة غير جاهز.',
    'voiceTestFail': 'تعذّر الوصول إلى الخادم الصوتي.',
    'voiceResetDevice': 'نسيان هذا الجهاز',
    'voiceResetDeviceDesc':
        'يحذف تسجيل هذا التثبيت. ستُسجّل المكالمة التالية من جديد.',
    'voiceResetDone': 'تم حذف تسجيل الجهاز.',
    'voiceSaved': 'تم حفظ إعدادات الصوت.',
    'voiceNotConfigured': 'تحقّق من عنوان الخادم الصوتي في إعدادات الصوت.',
    'voiceSave': 'حفظ',

    // Security & Lock
    'securityLock': 'قفل وأمان التطبيق',
    'securityDesc':
        'احمِ Serene برمز PIN من 4 أرقام والبصمة. يُحفظ على هذا الهاتف بصمة مشفّرة للرمز فقط، ولا يُحفظ الرمز نفسه أبدًا.',
    'pinLock': 'رمز PIN من 4 أرقام',
    'pinActive': 'مفعّل',
    'pinDisabled': 'غير مفعّل',
    'enablePin': 'تعيين رمز PIN',
    'changePin': 'تغيير رمز PIN',
    'disablePin': 'إلغاء قفل PIN',
    'biometrics': 'فتح القفل بالبصمة أو الوجه',
    'biometricsDesc': 'افتح التطبيق بسرعة عبر البصمة الحيوية المسجلة في هاتفك.',
    'biometricsUnavailable': 'هذا الجهاز لا يحتوي على مستشعر بصمة حيوية.',
    'biometricsNotEnrolled':
        'أضف بصمة إصبع أو بصمة وجه من إعدادات هاتفك أولًا.',
    'biometricsPrompt': 'أكّد هويتك',
    'biometricsFailed': 'تعذّر تفعيل فتح القفل بالبصمة. حاول مرة أخرى.',
    'enterNewPin': 'أدخل رمز PIN من 4 أرقام',
    'confirmPin': 'أكّد رمز PIN',
    'pinMismatch': 'الرمزان غير متطابقين، حاول مجددًا.',
    'pinSetSuccess': 'تم تفعيل قفل PIN بنجاح.',
    'pinRemoved': 'تم إلغاء قفل PIN.',

    // شاشة القفل
    'lockEnterPin': 'أدخل رمز PIN المكوّن من 4 أرقام',
    'lockIncorrectPin': 'رمز PIN غير صحيح',
    'lockTooManyAttempts': 'محاولات كثيرة. انتظر {seconds} ثانية',
    'lockBiometricReason': 'أكّد هويتك للدخول إلى Serene',
    'lockBiometricFailed': 'تعذّر فتح القفل بالبصمة. أدخل رمز PIN.',
    'lockBiometricTooltip': 'فتح القفل بالبصمة',
    'lockSos': 'مساعدة طارئة',
    'lockEmergencyTitle': 'خطوط دعم الأزمات',
    'lockEmergencyBody':
        'المساعدة متاحة على مدار الساعة. لست مضطرًا لتحمّل هذا وحدك.',
    'lockClose': 'إغلاق',

    // Reminders & Notifications
    'reminders': 'تنبيهات اليقظة والاطمئنان',
    'remindersDesc': 'تلقَّ تذكيرًا يوميًا هادئًا للاطمئنان على نفسك والتنفس.',
    'dailyReminder': 'تذكير يومي لطيف',
    'reminderTime': 'وقت التذكير',
    'testNotification': 'إرسال تذكير تجريبي الآن',
    'notificationSent': 'تم إرسال التنبيه! تفقّد شريط الإشعارات.',
    'notificationsBlocked':
        'الإشعارات متوقفة لتطبيق Serene. فعّلها من إعدادات هاتفك.',
    'notificationsFailed': 'تعذّر جدولة التذكير. حاول مرة أخرى.',

    // Automatic Memory Suggestions
    'memorySuggestionTitle': '💡 هل ترغب أن تتذكر Serene هذه المعلومة؟',
    'remember': 'تذكّر هذا',
    'dismiss': 'ليس الآن',
    'memorySaved': 'تم حفظها في ذكريات هذه الجلسة.',

    // Memories
    'memories': 'ذكريات هذه الجلسة',
    'memHint':
        'أضف ما تحب أن تتذكره Serene عنك (مثل: "أحب الرسم عندما أكون قلقًا")',
    'useMem': 'السماح لـ Serene بتذكّر هذه التفاصيل في الحديث',
    'wipe': 'محو بيانات هذه الجلسة',
    'wipeConfirm':
        'هل تريد محو كل ما تحتفظ به Serene في الذاكرة — الذكريات وتسجيلات المزاج واليوميات والملف الشخصي — وإعادة ضبط اللغة والمظهر والتذكيرات المحفوظة؟ لا شيء شخصي محفوظ على هاتفك، لذا يؤثر هذا في الجلسة الحالية فقط.',
    'wipeDone': 'تم محو بيانات هذه الجلسة.',
    'confirm': 'محو',
    'cancel': 'إلغاء',

    // Trusted contact
    'trustedTitle': 'شخص موثوق للطوارئ',
    'trustedDesc':
        'احفظ رقم شخص قريب أو صديق أو معالج يمكنك الاتصال به بنقرة واحدة عند اشتداد الأزمة.',
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
    'groundingIntro':
        'عندما يجتاحك الهلع أو تتسارع نبضاتك وأفكارك، يساعدك هذا الأسلوب الحسي المعتمد على استعادة الهدوء والعودة الآمنة للحظة الحالية.',
    'step5': 'انظر حولك ولاحظ 5 أشياء يمكنك رُؤيتها بالعين.',
    'step5Hint': 'شكل الإضاءة على الحائط، حذاؤك، نبتة، قطعة أثاث، يديك…',
    'step4': 'انتبه لـ 4 أشياء يمكنك لَمْسها أو الإحساس بها.',
    'step4Hint': 'ملمس قماش ملابسك، برودة الطاولة، ثبات قدميك على الأرض…',
    'step3': 'أصغِ باهتمام لـ 3 أصوات يمكنك سَمَاعها.',
    'step3Hint':
        'صوت سيارة بعيدة، صوت جهاز التكييف، صوت تنفسك، طيور في الخارج…',
    'step2': 'ميّز شيئين (2) يمكنك شَمَّهما.',
    'step2Hint': 'رائحة الهواء، فنجان قهوة، عطرك، أو تخيّل رائحة مهدئة تحبها…',
    'step1': 'لاحظ شيئًا (1) يمكنك تذوّقه أو قل كلمة طمأنينة لنفسك.',
    'step1Hint':
        'اشرب رشفة ماء بارد، أو ردّد: "أنا هنا الآن بأمان. هذه المشاعر ستمضي."',
    'nextStep': 'الخطوة التالية',
    'prevStep': 'الخطوة السابقة',
    'groundingDone': 'أشعر بالهدوء والاتزان الآن',
    'groundingComplete': 'أحسنت صنعًا. خذ نفسًا هادئًا؛ لقد عدت إلى هنا والآن.',
    'senseSight': 'الرؤية',
    'senseTouch': 'اللمس',
    'senseHearing': 'السمع',
    'senseSmell': 'الشم',
    'senseTaste': 'التذوق والسكينة',
    'groundingTapHint': 'المس كل دائرة عندما تلاحظ عنصراً من حولك:',
    'allFound': 'تم تحديد جميع العناصر بنجاح. خذ نفساً عميقاً وهادئاً.',
    'groundingBreatheBtn': 'جلسة تنفّس',
    'restartExercise': 'إعادة التمرين',

    // Journal
    'writeHere':
        'اكتب بكل حرية. هذه المساحة في الذاكرة فقط وتختفي عند إغلاق التطبيق.',
    'noEntries':
        'لا توجد كتابات بعد. دوّن ما تشعر به متى أردت تفريغ ما في داخلك.',
    'journalPrompt1': 'ما هو الفكر الثقيل الذي تود إفراغه وتركه اليوم؟',
    'journalPrompt2':
        'ما هو الشيء البسيط الذي منحك بصيصًا من الطمأنينة أو السلام؟',
    'journalPrompt3': 'ما الذي تحتاجه نفسك منك بلطف في هذا الوقت؟',
  },
};

/// Every translated string, grouped by language code.
///
/// Exposed so tests can prove that no language is missing a key or a
/// placeholder. The app itself should always go through [S].
@visibleForTesting
Map<String, Map<String, String>> get l10nTables => _strings;

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
