/// Tom de um insight, usado para escolher cor/ícone na UI sem que o motor
/// de inteligência precise conhecer detalhes visuais.
enum InsightTone { positivo, alerta, neutro, peligro }

/// Uma frase interpretativa gerada pelo motor de inteligência financeira.
/// Substitui números/tabelas por linguagem natural sempre que possível.
class Insight {
  final String text;
  final InsightTone tone;
  final String iconKey;

  const Insight({
    required this.text,
    this.tone = InsightTone.neutro,
    this.iconKey = 'info',
  });
}
