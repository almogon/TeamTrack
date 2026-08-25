import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A stylized football half-pitch (goal line at the bottom, halfway line —
/// with the center-circle arc — at the top), stretched with [BoxFit.fill]
/// to exactly match whatever area it's placed behind. Used as a
/// [Positioned.fill] background inside [LineupGridView] so it always lines
/// up with the formation rows above it: the goal line sits under the GK
/// row, the halfway line sits above the forward line.
class FootballPitchBackground extends StatelessWidget {
  const FootballPitchBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/pitches/football_half_pitch.svg',
      fit: BoxFit.fill,
    );
  }
}
