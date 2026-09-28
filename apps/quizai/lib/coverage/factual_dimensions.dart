enum FactualDimensionGroup { intra, meta, extra }

final class FactualDimension {
  const FactualDimension(this.code, this.name, this.definition, this.group);

  final String code;
  final String name;
  final String definition;
  final FactualDimensionGroup group;
}

const factualDimensions = <FactualDimension>[
  FactualDimension(
    'I01',
    'Caracterización',
    'Establece cómo queda caracterizada una entidad.',
    FactualDimensionGroup.intra,
  ),
  FactualDimension(
    'I02',
    'Configuración relativa',
    'Establece la configuración relativa de entidades consideradas conjuntamente.',
    FactualDimensionGroup.intra,
  ),
  FactualDimension(
    'I03',
    'Temporalidad',
    'Establece cómo se sitúa un hecho respecto del tiempo.',
    FactualDimensionGroup.intra,
  ),
  FactualDimension(
    'I04',
    'Procedencia interna',
    'Establece cómo una entidad o estado procede de un antecedente.',
    FactualDimensionGroup.intra,
  ),
  FactualDimension(
    'I05',
    'Condicionamiento interno',
    'Establece de qué depende lo que sucede.',
    FactualDimensionGroup.intra,
  ),
  FactualDimension(
    'I06',
    'Función interna',
    'Establece qué papel corresponde a un elemento.',
    FactualDimensionGroup.intra,
  ),
  FactualDimension(
    'I07',
    'Alcance interno',
    'Establece hasta dónde se extiende la validez o aplicación de un contenido.',
    FactualDimensionGroup.intra,
  ),
  FactualDimension(
    'I08',
    'Representación interna',
    'Establece la correspondencia entre una representación y aquello que representa.',
    FactualDimensionGroup.intra,
  ),
  FactualDimension(
    'I09',
    'Consecuencia formal',
    'Establece qué se sigue formalmente de lo admitido.',
    FactualDimensionGroup.intra,
  ),
  FactualDimension(
    'M01',
    'Procedencia externa',
    'Establece a quién o a qué se atribuye la procedencia de una entidad o contenido.',
    FactualDimensionGroup.meta,
  ),
  FactualDimension(
    'M02',
    'Representación externa',
    'Establece la correspondencia entre lo representado y su representación convencional.',
    FactualDimensionGroup.meta,
  ),
  FactualDimension(
    'M03',
    'Concepción externa',
    'Establece qué concepción se sostiene sobre algo desde una perspectiva externa.',
    FactualDimensionGroup.meta,
  ),
  FactualDimension(
    'M04',
    'Referencia externa',
    'Establece a qué elementos se remite una afirmación para examinarla.',
    FactualDimensionGroup.meta,
  ),
  FactualDimension(
    'M05',
    'Recepción externa',
    'Establece la respuesta que recibe algo por parte de agentes externos.',
    FactualDimensionGroup.meta,
  ),
  FactualDimension(
    'E01',
    'Contexto de intervención',
    'Establece en qué situación tiene lugar una intervención.',
    FactualDimensionGroup.extra,
  ),
  FactualDimension(
    'E02',
    'Participación externa',
    'Establece cómo interviene un elemento en una realidad externa.',
    FactualDimensionGroup.extra,
  ),
  FactualDimension(
    'E03',
    'Dependencia externa',
    'Establece qué depende de una intervención.',
    FactualDimensionGroup.extra,
  ),
  FactualDimension(
    'E04',
    'Condiciones de intervención',
    'Establece de qué depende que una intervención sea posible o pertinente.',
    FactualDimensionGroup.extra,
  ),
];
