// The 4-item Perceived Stress Scale (PSS-4).
// Items 1 and 4 are scored directly; items 2 and 3 are reverse-scored.
// The database computes the total (0-16, lower = less stress).
//
// TODO: The official PSS-4 asks about "the last month". Because EcoWell
// measures stress before and after a visit, the wording below is adapted to
// "right now". Replace these with the exact wording from your proposal.
const pss4Questions = <String>[
  'Right now, how often do you feel unable to control the important things in your life?',
  'Right now, how often do you feel confident about your ability to handle your personal problems?',
  'Right now, how often do you feel that things are going your way?',
  'Right now, how often do you feel that difficulties are piling up so high that you cannot overcome them?',
];

/// Answer value = position in this list (0-4).
const pssOptions = <String>[
  'Never',
  'Almost never',
  'Sometimes',
  'Fairly often',
  'Very often',
];
