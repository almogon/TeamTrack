import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A stylized football pitch/court, stretched with [BoxFit.fill] to exactly
/// match whatever area it's placed behind. Used as a [Positioned.fill]
/// background inside [LineupGridView] so it always lines up with the
/// formation rows above it: the goal line sits under the GK row, the
/// halfway line sits above the forward line.
///
/// Football 5 (futsal) gets its own indoor-court asset ([isFutsal]) — a
/// salmon floor with the futsal-specific "D" goal area and second-penalty
/// arc, instead of the grass half-pitch used for 7 and 11-a-side.
class FootballPitchBackground extends StatelessWidget {
  const FootballPitchBackground({super.key, this.isFutsal = false});

  final bool isFutsal;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      isFutsal
          ? 'assets/pitches/futsal_court.svg'
          : 'assets/pitches/football_half_pitch.svg',
      fit: BoxFit.fill,
    );
  }
}
