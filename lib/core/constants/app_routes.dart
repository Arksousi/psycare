// app_routes.dart
// Named route constants used for navigation across PsyCare.

/// Centralized route name constants to avoid magic strings in navigation calls.
class AppRoutes {
  AppRoutes._(); // Prevent instantiation

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';

  // Patient routes
  static const String patientDashboard = '/patient-dashboard';
  static const String assessmentIntro = '/assessment-intro';
  static const String assessment = '/assessment';
  static const String assessmentComplete = '/assessment-complete';

  // Therapist routes
  static const String therapistDashboard = '/therapist-dashboard';
  static const String patientList = '/patient-list';
  static const String patientDetail = '/patient-detail';

  // New patient routes
  static const String dsm5Questions = '/dsm5';
  static const String openText = '/open-text';
  static const String aiSummary = '/ai-summary';
  static const String postAssessment = '/post-assessment';
  static const String immediateChatWaiting = '/immediate-chat-waiting';
  static const String chat = '/chat';
  static const String therapistDirectory = '/therapist-directory';
  static const String therapistProfile = '/therapist-profile';
  static const String bookingConsent = '/booking-consent';

  // New therapist routes
  static const String incomingRequests = '/incoming-requests';
  static const String bookingRequests = '/booking-requests';
static const String therapistProfileEdit = '/therapist-profile-edit';

  // Shared
  static const String chatSessions = '/chat-sessions';
  static const String journal = '/journal';

  // Chatbot
  static const String chatbot = '/chatbot';

  // Volunteer routes
  static const String volunteerProfileSetup = '/volunteer-profile-setup';
  static const String volunteerDashboard = '/volunteer-dashboard';
  static const String myConnections = '/my-connections';
  static const String browseVolunteers = '/browse-volunteers';
  static const String browsePatients = '/browse-patients';
  static const String volunteerProfile = '/volunteer-profile';
  static const String volunteerChat = '/volunteer-chat';

  // Shared routes
  static const String settings = '/settings';
}
