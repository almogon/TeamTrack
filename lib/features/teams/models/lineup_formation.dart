import 'player.dart';
import 'sport_type.dart';

/// A hardcoded formation shape: an ordered list of position codes, one per
/// slot. A slot's position in this list is its persisted `slot_index`.
///
/// This list itself is never stored in the database — only which formation
/// a team picked (`teams.lineup_formation`, matched against [key]) and who
/// occupies each slot (`lineup_slots`) are.
class LineupFormation {
  const LineupFormation({required this.key, required this.slots});

  /// e.g. '4-3-3' — also used as the display label.
  final String key;

  final List<String> slots;

  /// Carries players over from [from] to [to], keeping them in a slot of
  /// their same role where possible. When a role shrinks (e.g. 4-4-2's 4
  /// MID -> 4-3-3's 3 MID), the overflow cascades into the next slot
  /// forward in [roleOrder] (here, the new FWD slot) rather than being
  /// dropped to the bench outright; only overflow that can't be placed
  /// anywhere forward of its original role ends up unassigned (bench).
  /// [roleOrder] must be defense-to-attack (e.g. `[GK, DEF, MID, FWD]`).
  static Map<int, Player> remapAssignments({
    required LineupFormation from,
    required LineupFormation to,
    required Map<int, Player> oldAssignments,
    required List<String> roleOrder,
  }) {
    final oldByRole = <String, List<Player>>{};
    for (var i = 0; i < from.slots.length; i++) {
      final player = oldAssignments[i];
      if (player != null) {
        oldByRole.putIfAbsent(from.slots[i], () => []).add(player);
      }
    }

    final newSlotsByRole = <String, List<int>>{};
    for (var i = 0; i < to.slots.length; i++) {
      newSlotsByRole.putIfAbsent(to.slots[i], () => []).add(i);
    }

    final result = <int, Player>{};
    var carry = <Player>[];
    for (final role in roleOrder) {
      final List<Player> pool = [
        ...oldByRole[role] ?? const <Player>[],
        ...carry,
      ];
      final newSlots = newSlotsByRole[role] ?? const <int>[];
      final placed = pool.take(newSlots.length).toList();
      for (var i = 0; i < placed.length; i++) {
        result[newSlots[i]] = placed[i];
      }
      carry = pool.skip(newSlots.length).toList();
    }
    // Any remaining `carry` after the most attacking role has nowhere
    // further forward to go, so it's simply left unassigned (bench).
    return result;
  }

  static List<LineupFormation> forTeam(SportType sport, String format) =>
      switch (sport) {
        SportType.football => switch (format) {
            '7' => football7,
            '5' => football5,
            _ => football11,
          },
        SportType.basketball => basketball5,
        SportType.volleyball => volleyball6,
      };

  static const football11 = [
    LineupFormation(
      key: '4-4-2',
      slots: [
        'GK',
        'DEF', 'DEF', 'DEF', 'DEF',
        'MID', 'MID', 'MID', 'MID',
        'FWD', 'FWD',
      ],
    ),
    LineupFormation(
      key: '4-3-3',
      slots: [
        'GK',
        'DEF', 'DEF', 'DEF', 'DEF',
        'MID', 'MID', 'MID',
        'FWD', 'FWD', 'FWD',
      ],
    ),
    LineupFormation(
      key: '3-5-2',
      slots: [
        'GK',
        'DEF', 'DEF', 'DEF',
        'MID', 'MID', 'MID', 'MID', 'MID',
        'FWD', 'FWD',
      ],
    ),
    LineupFormation(
      key: '3-4-3',
      slots: [
        'GK',
        'DEF', 'DEF', 'DEF',
        'MID', 'MID', 'MID', 'MID',
        'FWD', 'FWD', 'FWD',
      ],
    ),
  ];

  static const football7 = [
    LineupFormation(
      key: '3-3',
      slots: ['GK', 'DEF', 'DEF', 'DEF', 'FWD', 'FWD', 'FWD'],
    ),
    LineupFormation(
      key: '3-2-1',
      slots: ['GK', 'DEF', 'DEF', 'DEF', 'MID', 'MID', 'FWD'],
    ),
    LineupFormation(
      key: '2-3-1',
      slots: ['GK', 'DEF', 'DEF', 'MID', 'MID', 'MID', 'FWD'],
    ),
    LineupFormation(
      key: '3-1-2',
      slots: ['GK', 'DEF', 'DEF', 'DEF', 'MID', 'FWD', 'FWD'],
    ),
  ];

  static const football5 = [
    LineupFormation(
      key: '2-1-1',
      slots: ['GK', 'DEF', 'DEF', 'MID', 'FWD'],
    ),
    LineupFormation(
      key: '1-2-1',
      slots: ['GK', 'DEF', 'MID', 'MID', 'FWD'],
    ),
    LineupFormation(
      key: '2-2',
      slots: ['GK', 'DEF', 'DEF', 'FWD', 'FWD'],
    ),
  ];

  static const basketball5 = [
    LineupFormation(
      key: 'Starting five',
      slots: ['PG', 'SG', 'SF', 'PF', 'C'],
    ),
  ];

  static const volleyball6 = [
    LineupFormation(
      key: 'Rotation',
      slots: ['S', 'OH', 'OH', 'MB', 'MB', 'OPP'],
    ),
  ];
}
