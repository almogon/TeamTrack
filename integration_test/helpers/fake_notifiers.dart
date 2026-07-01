import 'package:team_track/features/matches/models/match.dart';
import 'package:team_track/features/matches/providers/match_list_provider.dart';
import 'package:team_track/features/teams/models/player.dart';
import 'package:team_track/features/teams/models/team.dart';
import 'package:team_track/features/teams/providers/teams_provider.dart';

// ── Fake data fixtures ────────────────────────────────────────────────────────

final fakeTeam = Team(
  id: 'team-1',
  ownerId: 'user-1',
  name: 'Real Madrid Test',
  sport: 'football',
  format: '11',
  createdAt: DateTime(2026, 1, 1),
);

final fakePlayers = [
  const Player(
    id: 'p1',
    teamId: 'team-1',
    name: 'Toni Kroos',
    number: 8,
    active: true,
  ),
  const Player(
    id: 'p2',
    teamId: 'team-1',
    name: 'Luka Modrić',
    number: 10,
    active: true,
  ),
];

// ── Fake notifiers ────────────────────────────────────────────────────────────

class FakeTeamsNotifier extends TeamsNotifier {
  FakeTeamsNotifier(this._teams);
  final List<Team> _teams;

  @override
  Future<List<Team>> build() async => _teams;
}

class FakeMatchListNotifier extends MatchListNotifier {
  FakeMatchListNotifier(this._matches);
  final List<Match> _matches;

  @override
  Future<List<Match>> build(String arg) async => _matches;
}
