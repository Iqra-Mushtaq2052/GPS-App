/// Supabase project configuration constants.
/// URL and anon key for the GPS App Supabase project.
class SupabaseConfig {
  SupabaseConfig._();

  static const String projectUrl = 'https://spifmbxhisvdiscrunpv.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNwaWZtYnhoaXN2ZGlzY3J1bnB2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgxODUwMTUsImV4cCI6MjEwMzc2MTAxNX0'
      '.F-PamU890ckzv-MyaOcvPVwkqWPBZExYxLpimJ9RQ-k';

  // Table names
  static const String mosquesTable = 'mosques';
  static const String prayerTimesTable = 'prayer_times';
}
