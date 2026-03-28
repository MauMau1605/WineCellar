import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

/// Sort criteria for the wine list
class WineSort {
  final WineSortField field;
  final bool ascending;

  const WineSort({required this.field, this.ascending = true});

  WineSort copyWith({WineSortField? field, bool? ascending}) {
    return WineSort(
      field: field ?? this.field,
      ascending: ascending ?? this.ascending,
    );
  }

  List<WineEntity> apply(List<WineEntity> wines) {
    final sorted = [...wines];
    sorted.sort((a, b) {
      final cmp = _compare(a, b);
      return ascending ? cmp : -cmp;
    });
    return sorted;
  }

  int _compare(WineEntity a, WineEntity b) {
    switch (field) {
      case WineSortField.name:
        return a.name.compareTo(b.name);
      case WineSortField.vintage:
        return (a.vintage ?? 0).compareTo(b.vintage ?? 0);
      case WineSortField.drinkUntilYear:
        return (a.drinkUntilYear ?? 9999).compareTo(b.drinkUntilYear ?? 9999);
      case WineSortField.drinkFromYear:
        return (a.drinkFromYear ?? 9999).compareTo(b.drinkFromYear ?? 9999);
      case WineSortField.color:
        return a.color.index.compareTo(b.color.index);
      case WineSortField.region:
        return (a.region ?? '').compareTo(b.region ?? '');
      case WineSortField.appellation:
        return (a.appellation ?? '').compareTo(b.appellation ?? '');
      case WineSortField.rating:
        return (a.rating ?? 0).compareTo(b.rating ?? 0);
      case WineSortField.location:
        return (a.location ?? '').compareTo(b.location ?? '');
    }
  }
}
