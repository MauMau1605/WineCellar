import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';

class ChatCellarNamingHelper {
  ChatCellarNamingHelper._();

  static String buildDefaultCellarName(
    List<VirtualCellarEntity> existingCellars,
  ) {
    final lowerNames = existingCellars
        .map((cellar) => cellar.name.trim().toLowerCase())
        .toSet();

    if (!lowerNames.contains('ma cave')) {
      return 'Ma cave';
    }

    var suffix = 2;
    while (lowerNames.contains('ma cave $suffix')) {
      suffix++;
    }
    return 'Ma cave $suffix';
  }
}