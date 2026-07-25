/// Categoria com suas subcategorias, usada tanto para gastos/deudas quanto
/// para ingresos/inversiones. Tudo é customizável pelo usuário.
class CategoryDef {
  String name;
  List<String> subcategories;
  String icon; // nome do ícone Material (chave em icon_map.dart)

  CategoryDef({
    required this.name,
    required this.subcategories,
    this.icon = 'category',
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'subcategories': subcategories,
    'icon': icon,
  };

  factory CategoryDef.fromJson(Map<String, dynamic> json) => CategoryDef(
    name: json['name'] as String,
    subcategories: (json['subcategories'] as List)
        .map((e) => e.toString())
        .toList(),
    icon: json['icon'] as String? ?? 'category',
  );
}
