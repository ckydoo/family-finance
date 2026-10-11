# Mhuri premium UI refinement

This pass keeps the existing Mhuri architecture and business logic intact while tightening the visual system for a calmer, denser mobile product.

## Applied
- Home header now prioritizes the greeting/user while keeping family switching compact underneath.
- Family Chat remains a compact header action with unread count instead of a full navigation card.
- Global typography hierarchy is slightly quieter for section/title styles.
- Global quick-add FAB is circular, lower-elevation, and visually smaller/lighter.
- Budget records use dense list rows and hairline separators instead of repeated floating cards.
- Existing large-data search/filter behavior, Savings Goals/Contributions/Debts segmentation, Tasks, Chat, and Family architecture are preserved.

## Validation note
The supplied execution environment does not include the Flutter/Dart SDK, so `flutter analyze` and `flutter test` could not be executed here. Run both locally before release.
