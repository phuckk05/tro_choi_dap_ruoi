part of '../fly_swatter_game.dart';

enum _Edge { top, right, bottom, left }

class _PendingCollisionSpawn {
  final Fly first;
  final Fly second;
  double remaining;

  _PendingCollisionSpawn({
    required this.first,
    required this.second,
    required this.remaining,
  });
}

enum ToolType { shield, slap, strikeSet }
