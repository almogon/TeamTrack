import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/teams/models/player.dart';

const _maxAliasLength = 10;

/// A tappable rotated-square "diamond" token showing a player's shirt number,
/// with their alias (if set) captioned underneath, truncated past
/// [_maxAliasLength] characters. Used by both the main menu's read-only
/// formation view and the editable Line-Up slot grid, so the two share the
/// same visual language.
class PlayerDiamond extends StatelessWidget {
  const PlayerDiamond({super.key, required this.player, required this.onTap});

  final Player player;
  final VoidCallback onTap;

  String? get _aliasLabel {
    final alias = player.alias;
    if (alias == null || alias.isEmpty) return null;
    return alias.length > _maxAliasLength
        ? '${alias.substring(0, _maxAliasLength)}…'
        : alias;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final alias = _aliasLabel;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                border: Border.all(color: cs.primary, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Transform.rotate(
                  angle: -math.pi / 4,
                  child: Text(
                    player.number != null
                        ? '${player.number}'
                        : player.initials,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (alias != null) ...[
            const SizedBox(height: 4),
            Text(
              alias,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 3),
                    ],
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
