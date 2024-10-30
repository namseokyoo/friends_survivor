import 'package:flutter/material.dart';

class ExperiencePoint {
  final Offset position;
  final bool isTriple;

  ExperiencePoint(this.position, this.isTriple);

  Color get color => isTriple ? Colors.green : Colors.yellow;
  int get value => isTriple ? 3 : 1;
}
