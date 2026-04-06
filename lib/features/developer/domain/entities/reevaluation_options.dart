/// Available field groups that can be re-evaluated by the AI.
enum ReevaluationType {
  drinkingWindow,
  foodPairings,
}

/// Options for a wine re-evaluation session.
class ReevaluationOptions {
  final Set<ReevaluationType> types;

  const ReevaluationOptions({required this.types});

  bool get includesDrinkingWindow =>
      types.contains(ReevaluationType.drinkingWindow);

  bool get includesFoodPairings =>
      types.contains(ReevaluationType.foodPairings);

  bool get isValid => types.isNotEmpty;

  static const ReevaluationOptions all = ReevaluationOptions(
    types: {ReevaluationType.drinkingWindow, ReevaluationType.foodPairings},
  );

  ReevaluationOptions copyWith({Set<ReevaluationType>? types}) =>
      ReevaluationOptions(types: types ?? this.types);
}
