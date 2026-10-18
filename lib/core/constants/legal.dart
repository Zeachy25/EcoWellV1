/// Bump this when the Terms / Privacy Policy change.
/// It is saved with each user's consent record.
const kConsentVersion = '2026-10';

class LegalSection {
  const LegalSection(this.title, this.body);
  final String title;
  final String body;
}

// TODO: This is a DRAFT. Review it with your adviser and replace the
// [bracketed] items before real users test the app.
const legalSections = <LegalSection>[
  LegalSection(
    '1. About EcoWell',
    'EcoWell is a wellness app developed as a BSIT capstone project. '
        'It helps adults aged 18 to 60 reduce stress by spending time in '
        'green spaces. Contact: [your email address].',
  ),
  LegalSection(
    '2. What we collect',
    'Account details (name, email, birthdate); your answers and scores '
        'from the short stress checks before and after visits; the green '
        'spaces you visit and when; your location while the app detects '
        'arrival at or exit from a green space (we do not keep a continuous '
        'location trail); posts, photos and comments you share; messages '
        'with the AI coach; and a device token for notifications.',
  ),
  LegalSection(
    '3. Why we collect it',
    'To detect your visits, calculate your Stress Reduction Score, show your '
        'progress, power the community features and reminders, and evaluate '
        'and improve the app as part of our capstone research.',
  ),
  LegalSection(
    '4. Who can see your data',
    'Your visits and stress check results are private to you. Posts and '
        'comments, and your name and profile picture, are visible to other '
        'EcoWell users. We do not sell your '
        'data. We use service providers to run the app: Supabase (database '
        'and hosting), Google (sign-in and maps), and an AI provider for the '
        'coach. They receive only what is needed to provide their service.',
  ),
  LegalSection(
    '5. Your rights',
    'Under the Data Privacy Act of 2012 (RA 10173) you have the right to be '
        'informed, to access and correct your data, to object, to request '
        'deletion, to withdraw your consent, and to file a complaint with '
        'the National Privacy Commission. To use these rights, contact '
        '[your email address].',
  ),
  LegalSection(
    '6. Keeping and deleting data',
    'We keep your data while your account is active. You can ask us to '
        'delete your account and the data linked to it at any time.',
  ),
  LegalSection(
    '7. Security',
    'Data is encrypted in transit, and access rules make sure you can only '
        'read your own private records. No system is perfectly secure, so '
        'please use a strong password.',
  ),
  LegalSection(
    '8. Not medical advice',
    'EcoWell is a wellness tool. It does not diagnose, treat or replace '
        'professional mental health care. If you are in crisis or need '
        'urgent help, contact your local emergency services or a crisis '
        'hotline.',
  ),
  LegalSection(
    '9. Changes',
    'If these terms change in a significant way, we will ask for your '
        'consent again.',
  ),
];
