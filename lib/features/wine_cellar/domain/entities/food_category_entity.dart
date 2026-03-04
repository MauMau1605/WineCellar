/// Domain entity for food category
class FoodCategoryEntity {
  final int id;
  final String name;
  final String? icon;
  final int sortOrder;

  const FoodCategoryEntity({
    required this.id,
    required this.name,
    this.icon,
    this.sortOrder = 0,
  });
}
