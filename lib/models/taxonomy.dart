import 'enums.dart';

/// Categoria com suas subcategorias. Categorias padrão vêm marcadas com
/// [isCustom]=false; categorias criadas pelo usuário são sempre isCustom=true,
/// e são exibidas com um indicador "*" nas listas (itens padrão primeiro).
///
/// [controllability] é a classificação padrão da categoria; [subControllability]
/// permite refinar por subcategoria específica. Essa informação é interna —
/// nunca aparece como conceito na UI — e alimenta o motor de recomendações.
class CategoryDef {
  String name;
  List<String> subcategories;
  String icon;
  bool isCustom;
  Controllability controllability;
  Map<String, Controllability> subControllability;

  CategoryDef({
    required this.name,
    required this.subcategories,
    this.icon = 'category',
    this.isCustom = false,
    this.controllability = Controllability.semiControlable,
    Map<String, Controllability>? subControllability,
  }) : subControllability = subControllability ?? {};

  Controllability controllabilityFor(String? subcategory) {
    if (subcategory != null && subControllability.containsKey(subcategory)) {
      return subControllability[subcategory]!;
    }
    return controllability;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'subcategories': subcategories,
    'icon': icon,
    'isCustom': isCustom,
    'controllability': controllability.name,
    'subControllability': subControllability.map((k, v) => MapEntry(k, v.name)),
  };

  factory CategoryDef.fromJson(Map<String, dynamic> json) => CategoryDef(
    name: json['name'] as String,
    subcategories: (json['subcategories'] as List)
        .map((e) => e.toString())
        .toList(),
    icon: json['icon'] as String? ?? 'category',
    isCustom: json['isCustom'] as bool? ?? true,
    controllability: Controllability.values.firstWhere(
      (c) =>
          c.name == (json['controllability'] as String? ?? 'semiControlable'),
      orElse: () => Controllability.semiControlable,
    ),
    subControllability:
        (json['subControllability'] as Map?)?.map(
          (k, v) => MapEntry(
            k.toString(),
            Controllability.values.firstWhere(
              (c) => c.name == v,
              orElse: () => Controllability.semiControlable,
            ),
          ),
        ) ??
        {},
  );
}
