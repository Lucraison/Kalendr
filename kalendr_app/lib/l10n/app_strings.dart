import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class AppStrings {
  final String _locale;
  AppStrings._(this._locale);

  static AppStrings of(BuildContext context) {
    final locale = context.read<AppProvider>().locale;
    return AppStrings._(locale);
  }

  static const supportedLocales = [Locale('en'), Locale('fr'), Locale('es')];

  String call(String key) => _t(key);

  String _t(String key) =>
      _translations[_locale]?[key] ?? _translations['en']![key] ?? key;

  // ── Common ────────────────────────────────────────────────────────────────
  String get cancel => _t('cancel');
  String get save => _t('save');
  String get delete => _t('delete');
  String get edit => _t('edit');
  String get retry => _t('retry');
  String get rename => _t('rename');
  String get leave => _t('leave');
  String get remove => _t('remove');
  String get transfer => _t('transfer');
  String get share => _t('share');
  String get create => _t('create');
  String get join => _t('join');
  String get next => _t('next');
  String get skip => _t('skip');
  String get letsGo => _t('letsGo');
  String get today => _t('today');
  String get personal => _t('personal');
  String get custom => _t('custom');
  String get from => _t('from');
  String get until => _t('until');
  String get hours => _t('hours');
  String get members => _t('members');
  String get owner => _t('owner');
  String get upcoming => _t('upcoming');
  String get settings => _t('settings');
  String get notifications => _t('notifications');
  String get events => _t('events');
  String get groups => _t('groups');
  String get appearance => _t('appearance');
  String get light => _t('light');
  String get system => _t('system');
  String get dark => _t('dark');
  String get logout => _t('logout');
  String get account => _t('account');
  String get selected => _t('selected');
  String get seeAll => _t('seeAll');
  String get language => _t('language');

  // ── Auth / Login ──────────────────────────────────────────────────────────
  String get loginSubtitle => _t('loginSubtitle');
  String get username => _t('username');
  String get email => _t('email');
  String get password => _t('password');
  String get login => _t('login');
  String get register => _t('register');
  String get toggleLogin => _t('toggleLogin');
  String get toggleRegister => _t('toggleRegister');

  // ── Forgot password ───────────────────────────────────────────────────────
  String get forgotPassword => _t('forgotPassword');
  String get checkYourEmail => _t('checkYourEmail');
  String get enterEmailForCode => _t('enterEmailForCode');
  String get sixDigitCode => _t('sixDigitCode');
  String get newPassword => _t('newPassword');
  String get confirmPassword => _t('confirmPassword');
  String get sendCode => _t('sendCode');
  String get resetPassword => _t('resetPassword');
  String get resendCode => _t('resendCode');
  String get backToLogin => _t('backToLogin');
  String get enterYourEmail => _t('enterYourEmail');
  String get enterYourUsername => _t('enterYourUsername');
  String get usernameOrEmail => _t('usernameOrEmail');
  String get enterUsernameOrEmailForCode => _t('enterUsernameOrEmailForCode');
  String get enterCodeFromEmail => _t('enterCodeFromEmail');
  String get passwordAtLeast6 => _t('passwordAtLeast6');
  String get passwordsDoNotMatch => _t('passwordsDoNotMatch');
  String get passwordResetLoginAgain => _t('passwordResetLoginAgain');
  String sentCodeTo(String email) => _t('sentCodeTo').replaceAll('{email}', email);

  // ── Onboarding ────────────────────────────────────────────────────────────
  String get welcomeToKalendr => _t('welcomeToKalendr');
  String get onboardingDesc1 => _t('onboardingDesc1');
  String get groupsKeepYouInSync => _t('groupsKeepYouInSync');
  String get onboardingDesc2 => _t('onboardingDesc2');
  String get reactAndRsvp => _t('reactAndRsvp');
  String get onboardingDesc3 => _t('onboardingDesc3');

  // ── Calendar screen ───────────────────────────────────────────────────────
  String get calendars => _t('calendars');
  String get addTo => _t('addTo');
  String get freeDay => _t('freeDay');
  String get nothingScheduled => _t('nothingScheduled');
  String get removeFromGroup => _t('removeFromGroup');
  String eventCount(int n) => _t(n == 1 ? 'event1count' : 'eventsNcount').replaceAll('{n}', '$n');
  String get onlyVisibleToYou => _t('onlyVisibleToYou');
  String get couldNotLoadEvents => _t('couldNotLoadEvents');
  String get goToGroupsToStart => _t('goToGroupsToStart');
  String get workingToday => _t('workingToday');
  String greetingMorning(String name) => _t('greetingMorning').replaceAll('{name}', name);
  String greetingAfternoon(String name) => _t('greetingAfternoon').replaceAll('{name}', name);
  String greetingEvening(String name) => _t('greetingEvening').replaceAll('{name}', name);
  String eventsToday(int n) => _t(n == 1 ? 'event1Today' : 'eventsNToday').replaceAll('{n}', '$n');

  // ── Add event sheet ───────────────────────────────────────────────────────
  String get newEvent => _t('newEvent');
  String get editEvent => _t('editEvent');
  String get eventTitle => _t('eventTitle');
  String get descriptionOptional => _t('descriptionOptional');
  String get allDay => _t('allDay');
  String get visibleTo => _t('visibleTo');
  String get start => _t('start');
  String get end => _t('end');
  String get endTime => _t('endTime');
  String get startingFrom => _t('startingFrom');
  String get endingOn => _t('endingOn');
  String get repeat => _t('repeat');
  String get repeatNone => _t('repeatNone');
  String get repeatDaily => _t('repeatDaily');
  String get repeatWeekdays => _t('repeatWeekdays');
  String get repeatWeekly => _t('repeatWeekly');
  String get noEndDate => _t('noEndDate');
  String get repeatUntil => _t('repeatUntil');
  String get repeatsUpTo1Year => _t('repeatsUpTo1Year');
  String get saveChanges => _t('saveChanges');
  String get addEvent => _t('addEvent');
  String get titleRequired => _t('titleRequired');
  String get endAfterStart => _t('endAfterStart');
  String get noDaysSelected => _t('noDaysSelected');
  String get noDatesInRange => _t('noDatesInRange');
  String addEvents(int n) => _t(n == 1 ? 'add1Event' : 'addNEvents').replaceAll('{n}', '$n');
  String daysCount(int n) => _t(n == 1 ? 'day1' : 'daysN').replaceAll('{n}', '$n');

  // ── Work schedule sheet ───────────────────────────────────────────────────
  String get workSchedule => _t('workSchedule');
  String get workDays => _t('workDays');
  String get sameHoursEveryDay => _t('sameHoursEveryDay');
  String get dateRange => _t('dateRange');
  String get duration => _t('duration');
  String get nameRequired => _t('nameRequired');
  String get selectAtLeastOneDay => _t('selectAtLeastOneDay');
  String get noShiftsInRange => _t('noShiftsInRange');
  String get addWorkSchedule => _t('addWorkSchedule');
  String shiftCount(int n) => _t(n == 1 ? 'shift1' : 'shiftsN').replaceAll('{n}', '$n');
  String addShifts(int n) => _t(n == 1 ? 'add1Shift' : 'addNShifts').replaceAll('{n}', '$n');

  // ── Type picker ───────────────────────────────────────────────────────────
  String get whatAreYouAdding => _t('whatAreYouAdding');
  String get event => _t('event');
  String get eventTypeDesc => _t('eventTypeDesc');
  String get workScheduleDesc => _t('workScheduleDesc');

  // ── Add event / work schedule (extra) ────────────────────────────────────
  String get startDate => _t('startDate');
  String get endDate => _t('endDate');
  String get startTimeInPast => _t('startTimeInPast');
  String get scheduleNameHint => _t('scheduleNameHint');
  List<String> get weekdayShort => _t('weekdayShort').split(',');
  List<String> get weekdayNames => _t('weekdayLong').split(',');

  // ── Navbar ────────────────────────────────────────────────────────────────
  String get navCalendar => _t('navCalendar');
  String get navActivity => _t('navActivity');
  String get navProfile => _t('navProfile');

  // ── Calendar picker ───────────────────────────────────────────────────────
  String get selectTime => _t('selectTime');
  String confirmDate(String date) => _t('confirmDate').replaceAll('{date}', date);

  // ── Event detail ──────────────────────────────────────────────────────────
  String get editRecurringEvent => _t('editRecurringEvent');
  String get eventRepeatsEditChoice => _t('eventRepeatsEditChoice');
  String get thisEventOnly => _t('thisEventOnly');
  String get allEventsInSeries => _t('allEventsInSeries');
  String thisEventOnlyDesc(String date) => _t('thisEventOnlyDesc').replaceAll('{date}', date);
  String get allEventsInSeriesDesc => _t('allEventsInSeriesDesc');
  String get areYouGoing => _t('areYouGoing');
  String get going => _t('going');
  String get maybe => _t('maybe');
  String get cantGo => _t('cantGo');
  String get reactions => _t('reactions');
  String get comments => _t('comments');
  String get noCommentsYet => _t('noCommentsYet');
  String get addCommentPlaceholder => _t('addCommentPlaceholder');
  String get deleteComment => _t('deleteComment');
  String get deleteEvent => _t('deleteEvent');
  String get deleteEventPermanent => _t('deleteEventPermanent');
  String get justThisOne => _t('justThisOne');
  String get deleteSeries => _t('deleteSeries');
  String deleteOccurrenceOrSeries(String title) => _t('deleteOccurrenceOrSeries').replaceAll('{title}', title);
  String updatedCount(int n) => _t(n == 1 ? 'updated1' : 'updatedN').replaceAll('{n}', '$n');
  String deletedCount(int n) => _t(n == 1 ? 'deleted1' : 'deletedN').replaceAll('{n}', '$n');

  // ── Groups screen ─────────────────────────────────────────────────────────
  String get createAGroup => _t('createAGroup');
  String get joinWithInviteCode => _t('joinWithInviteCode');
  String get myGroups => _t('myGroups');
  String get noGroupsYet => _t('noGroupsYet');
  String get tapPlusToCreate => _t('tapPlusToCreate');
  String get couldNotLoadGroups => _t('couldNotLoadGroups');
  String get inviteCodeCopied => _t('inviteCodeCopied');
  String get groupRenamed => _t('groupRenamed');
  String get groupNameHint => _t('groupNameHint');
  String get groupName => _t('groupName');
  String leaveGroupConfirm(String name) => _t('leaveGroupConfirm').replaceAll('{name}', name);
  String get rejoinWithInviteCode => _t('rejoinWithInviteCode');

  // ── Events screen (group detail) ──────────────────────────────────────────
  String get noEventsYet => _t('noEventsYet');
  String get tapPlusToAdd => _t('tapPlusToAdd');
  String get noUpcomingEvents => _t('noUpcomingEvents');
  String get couldNotLoadEventsScreen => _t('couldNotLoadEventsScreen');
  String get yourColor => _t('yourColor');
  String get transferOwnership => _t('transferOwnership');
  String get becomeRegularMember => _t('becomeRegularMember');
  String get colorUpdated => _t('colorUpdated');
  String get removesEventForEveryone => _t('removesEventForEveryone');
  String memberCount(int n) => _t(n == 1 ? 'member1' : 'membersN').replaceAll('{n}', '$n');
  String pastEvents(int n) => _t(n == 1 ? 'pastEvent1' : 'pastEventsN').replaceAll('{n}', '$n');
  String removeMemberConfirm(String name) => _t('removeMemberConfirm').replaceAll('{name}', name);
  String transferOwnershipConfirm(String name) => _t('transferOwnershipConfirm').replaceAll('{name}', name);
  String deleteEventTitle(String title) => _t('deleteEventTitle').replaceAll('{title}', title);
  String multipleEventDelete(String title, int total) =>
      _t('multipleEventDelete').replaceAll('{title}', title).replaceAll('{total}', '$total');
  String allCount(int n) => _t('allCount').replaceAll('{n}', '$n');

  // ── Notifications screen ──────────────────────────────────────────────────
  String get clearAll => _t('clearAll');
  String get youreAllCaughtUp => _t('youreAllCaughtUp');
  String get newEventsWillAppearHere => _t('newEventsWillAppearHere');
  String get couldNotLoadEvent => _t('couldNotLoadEvent');

  // ── Profile screen ────────────────────────────────────────────────────────
  String get chooseFromGallery => _t('chooseFromGallery');
  String get takeAPhoto => _t('takeAPhoto');
  String get changePassword => _t('changePassword');
  String get changeEmail => _t('changeEmail');
  String get yourGroups => _t('yourGroups');
  String get deleteAccount => _t('deleteAccount');
  String get deleteAccountWarning => _t('deleteAccountWarning');
  String get permanentlyRemovesData => _t('permanentlyRemovesData');
  String get atLeast6Characters => _t('atLeast6Characters');
  String get passwordUpdated => _t('passwordUpdated');
  String get enterValidEmail => _t('enterValidEmail');
  String get emailUpdated => _t('emailUpdated');
  String get currentPassword => _t('currentPassword');
  String get confirmNewPassword => _t('confirmNewPassword');
  String get newEmail => _t('newEmail');
  String get currentPasswordToConfirm => _t('currentPasswordToConfirm');
  String get willNeedLoginAgain => _t('willNeedLoginAgain');

  // ─────────────────────────────────────────────────────────────────────────
  // TRANSLATIONS
  // ─────────────────────────────────────────────────────────────────────────
  static const Map<String, Map<String, String>> _translations = {
    'en': {
      // Common
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'retry': 'Retry',
      'rename': 'Rename',
      'leave': 'Leave',
      'remove': 'Remove',
      'transfer': 'Transfer',
      'share': 'Share',
      'create': 'Create',
      'join': 'Join',
      'next': 'Next',
      'skip': 'Skip',
      'letsGo': "Let's go!",
      'today': 'Today',
      'personal': 'Personal',
      'custom': 'Custom',
      'from': 'From',
      'until': 'Until',
      'hours': 'Hours',
      'members': 'Members',
      'owner': 'Owner',
      'upcoming': 'Upcoming',
      'settings': 'Settings',
      'notifications': 'Notifications',
      'events': 'Events',
      'groups': 'Groups',
      'appearance': 'Appearance',
      'light': 'Light',
      'system': 'System',
      'dark': 'Dark',
      'logout': 'Log out',
      'account': 'Account',
      'selected': 'Selected',
      'seeAll': 'See all',
      'language': 'Language',
      // Auth
      'loginSubtitle': 'Your shared family calendar',
      'username': 'Username',
      'email': 'Email',
      'password': 'Password',
      'login': 'Log In',
      'register': 'Create Account',
      'toggleLogin': 'Already have an account? Log in',
      'toggleRegister': "Don't have an account? Sign up",
      // Forgot password
      'forgotPassword': 'Forgot password?',
      'checkYourEmail': 'Check your email',
      'enterEmailForCode': "Enter your email and we'll send a 6-digit code.",
      'sixDigitCode': '6-digit code',
      'newPassword': 'New password',
      'confirmPassword': 'Confirm password',
      'sendCode': 'Send code',
      'resetPassword': 'Reset password',
      'resendCode': 'Resend code',
      'backToLogin': 'Back to login',
      'enterYourEmail': 'Enter your email.',
      'enterYourUsername': 'Enter your username.',
      'usernameOrEmail': 'Username or email',
      'enterUsernameOrEmailForCode': "Enter your username or email and we'll send a 6-digit code.",
      'enterCodeFromEmail': 'Enter the code from your email.',
      'passwordAtLeast6': 'Password must be at least 6 characters.',
      'passwordsDoNotMatch': 'Passwords do not match.',
      'passwordResetLoginAgain': 'Password reset! Please log in.',
      'sentCodeTo': 'We sent a code to {email}. Enter it below.',
      // Onboarding
      'welcomeToKalendr': 'Welcome to Kalendr',
      'onboardingDesc1': 'A shared calendar for the people that matter — family, friends, teammates.',
      'groupsKeepYouInSync': 'Groups keep you in sync',
      'onboardingDesc2': "Create or join a group, share events, and always know what's coming up.",
      'reactAndRsvp': 'React and RSVP',
      'onboardingDesc3': "Let people know you're going, react to events, and pick your personal color.",
      // Calendar screen
      'calendars': 'Calendars',
      'addTo': 'Add to...',
      'onlyVisibleToYou': 'Only visible to you',
      'couldNotLoadEvents': 'Could not load events',
      'goToGroupsToStart': 'Go to Groups to get started',
      'workingToday': 'Working today',
      'greetingMorning': 'Good morning, {name}! 🌅',
      'greetingAfternoon': 'Good afternoon, {name}! ☀️',
      'greetingEvening': 'Good evening, {name}! 🌙',
      'event1Today': '1 today',
      'eventsNToday': '{n} today',
      'freeDay': 'Free day!',
      'nothingScheduled': 'Nothing scheduled',
      'removeFromGroup': 'Remove from group',
      'event1count': '1 event',
      'eventsNcount': '{n} events',
      // Add event sheet
      'newEvent': 'New Event',
      'editEvent': 'Edit Event',
      'eventTitle': 'Event title',
      'descriptionOptional': 'Description (optional)',
      'allDay': 'All day',
      'visibleTo': 'Visible to',
      'start': 'Start',
      'end': 'End',
      'endTime': 'End time',
      'startingFrom': 'Starting from',
      'endingOn': 'Ending on',
      'repeat': 'Repeat',
      'repeatNone': 'None',
      'repeatDaily': 'Daily',
      'repeatWeekdays': 'Weekdays',
      'repeatWeekly': 'Weekly',
      'noEndDate': 'No end date',
      'repeatUntil': 'Repeat until',
      'repeatsUpTo1Year': 'Repeats up to 1 year from start',
      'saveChanges': 'Save Changes',
      'addEvent': 'Add Event',
      'add1Event': 'Add 1 Event',
      'addNEvents': 'Add {n} Events',
      'titleRequired': 'Title is required',
      'endAfterStart': 'End time must be after start time',
      'noDaysSelected': 'No days selected or no dates in range',
      'noDatesInRange': 'No dates in range',
      'day1': '1 day',
      'daysN': '{n} days',
      // Work schedule
      'workSchedule': 'Work Schedule',
      'workDays': 'Work days',
      'sameHoursEveryDay': 'Same hours every day',
      'dateRange': 'Date range',
      'duration': 'Duration',
      'nameRequired': 'Name is required',
      'selectAtLeastOneDay': 'Select at least one day',
      'noShiftsInRange': 'No shifts in selected date range',
      'addWorkSchedule': 'Add Work Schedule',
      'shift1': '1 shift',
      'shiftsN': '{n} shifts',
      'add1Shift': 'Add 1 Shift',
      'addNShifts': 'Add {n} Shifts',
      // Type picker
      'whatAreYouAdding': 'What are you adding?',
      'event': 'Event',
      'eventTypeDesc': 'A one-time or recurring moment — birthday, meeting, trip...',
      'workScheduleDesc': "Set your recurring work hours so others can see when you're busy",
      // Add event / work schedule (extra)
      'startDate': 'Start date',
      'endDate': 'End date',
      'startTimeInPast': 'Start time is in the past',
      'scheduleNameHint': 'Schedule name (e.g. Work)',
      'weekdayShort': 'M,T,W,T,F,S,S',
      'weekdayLong': 'Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday',
      // Navbar
      'navCalendar': 'Calendar',
      'navActivity': 'Activity',
      'navProfile': 'Profile',
      // Calendar picker
      'selectTime': 'Select time',
      'confirmDate': 'Confirm {date}',
      // Event detail
      'editRecurringEvent': 'Edit recurring event',
      'eventRepeatsEditChoice': 'This event repeats. What do you want to edit?',
      'thisEventOnly': 'This event only',
      'allEventsInSeries': 'All events in series',
      'thisEventOnlyDesc': 'Changes apply only to {date}',
      'allEventsInSeriesDesc': 'Changes apply to every occurrence',
      'areYouGoing': 'Are you going?',
      'going': 'Going',
      'maybe': 'Maybe',
      'cantGo': "Can't",
      'reactions': 'Reactions',
      'comments': 'Comments',
      'noCommentsYet': 'No comments yet. Be the first!',
      'addCommentPlaceholder': 'Add a comment...',
      'deleteComment': 'Delete comment',
      'deleteEvent': 'Delete event?',
      'deleteEventPermanent': 'This will permanently delete "{title}".',
      'justThisOne': 'Just this one',
      'deleteSeries': 'Delete series',
      'deleteOccurrenceOrSeries': 'Delete just this occurrence, or the entire "{title}" series?',
      'updated1': 'Updated 1 event',
      'updatedN': 'Updated {n} events',
      'deleted1': 'Deleted 1 event',
      'deletedN': 'Deleted {n} events',
      // Groups screen
      'createAGroup': 'Create a group',
      'joinWithInviteCode': 'Join with invite code',
      'myGroups': 'My Groups',
      'noGroupsYet': 'No groups yet',
      'tapPlusToCreate': 'Tap + to create one or join with an invite code.',
      'couldNotLoadGroups': 'Could not load groups',
      'inviteCodeCopied': 'Invite code copied!',
      'groupRenamed': 'Group renamed!',
      'groupNameHint': 'Group name...',
      'groupName': 'Group name',
      'leaveGroupConfirm': 'Leave "{name}"?',
      'rejoinWithInviteCode': 'You can rejoin later with an invite code.',
      // Events screen
      'noEventsYet': 'No events yet.',
      'tapPlusToAdd': 'Tap + to add one.',
      'noUpcomingEvents': 'No upcoming events',
      'couldNotLoadEventsScreen': 'Could not load events',
      'yourColor': 'your color',
      'transferOwnership': 'Transfer ownership',
      'becomeRegularMember': 'You will become a regular member.',
      'colorUpdated': 'Color updated!',
      'removesEventForEveryone': 'This removes the event for everyone.',
      'member1': '1 member',
      'membersN': '{n} members',
      'pastEvent1': '1 past event',
      'pastEventsN': '{n} past events',
      'removeMemberConfirm': 'Remove {name}?',
      'transferOwnershipConfirm': 'Transfer ownership to {name}?',
      'deleteEventTitle': 'Delete "{title}"?',
      'multipleEventDelete': 'There are {total} events named "{title}". Delete just this one or all of them?',
      'allCount': 'All {n}',
      // Notifications screen
      'clearAll': 'Clear all',
      'youreAllCaughtUp': "You're all caught up!",
      'newEventsWillAppearHere': 'New events and comments will appear here.',
      'couldNotLoadEvent': 'Could not load event',
      // Profile screen
      'chooseFromGallery': 'Choose from gallery',
      'takeAPhoto': 'Take a photo',
      'changePassword': 'Change password',
      'changeEmail': 'Change email',
      'yourGroups': 'Your Groups',
      'deleteAccount': 'Delete account',
      'deleteAccountWarning': 'This permanently deletes your account, all your events, and removes you from all groups. This cannot be undone.',
      'permanentlyRemovesData': 'Permanently removes all your data',
      'atLeast6Characters': 'At least 6 characters',
      'passwordUpdated': 'Password updated!',
      'enterValidEmail': 'Enter a valid email',
      'emailUpdated': 'Email updated!',
      'currentPassword': 'Current password',
      'confirmNewPassword': 'Confirm new password',
      'newEmail': 'New email',
      'currentPasswordToConfirm': 'Current password (to confirm)',
      'willNeedLoginAgain': 'You will need to log in again.',
    },

    // ── FRENCH ───────────────────────────────────────────────────────────────
    'fr': {
      // Common
      'cancel': 'Annuler',
      'save': 'Enregistrer',
      'delete': 'Supprimer',
      'edit': 'Modifier',
      'retry': 'Réessayer',
      'rename': 'Renommer',
      'leave': 'Quitter',
      'remove': 'Retirer',
      'transfer': 'Transférer',
      'share': 'Partager',
      'create': 'Créer',
      'join': 'Rejoindre',
      'next': 'Suivant',
      'skip': 'Passer',
      'letsGo': 'Allons-y !',
      'today': "Aujourd'hui",
      'personal': 'Personnel',
      'custom': 'Personnalisé',
      'from': 'Du',
      'until': "Jusqu'au",
      'hours': 'Heures',
      'members': 'Membres',
      'owner': 'Propriétaire',
      'upcoming': 'À venir',
      'settings': 'Paramètres',
      'notifications': 'Notifications',
      'events': 'Événements',
      'groups': 'Groupes',
      'appearance': 'Apparence',
      'light': 'Clair',
      'system': 'Système',
      'dark': 'Sombre',
      'logout': 'Se déconnecter',
      'account': 'Compte',
      'selected': 'Sélectionné',
      'seeAll': 'Voir tout',
      'language': 'Langue',
      // Auth
      'loginSubtitle': 'Votre calendrier familial partagé',
      'username': "Nom d'utilisateur",
      'email': 'E-mail',
      'password': 'Mot de passe',
      'login': 'Se connecter',
      'register': 'Créer un compte',
      'toggleLogin': 'Déjà un compte ? Connectez-vous',
      'toggleRegister': 'Pas de compte ? Inscrivez-vous',
      // Forgot password
      'forgotPassword': 'Mot de passe oublié ?',
      'checkYourEmail': 'Vérifiez vos e-mails',
      'enterEmailForCode': 'Entrez votre e-mail et nous vous enverrons un code à 6 chiffres.',
      'sixDigitCode': 'Code à 6 chiffres',
      'newPassword': 'Nouveau mot de passe',
      'confirmPassword': 'Confirmer le mot de passe',
      'sendCode': 'Envoyer le code',
      'resetPassword': 'Réinitialiser le mot de passe',
      'resendCode': 'Renvoyer le code',
      'backToLogin': 'Retour à la connexion',
      'enterYourEmail': 'Entrez votre e-mail.',
      'enterYourUsername': "Entrez votre nom d'utilisateur.",
      'usernameOrEmail': "Nom d'utilisateur ou e-mail",
      'enterUsernameOrEmailForCode': "Entrez votre nom d'utilisateur ou e-mail et nous vous enverrons un code à 6 chiffres.",
      'enterCodeFromEmail': 'Entrez le code reçu par e-mail.',
      'passwordAtLeast6': 'Le mot de passe doit contenir au moins 6 caractères.',
      'passwordsDoNotMatch': 'Les mots de passe ne correspondent pas.',
      'passwordResetLoginAgain': 'Mot de passe réinitialisé ! Veuillez vous connecter.',
      'sentCodeTo': 'Nous avons envoyé un code à {email}. Entrez-le ci-dessous.',
      // Onboarding
      'welcomeToKalendr': 'Bienvenue sur Kalendr',
      'onboardingDesc1': 'Un calendrier partagé pour ceux qui comptent — famille, amis, collègues.',
      'groupsKeepYouInSync': 'Les groupes vous synchronisent',
      'onboardingDesc2': 'Créez ou rejoignez un groupe, partagez des événements et soyez toujours informé.',
      'reactAndRsvp': 'Réagissez et confirmez',
      'onboardingDesc3': 'Dites si vous venez, réagissez aux événements et choisissez votre couleur.',
      // Calendar screen
      'calendars': 'Calendriers',
      'addTo': 'Ajouter à...',
      'onlyVisibleToYou': 'Visible uniquement par vous',
      'couldNotLoadEvents': 'Impossible de charger les événements',
      'goToGroupsToStart': 'Allez dans Groupes pour commencer',
      'workingToday': 'Au travail aujourd\'hui',
      'greetingMorning': 'Bonjour, {name} ! 🌅',
      'greetingAfternoon': 'Bon après-midi, {name} ! ☀️',
      'greetingEvening': 'Bonsoir, {name} ! 🌙',
      'event1Today': '1 aujourd\'hui',
      'eventsNToday': '{n} aujourd\'hui',
      'freeDay': 'Journée libre !',
      'nothingScheduled': 'Rien de prévu',
      'removeFromGroup': 'Retirer du groupe',
      'event1count': '1 événement',
      'eventsNcount': '{n} événements',
      // Add event sheet
      'newEvent': 'Nouvel événement',
      'editEvent': "Modifier l'événement",
      'eventTitle': "Titre de l'événement",
      'descriptionOptional': 'Description (facultatif)',
      'allDay': 'Toute la journée',
      'visibleTo': 'Visible par',
      'start': 'Début',
      'end': 'Fin',
      'endTime': 'Heure de fin',
      'startingFrom': 'À partir du',
      'endingOn': "Jusqu'au",
      'repeat': 'Répéter',
      'repeatNone': 'Aucun',
      'repeatDaily': 'Quotidien',
      'repeatWeekdays': 'Jours ouvrés',
      'repeatWeekly': 'Hebdomadaire',
      'noEndDate': 'Sans date de fin',
      'repeatUntil': "Répéter jusqu'au",
      'repeatsUpTo1Year': "Répète jusqu'à 1 an depuis le début",
      'saveChanges': 'Enregistrer',
      'addEvent': 'Ajouter',
      'add1Event': 'Ajouter 1 événement',
      'addNEvents': 'Ajouter {n} événements',
      'titleRequired': 'Le titre est requis',
      'endAfterStart': 'La fin doit être après le début',
      'noDaysSelected': 'Aucun jour sélectionné ou aucune date dans la plage',
      'noDatesInRange': 'Aucune date dans la plage',
      'day1': '1 jour',
      'daysN': '{n} jours',
      // Work schedule
      'workSchedule': 'Horaires de travail',
      'workDays': 'Jours de travail',
      'sameHoursEveryDay': 'Mêmes heures chaque jour',
      'dateRange': 'Plage de dates',
      'duration': 'Durée',
      'nameRequired': 'Le nom est requis',
      'selectAtLeastOneDay': 'Sélectionnez au moins un jour',
      'noShiftsInRange': 'Aucun quart dans la plage de dates',
      'addWorkSchedule': 'Ajouter les horaires',
      'shift1': '1 quart',
      'shiftsN': '{n} quarts',
      'add1Shift': 'Ajouter 1 quart',
      'addNShifts': 'Ajouter {n} quarts',
      // Type picker
      'whatAreYouAdding': 'Que voulez-vous ajouter ?',
      'event': 'Événement',
      'eventTypeDesc': 'Un moment unique ou récurrent — anniversaire, réunion, voyage...',
      'workScheduleDesc': 'Définissez vos heures de travail récurrentes pour que les autres sachent quand vous êtes occupé',
      // Add event / work schedule (extra)
      'startDate': 'Date de début',
      'endDate': 'Date de fin',
      'startTimeInPast': "L'heure de début est dans le passé",
      'scheduleNameHint': 'Nom (ex : Travail)',
      'weekdayShort': 'L,M,M,J,V,S,D',
      'weekdayLong': 'Lundi,Mardi,Mercredi,Jeudi,Vendredi,Samedi,Dimanche',
      // Navbar
      'navCalendar': 'Calendrier',
      'navActivity': 'Activité',
      'navProfile': 'Profil',
      // Calendar picker
      'selectTime': "Sélectionner l'heure",
      'confirmDate': 'Confirmer {date}',
      // Event detail
      'editRecurringEvent': 'Modifier un événement récurrent',
      'eventRepeatsEditChoice': 'Cet événement se répète. Que voulez-vous modifier ?',
      'thisEventOnly': 'Cet événement uniquement',
      'allEventsInSeries': 'Tous les événements de la série',
      'thisEventOnlyDesc': "Les modifications s'appliquent uniquement au {date}",
      'allEventsInSeriesDesc': "Les modifications s'appliquent à toutes les occurrences",
      'areYouGoing': 'Vous y allez ?',
      'going': "J'y vais",
      'maybe': 'Peut-être',
      'cantGo': "Non",
      'reactions': 'Réactions',
      'comments': 'Commentaires',
      'noCommentsYet': 'Pas encore de commentaires. Soyez le premier !',
      'addCommentPlaceholder': 'Ajouter un commentaire...',
      'deleteComment': 'Supprimer le commentaire',
      'deleteEvent': "Supprimer l'événement ?",
      'deleteEventPermanent': 'Cela supprimera définitivement "{title}".',
      'justThisOne': 'Juste celui-ci',
      'deleteSeries': 'Supprimer la série',
      'deleteOccurrenceOrSeries': 'Supprimer cette occurrence ou toute la série "{title}" ?',
      'updated1': '1 événement mis à jour',
      'updatedN': '{n} événements mis à jour',
      'deleted1': '1 événement supprimé',
      'deletedN': '{n} événements supprimés',
      // Groups screen
      'createAGroup': 'Créer un groupe',
      'joinWithInviteCode': "Rejoindre avec un code d'invitation",
      'myGroups': 'Mes groupes',
      'noGroupsYet': 'Aucun groupe pour le moment',
      'tapPlusToCreate': "Appuyez sur + pour en créer un ou rejoindre avec un code d'invitation.",
      'couldNotLoadGroups': 'Impossible de charger les groupes',
      'inviteCodeCopied': "Code d'invitation copié !",
      'groupRenamed': 'Groupe renommé !',
      'groupNameHint': 'Nom du groupe...',
      'groupName': 'Nom du groupe',
      'leaveGroupConfirm': 'Quitter « {name} » ?',
      'rejoinWithInviteCode': "Vous pouvez rejoindre à nouveau avec un code d'invitation.",
      // Events screen
      'noEventsYet': 'Aucun événement pour le moment.',
      'tapPlusToAdd': 'Appuyez sur + pour en ajouter un.',
      'noUpcomingEvents': 'Aucun événement à venir',
      'couldNotLoadEventsScreen': 'Impossible de charger les événements',
      'yourColor': 'votre couleur',
      'transferOwnership': 'Transférer la propriété',
      'becomeRegularMember': 'Vous deviendrez un membre ordinaire.',
      'colorUpdated': 'Couleur mise à jour !',
      'removesEventForEveryone': "Cela supprime l'événement pour tout le monde.",
      'member1': '1 membre',
      'membersN': '{n} membres',
      'pastEvent1': '1 événement passé',
      'pastEventsN': '{n} événements passés',
      'removeMemberConfirm': 'Retirer {name} ?',
      'transferOwnershipConfirm': 'Transférer la propriété à {name} ?',
      'deleteEventTitle': 'Supprimer « {title} » ?',
      'multipleEventDelete': 'Il y a {total} événements nommés « {title} ». Supprimer uniquement celui-ci ou tous ?',
      'allCount': 'Tous ({n})',
      // Notifications
      'clearAll': 'Tout effacer',
      'youreAllCaughtUp': 'Vous êtes à jour !',
      'newEventsWillAppearHere': 'Les nouveaux événements et commentaires apparaîtront ici.',
      'couldNotLoadEvent': "Impossible de charger l'événement",
      // Profile
      'chooseFromGallery': 'Choisir dans la galerie',
      'takeAPhoto': 'Prendre une photo',
      'changePassword': 'Changer le mot de passe',
      'changeEmail': "Changer l'e-mail",
      'yourGroups': 'Vos groupes',
      'deleteAccount': 'Supprimer le compte',
      'deleteAccountWarning': 'Cela supprime définitivement votre compte, tous vos événements et vous retire de tous les groupes. Cette action est irréversible.',
      'permanentlyRemovesData': 'Supprime définitivement toutes vos données',
      'atLeast6Characters': 'Au moins 6 caractères',
      'passwordUpdated': 'Mot de passe mis à jour !',
      'enterValidEmail': 'Entrez un e-mail valide',
      'emailUpdated': 'E-mail mis à jour !',
      'currentPassword': 'Mot de passe actuel',
      'confirmNewPassword': 'Confirmer le nouveau mot de passe',
      'newEmail': 'Nouvel e-mail',
      'currentPasswordToConfirm': 'Mot de passe actuel (pour confirmer)',
      'willNeedLoginAgain': 'Vous devrez vous reconnecter.',
    },

    // ── SPANISH ───────────────────────────────────────────────────────────────
    'es': {
      // Common
      'cancel': 'Cancelar',
      'save': 'Guardar',
      'delete': 'Eliminar',
      'edit': 'Editar',
      'retry': 'Reintentar',
      'rename': 'Renombrar',
      'leave': 'Salir',
      'remove': 'Eliminar',
      'transfer': 'Transferir',
      'share': 'Compartir',
      'create': 'Crear',
      'join': 'Unirse',
      'next': 'Siguiente',
      'skip': 'Omitir',
      'letsGo': '¡Vamos!',
      'today': 'Hoy',
      'personal': 'Personal',
      'custom': 'Personalizado',
      'from': 'Desde',
      'until': 'Hasta',
      'hours': 'Horas',
      'members': 'Miembros',
      'owner': 'Propietario',
      'upcoming': 'Próximos',
      'settings': 'Ajustes',
      'notifications': 'Notificaciones',
      'events': 'Eventos',
      'groups': 'Grupos',
      'appearance': 'Apariencia',
      'light': 'Claro',
      'system': 'Sistema',
      'dark': 'Oscuro',
      'logout': 'Cerrar sesión',
      'account': 'Cuenta',
      'selected': 'Seleccionado',
      'seeAll': 'Ver todo',
      'language': 'Idioma',
      // Auth
      'loginSubtitle': 'Tu calendario familiar compartido',
      'username': 'Usuario',
      'email': 'Correo',
      'password': 'Contraseña',
      'login': 'Iniciar sesión',
      'register': 'Crear cuenta',
      'toggleLogin': '¿Ya tienes cuenta? Inicia sesión',
      'toggleRegister': '¿No tienes cuenta? Regístrate',
      // Forgot password
      'forgotPassword': '¿Olvidaste tu contraseña?',
      'checkYourEmail': 'Revisa tu correo',
      'enterEmailForCode': 'Ingresa tu correo y te enviaremos un código de 6 dígitos.',
      'sixDigitCode': 'Código de 6 dígitos',
      'newPassword': 'Nueva contraseña',
      'confirmPassword': 'Confirmar contraseña',
      'sendCode': 'Enviar código',
      'resetPassword': 'Restablecer contraseña',
      'resendCode': 'Reenviar código',
      'backToLogin': 'Volver al inicio de sesión',
      'enterYourEmail': 'Ingresa tu correo.',
      'enterYourUsername': 'Ingresa tu usuario.',
      'usernameOrEmail': 'Usuario o correo',
      'enterUsernameOrEmailForCode': 'Ingresa tu usuario o correo y te enviaremos un código de 6 dígitos.',
      'enterCodeFromEmail': 'Ingresa el código de tu correo.',
      'passwordAtLeast6': 'La contraseña debe tener al menos 6 caracteres.',
      'passwordsDoNotMatch': 'Las contraseñas no coinciden.',
      'passwordResetLoginAgain': '¡Contraseña restablecida! Por favor inicia sesión.',
      'sentCodeTo': 'Enviamos un código a {email}. Ingrésalo a continuación.',
      // Onboarding
      'welcomeToKalendr': 'Bienvenido a Kalendr',
      'onboardingDesc1': 'Un calendario compartido para los que importan — familia, amigos, compañeros.',
      'groupsKeepYouInSync': 'Los grupos te mantienen sincronizado',
      'onboardingDesc2': 'Crea o únete a un grupo, comparte eventos y siempre sabe qué viene.',
      'reactAndRsvp': 'Reacciona y confirma asistencia',
      'onboardingDesc3': 'Dile a todos si vas, reacciona a eventos y elige tu color personal.',
      // Calendar screen
      'calendars': 'Calendarios',
      'addTo': 'Agregar a...',
      'onlyVisibleToYou': 'Solo visible para ti',
      'couldNotLoadEvents': 'No se pudieron cargar los eventos',
      'goToGroupsToStart': 'Ve a Grupos para comenzar',
      'workingToday': 'Trabajando hoy',
      'greetingMorning': '¡Buenos días, {name}! 🌅',
      'greetingAfternoon': '¡Buenas tardes, {name}! ☀️',
      'greetingEvening': '¡Buenas noches, {name}! 🌙',
      'event1Today': '1 hoy',
      'eventsNToday': '{n} hoy',
      'freeDay': '¡Día libre!',
      'nothingScheduled': 'Nada programado',
      'removeFromGroup': 'Eliminar del grupo',
      'event1count': '1 evento',
      'eventsNcount': '{n} eventos',
      // Add event sheet
      'newEvent': 'Nuevo evento',
      'editEvent': 'Editar evento',
      'eventTitle': 'Título del evento',
      'descriptionOptional': 'Descripción (opcional)',
      'allDay': 'Todo el día',
      'visibleTo': 'Visible para',
      'start': 'Inicio',
      'end': 'Fin',
      'endTime': 'Hora de fin',
      'startingFrom': 'A partir del',
      'endingOn': 'Hasta el',
      'repeat': 'Repetir',
      'repeatNone': 'Ninguno',
      'repeatDaily': 'Diario',
      'repeatWeekdays': 'Días hábiles',
      'repeatWeekly': 'Semanal',
      'noEndDate': 'Sin fecha de fin',
      'repeatUntil': 'Repetir hasta',
      'repeatsUpTo1Year': 'Se repite hasta 1 año desde el inicio',
      'saveChanges': 'Guardar cambios',
      'addEvent': 'Agregar evento',
      'add1Event': 'Agregar 1 evento',
      'addNEvents': 'Agregar {n} eventos',
      'titleRequired': 'El título es obligatorio',
      'endAfterStart': 'La hora de fin debe ser después del inicio',
      'noDaysSelected': 'Ningún día seleccionado o sin fechas en el rango',
      'noDatesInRange': 'Sin fechas en el rango',
      'day1': '1 día',
      'daysN': '{n} días',
      // Work schedule
      'workSchedule': 'Horario de trabajo',
      'workDays': 'Días laborales',
      'sameHoursEveryDay': 'Mismas horas cada día',
      'dateRange': 'Rango de fechas',
      'duration': 'Duración',
      'nameRequired': 'El nombre es obligatorio',
      'selectAtLeastOneDay': 'Selecciona al menos un día',
      'noShiftsInRange': 'Sin turnos en el rango de fechas',
      'addWorkSchedule': 'Agregar horario',
      'shift1': '1 turno',
      'shiftsN': '{n} turnos',
      'add1Shift': 'Agregar 1 turno',
      'addNShifts': 'Agregar {n} turnos',
      // Type picker
      'whatAreYouAdding': '¿Qué vas a agregar?',
      'event': 'Evento',
      'eventTypeDesc': 'Un momento único o recurrente — cumpleaños, reunión, viaje...',
      'workScheduleDesc': 'Configura tus horas de trabajo recurrentes para que otros sepan cuándo estás ocupado',
      // Add event / work schedule (extra)
      'startDate': 'Fecha de inicio',
      'endDate': 'Fecha de fin',
      'startTimeInPast': 'La hora de inicio es en el pasado',
      'scheduleNameHint': 'Nombre del horario (ej: Trabajo)',
      'weekdayShort': 'L,M,X,J,V,S,D',
      'weekdayLong': 'Lunes,Martes,Miércoles,Jueves,Viernes,Sábado,Domingo',
      // Navbar
      'navCalendar': 'Calendario',
      'navActivity': 'Actividad',
      'navProfile': 'Perfil',
      // Calendar picker
      'selectTime': 'Seleccionar hora',
      'confirmDate': 'Confirmar {date}',
      // Event detail
      'editRecurringEvent': 'Editar evento recurrente',
      'eventRepeatsEditChoice': '¿Qué quieres editar de este evento recurrente?',
      'thisEventOnly': 'Solo este evento',
      'allEventsInSeries': 'Todos los eventos de la serie',
      'thisEventOnlyDesc': 'Los cambios se aplican solo al {date}',
      'allEventsInSeriesDesc': 'Los cambios se aplican a todas las ocurrencias',
      'areYouGoing': '¿Vas a ir?',
      'going': 'Voy',
      'maybe': 'Tal vez',
      'cantGo': 'No',
      'reactions': 'Reacciones',
      'comments': 'Comentarios',
      'noCommentsYet': 'Sin comentarios aún. ¡Sé el primero!',
      'addCommentPlaceholder': 'Agregar un comentario...',
      'deleteComment': 'Eliminar comentario',
      'deleteEvent': '¿Eliminar evento?',
      'deleteEventPermanent': 'Esto eliminará permanentemente "{title}".',
      'justThisOne': 'Solo este',
      'deleteSeries': 'Eliminar serie',
      'deleteOccurrenceOrSeries': '¿Eliminar solo esta ocurrencia o toda la serie "{title}"?',
      'updated1': '1 evento actualizado',
      'updatedN': '{n} eventos actualizados',
      'deleted1': '1 evento eliminado',
      'deletedN': '{n} eventos eliminados',
      // Groups screen
      'createAGroup': 'Crear un grupo',
      'joinWithInviteCode': 'Unirse con código de invitación',
      'myGroups': 'Mis grupos',
      'noGroupsYet': 'Aún no hay grupos',
      'tapPlusToCreate': 'Toca + para crear uno o únete con un código de invitación.',
      'couldNotLoadGroups': 'No se pudieron cargar los grupos',
      'inviteCodeCopied': '¡Código de invitación copiado!',
      'groupRenamed': '¡Grupo renombrado!',
      'groupNameHint': 'Nombre del grupo...',
      'groupName': 'Nombre del grupo',
      'leaveGroupConfirm': '¿Salir de "{name}"?',
      'rejoinWithInviteCode': 'Puedes unirte de nuevo con un código de invitación.',
      // Events screen
      'noEventsYet': 'Aún no hay eventos.',
      'tapPlusToAdd': 'Toca + para agregar uno.',
      'noUpcomingEvents': 'No hay eventos próximos',
      'couldNotLoadEventsScreen': 'No se pudieron cargar los eventos',
      'yourColor': 'tu color',
      'transferOwnership': 'Transferir propiedad',
      'becomeRegularMember': 'Te convertirás en miembro regular.',
      'colorUpdated': '¡Color actualizado!',
      'removesEventForEveryone': 'Esto elimina el evento para todos.',
      'member1': '1 miembro',
      'membersN': '{n} miembros',
      'pastEvent1': '1 evento pasado',
      'pastEventsN': '{n} eventos pasados',
      'removeMemberConfirm': '¿Eliminar a {name}?',
      'transferOwnershipConfirm': '¿Transferir propiedad a {name}?',
      'deleteEventTitle': '¿Eliminar "{title}"?',
      'multipleEventDelete': 'Hay {total} eventos llamados "{title}". ¿Eliminar solo este o todos?',
      'allCount': 'Todos ({n})',
      // Notifications
      'clearAll': 'Borrar todo',
      'youreAllCaughtUp': '¡Estás al día!',
      'newEventsWillAppearHere': 'Los nuevos eventos y comentarios aparecerán aquí.',
      'couldNotLoadEvent': 'No se pudo cargar el evento',
      // Profile
      'chooseFromGallery': 'Elegir de la galería',
      'takeAPhoto': 'Tomar una foto',
      'changePassword': 'Cambiar contraseña',
      'changeEmail': 'Cambiar correo',
      'yourGroups': 'Tus grupos',
      'deleteAccount': 'Eliminar cuenta',
      'deleteAccountWarning': 'Esto elimina permanentemente tu cuenta, todos tus eventos y te elimina de todos los grupos. Esta acción no se puede deshacer.',
      'permanentlyRemovesData': 'Elimina permanentemente todos tus datos',
      'atLeast6Characters': 'Al menos 6 caracteres',
      'passwordUpdated': '¡Contraseña actualizada!',
      'enterValidEmail': 'Ingresa un correo válido',
      'emailUpdated': '¡Correo actualizado!',
      'currentPassword': 'Contraseña actual',
      'confirmNewPassword': 'Confirmar nueva contraseña',
      'newEmail': 'Nuevo correo',
      'currentPasswordToConfirm': 'Contraseña actual (para confirmar)',
      'willNeedLoginAgain': 'Deberás iniciar sesión de nuevo.',
    },
  };
}

extension AppStringsX on BuildContext {
  AppStrings get s => AppStrings.of(this);
}
