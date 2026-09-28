Map<String, dynamic> catalogJson([String context = 'Contexto de prueba']) => {
  'context': context,
  'pivots': List<dynamic>.generate(
    10,
    (p) => <String, dynamic>{
      'name': 'Pivote ${p + 1}',
      'attractors': List<dynamic>.generate(20, (a) => 'Eje ${p + 1} ${20 - a}'),
    },
  ),
};
