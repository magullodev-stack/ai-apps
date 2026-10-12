String semanticCatalogPrompt(String context) =>
    '''# PROMPT — Generador de Pivotes y Atractores

A partir del CONTEXTO proporcionado por el usuario, genera 10 PIVOTES locales de exploración.

Para cada PIVOTE genera 20 ATRACTORES ordenados por proximidad semántica relativa:

A01,...,A20.

Cada ATRACTOR debe constituir un eje distinto de exploración del PIVOTE y no puede contener nombres propios. Sus entidades, miembros, ejemplos, tipos y componentes quedan contenidos en ese eje y no ocupan posiciones Axx adicionales.

Los campos de atractores de los 10 pivotes deben ser distintos entre sí.

Devuelve exclusivamente el catálogo JSON según el esquema: context conserva literalmente el contexto recibido; pivots contiene los 10 pivotes con name y attractors, una lista de 20 nombres en el orden indicado. No incluyas códigos ni Markdown.

CONTEXTO [C]: $context''';

/// The service sets strict: true. Cardinalities are enforced locally, using
/// the same schema subset as the existing Muondia client/service integration.
Map<String, Object?> semanticCatalogSchema() => {
  'type': 'object',
  'additionalProperties': false,
  'required': ['context', 'pivots'],
  'properties': {
    'context': {'type': 'string'},
    'pivots': {
      'type': 'array',
      'items': {
        'type': 'object',
        'additionalProperties': false,
        'required': ['name', 'attractors'],
        'properties': {
          'name': {'type': 'string'},
          'attractors': {
            'type': 'array',
            'items': {'type': 'string'},
          },
        },
      },
    },
  },
};
