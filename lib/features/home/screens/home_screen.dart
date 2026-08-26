import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/profile_provider.dart';
import '../../teams/models/lineup_formation.dart';
import '../../teams/models/team.dart';
import '../../teams/providers/lineup_provider.dart';
import '../../teams/providers/teams_provider.dart';
import '../../teams/widgets/lineup_grid_view.dart';
import '../widgets/main_menu_footer.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _pageController = PageController(viewportFraction: 0.86);
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(teamsProvider);
    final planLabel = ref.watch(profileProvider).value?.planLabel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TeamTrack'),
        actions: [
          if (planLabel != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: ActionChip(
                  label: Text(planLabel, style: const TextStyle(fontSize: 11)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onPressed: () => context.push('/subscription'),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (teams) {
          if (teams.isEmpty) {
            return _EmptyState(onCreateTeam: () => context.push('/teams/new'));
          }
          if (_currentIndex >= teams.length) {
            _currentIndex = teams.length - 1;
          }
          final current = teams[_currentIndex];
          return Column(
            children: [
              Expanded(
                child: teams.length == 1
                    ? _TeamFormationPage(team: teams.first)
                    : ScrollConfiguration(
                        // Flutter's default ScrollBehavior only allows
                        // touch/stylus/trackpad to drag-scroll — mouse is
                        // excluded (it's normally reserved for text
                        // selection), so a mouse "swipe" between teams did
                        // nothing. Add mouse explicitly for this carousel.
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            ...ScrollConfiguration.of(context).dragDevices,
                            PointerDeviceKind.mouse,
                          },
                        ),
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: teams.length,
                          onPageChanged: (i) =>
                              setState(() => _currentIndex = i),
                          itemBuilder: (_, i) => Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: _TeamFormationPage(team: teams[i]),
                          ),
                        ),
                      ),
              ),
              if (teams.length > 1)
                _CarouselDots(count: teams.length, index: _currentIndex),
              MainMenuFooter(
                onScores: () =>
                    context.push('/teams/${current.id}', extra: 3),
                onStartMatch: () =>
                    context.push('/teams/${current.id}/matches/new'),
                onEditRoster: () => context.push('/teams/${current.id}'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreateTeam});

  final VoidCallback onCreateTeam;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: FilledButton(
              onPressed: onCreateTeam,
              style: FilledButton.styleFrom(shape: const CircleBorder()),
              child: const Icon(Icons.add, size: 40),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Create your first team',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _TeamFormationPage extends ConsumerWidget {
  const _TeamFormationPage({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lineupAsync = ref.watch(teamLineupProvider(team.id));
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(team.name, style: Theme.of(context).textTheme.titleLarge),
        Text(
          team.sportFormatLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        Expanded(
          child: lineupAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (lineup) {
              // Same default-to-first-formation behavior as the Line-Up
              // tab, so an unsaved team still shows a disposition (all
              // placeholders) rather than nothing.
              final formations =
                  LineupFormation.forTeam(team.sportType, team.format);
              final formation = formations.firstWhere(
                (f) => f.key == lineup.formation,
                orElse: () => formations.first,
              );
              return Column(
                children: [
                  // Always show the resolved formation name — including the
                  // default used for a team that's never saved a line-up —
                  // not just when one is persisted. Otherwise this row's
                  // presence/absence differs per card, which shifted the
                  // pitch up or down and made cards visibly misalign while
                  // scrolling the carousel.
                  Text(
                    formation.key,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  Expanded(
                    child: LineupGridView(
                      team: team,
                      formation: formation,
                      slots: lineup.slots,
                      onSlotTap: (slotIndex) {
                        final player = lineup.slots[slotIndex];
                        if (player != null) {
                          context
                              .push('/teams/${team.id}/players/${player.id}');
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CarouselDots extends StatelessWidget {
  const _CarouselDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == index ? cs.primary : cs.outlineVariant,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}
