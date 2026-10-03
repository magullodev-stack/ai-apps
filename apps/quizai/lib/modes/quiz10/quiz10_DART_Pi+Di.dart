import 'dart:math';

/// Fuente única de los pivotes y dimensiones de Quiz10.
typedef Quiz10Pivot = ({String code, String name});
typedef Quiz10Dimension = ({
  String code,
  String relation,
  String projection,
  String expectedType,
  String constraints,
});
typedef Quiz10Pair = ({
  int number,
  Quiz10Pivot pivot,
  Quiz10Dimension dimension,
  String difficulty,
});

typedef Quiz10HistoryKey = ({
  String pivotCode,
  String dimensionCode,
});

Quiz10HistoryKey quiz10HistoryKey(Quiz10Pair slot) => (
  pivotCode: slot.pivot.code,
  dimensionCode: slot.dimension.code,
);

const quiz10Pivots = <Quiz10Pivot>[
  (code: 'P01', name: 'Arquitectura'),
  (code: 'P02', name: 'Arte'),
  (code: 'P03', name: 'Astronomía'),
  (code: 'P04', name: 'Biología'),
  (code: 'P05', name: 'Derecho'),
  (code: 'P06', name: 'Economía'),
  (code: 'P07', name: 'Filosofía'),
  (code: 'P08', name: 'Física'),
  (code: 'P09', name: 'Gastronomía'),
  (code: 'P10', name: 'Geografía'),
  (code: 'P11', name: 'Geología'),
  (code: 'P12', name: 'Historia'),
  (code: 'P13', name: 'Informática'),
  (code: 'P14', name: 'Lingüística'),
  (code: 'P15', name: 'Literatura'),
  (code: 'P16', name: 'Matemáticas'),
  (code: 'P17', name: 'Medicina'),
  (code: 'P18', name: 'Psicología'),
  (code: 'P19', name: 'Química'),
  (code: 'P20', name: 'Sociología'),
];

const quiz10Dimensions = <Quiz10Dimension>[
  (
    code: 'D01',
    relation: 'ρ_P(x,p): x posee propiedad descriptiva/constitutiva p',
    projection: 'π_x',
    expectedType: 'entidad',
    constraints: 'Excluye identificación por función, procedencia o relación especializada',
  ),
  (
    code: 'D02',
    relation: 'ρ_P(x,p): x posee propiedad descriptiva/constitutiva p',
    projection: 'π_p',
    expectedType: 'propiedad/estado',
    constraints: 'Excluye función, procedencia y transformación',
  ),
  (
    code: 'D03',
    relation: 'ρ_E(x,r,c): x ocupa relación/posición estructural r en configuración c',
    projection: 'π_x',
    expectedType: 'entidad',
    constraints: 'Excluye coparticipación en actividad o acontecimiento',
  ),
  (
    code: 'D04',
    relation: 'ρ_A(x,y,e): x e y participan conjuntamente en actividad/acontecimiento e',
    projection: 'π_y',
    expectedType: 'participante',
    constraints: 'x u otros participantes son conocidos; excluye autoría',
  ),
  (
    code: 'D05',
    relation: 'ρ_T(e_1,r,e_2): acontecimiento e_1 mantiene relación temporal r con e_2',
    projection: 'π_e',
    expectedType: 'acontecimiento',
    constraints: 'La incógnita es uno de los acontecimientos, no la relación temporal',
  ),
  (
    code: 'D06',
    relation: 'ρ_T(e_1,r,e_2): acontecimiento e_1 mantiene relación temporal r con e_2',
    projection: 'π_r',
    expectedType: 'orden/distancia temporal',
    constraints: 'Interroga anterioridad, posterioridad, simultaneidad, separación, etc.',
  ),
  (
    code: 'D07',
    relation: 'ρ_C(e,t): hecho e ocurre/se sitúa temporalmente en t',
    projection: 'π_t',
    expectedType: 'fecha/intervalo/período',
    constraints: 'Excluye mera relación temporal relativa y vigencia normativa',
  ),
  (
    code: 'D08',
    relation: 'ρ_D(o,d): d procede/se deriva/se transforma desde o',
    projection: 'π_d',
    expectedType: 'entidad/estado derivado',
    constraints: 'Excluye atribución de autoría',
  ),
  (
    code: 'D09',
    relation: 'ρ_D(o,d): d procede/se deriva/se transforma desde o',
    projection: 'π_o',
    expectedType: 'antecedente/origen',
    constraints: 'Excluye atribución de autoría',
  ),
  (
    code: 'D10',
    relation: 'ρ_K(c,e): condiciones causales c producen hecho/efecto e',
    projection: 'π_e',
    expectedType: 'hecho/efecto',
    constraints: 'Excluye respuesta reactiva e intervención intencional',
  ),
  (
    code: 'D11',
    relation: 'ρ_K(c,e): condiciones causales c producen hecho/efecto e',
    projection: 'π_c',
    expectedType: 'causa/condición causal',
    constraints: 'Excluye intervención intencional y estímulo-respuesta',
  ),
  (
    code: 'D12',
    relation: 'ρ_F(c,f,o,s): componente c desempeña función f respecto de o en sistema s',
    projection: 'π_c',
    expectedType: 'componente',
    constraints: 'La función debe ser relativamente estable',
  ),
  (
    code: 'D13',
    relation: 'ρ_F(c,f,o,s): componente c desempeña función f respecto de o en sistema s',
    projection: 'π_o',
    expectedType: 'elemento/proceso funcionalmente relacionado',
    constraints: 'Excluye objeto de intervención puntual',
  ),
  (
    code: 'D14',
    relation: 'ρ_F(c,f,o,s): componente c desempeña función f respecto de o en sistema s',
    projection: 'π_f',
    expectedType: 'función',
    constraints: 'Excluye respuesta particular ante estímulo',
  ),
  (
    code: 'D15',
    relation: 'ρ_V(n,a): proposición/norma/regla n es válida o aplicable en ámbito a',
    projection: 'π_n',
    expectedType: 'proposición/norma/regla',
    constraints: 'Debe existir ámbito de validez/aplicación determinado',
  ),
  (
    code: 'D16',
    relation: 'ρ_V(n,a): proposición/norma/regla n es válida o aplicable en ámbito a',
    projection: 'π_a',
    expectedType: 'ámbito',
    constraints: 'Puede ser material, personal, territorial, temporal, etc.',
  ),
  (
    code: 'D17',
    relation: 'ρ_R(s,r,k): representación s representa referente/contenido r mediante sistema k',
    projection: 'π_r',
    expectedType: 'referente/contenido',
    constraints: 'Admite representación figurativa o convencional',
  ),
  (
    code: 'D18',
    relation: 'ρ_U(a,o): agente a es autor/creador de obra, invención o contenido o',
    projection: 'π_o',
    expectedType: 'obra/invención/contenido',
    constraints: 'Relación de autoría o creación atribuida',
  ),
  (
    code: 'D19',
    relation: 'ρ_U(a,o): agente a es autor/creador de obra, invención o contenido o',
    projection: 'π_a',
    expectedType: 'agente',
    constraints: 'Relación de autoría o creación atribuida',
  ),
  (
    code: 'D20',
    relation: 'ρ_R(s,r,k): representación convencional s representa referente/significado r en sistema k',
    projection: 'π_s',
    expectedType: 'signo/símbolo/código',
    constraints: 'Solo representación convencional',
  ),
  (
    code: 'D21',
    relation: 'ρ_Q(a,o,c): agente a sostiene concepción documentada c acerca de o',
    projection: 'π_o',
    expectedType: 'objeto/fenómeno',
    constraints: 'La concepción debe ser determinada y documentada',
  ),
  (
    code: 'D22',
    relation: 'ρ_Q(a,o,c): agente a sostiene concepción documentada c acerca de o',
    projection: 'π_c',
    expectedType: 'contenido conceptual/proposicional',
    constraints: 'Deben conocerse agente y objeto/fenómeno',
  ),
  (
    code: 'D23',
    relation: 'ρ_X(p,m,e): afirmación p es contrastada mediante procedimiento m usando referencias/evidencias e',
    projection: 'π_p',
    expectedType: 'afirmación/proposición',
    constraints: 'Debe existir procedimiento de contraste identificable',
  ),
  (
    code: 'D24',
    relation: 'ρ_X(p,m,e): afirmación p es contrastada mediante procedimiento m usando referencias/evidencias e',
    projection: 'π_e',
    expectedType: 'dato/evidencia/criterio',
    constraints: 'Debe estar ligado al contraste de p mediante m',
  ),
  (
    code: 'D25',
    relation: 'ρ_S(s,e,r): sistema/agente s produce respuesta r ante estímulo/contenido e',
    projection: 'π_e',
    expectedType: 'estímulo/conducta/solicitud/contenido',
    constraints: 'Interroga aquello ante lo que se responde',
  ),
  (
    code: 'D26',
    relation: 'ρ_S(s,e,r): sistema/agente s produce respuesta r ante estímulo/contenido e',
    projection: 'π_r',
    expectedType: 'respuesta',
    constraints: 'Admite estímulo deliberadamente aplicado',
  ),
  (
    code: 'D27',
    relation: 'ρ_I(i,a,o,m,c): intervención i es ejecutada/controlada por a, sobre o, mediante m, en contexto c',
    projection: 'π_c',
    expectedType: 'circunstancia/contexto',
    constraints: 'Excluye objeto, resultado y requisitos de ejecución',
  ),
  (
    code: 'D28',
    relation: 'ρ_I(i,a,o,m,c): intervención i es ejecutada/controlada por a, sobre o, mediante m, en contexto c',
    projection: 'π_a',
    expectedType: 'agente/sistema ejecutor',
    constraints: 'Debe ejercer control operativo de la ejecución',
  ),
  (
    code: 'D29',
    relation: 'ρ_I(i,a,o,m,c): intervención i es ejecutada/controlada por a, sobre o, mediante m, en contexto c',
    projection: 'π_o',
    expectedType: 'objeto de intervención',
    constraints: 'Realidad externa preexistente destinada a modificación',
  ),
  (
    code: 'D30',
    relation: 'ρ_I(i,a,o,m,c): intervención i es ejecutada/controlada por a, sobre o, mediante m, en contexto c',
    projection: 'π_m',
    expectedType: 'instrumento/medio',
    constraints: 'Excluye estímulo o contenido recibido por el sistema',
  ),
  (
    code: 'D31',
    relation: 'ρ_M(i,o,Δ): intervención efectivamente realizada i produce modificación Δ sobre o',
    projection: 'π_i',
    expectedType: 'intervención realizada',
    constraints: 'Debe existir modificación factual resultante',
  ),
  (
    code: 'D32',
    relation: 'ρ_Pos(i,c): condiciones operativas c hacen material/técnicamente posible intervención i',
    projection: 'π_i',
    expectedType: 'intervención posible',
    constraints: 'Interroga posibilidad técnica/material, no indicación',
  ),
  (
    code: 'D33',
    relation: 'ρ_Ind(i,k,f): criterios k, dentro de marco f, establecen indicación de intervención i',
    projection: 'π_i',
    expectedType: 'intervención indicada',
    constraints: 'Debe existir criterio explícito de indicación',
  ),
  (
    code: 'D34',
    relation: 'ρ_M(i,o,Δ): intervención efectivamente realizada i produce modificación Δ sobre o',
    projection: 'π_Δ',
    expectedType: 'modificación/resultado directo',
    constraints: 'Excluye respuesta reactiva del objeto o sistema receptor',
  ),
];

/// Diez P distintos y diez D distintas por Quiz10.
/// La posición fija la dificultad: 4 fáciles, 3 moderadas, 2 difíciles y 1 extrema.
List<Quiz10Pair> selectQuiz10Pairs(Random random) {
  final pivots = [...quiz10Pivots]..shuffle(random);
  final dimensions = [...quiz10Dimensions]..shuffle(random);
  const difficulties = <String>[
    'Fácil',
    'Fácil',
    'Fácil',
    'Fácil',
    'Moderada',
    'Moderada',
    'Moderada',
    'Difícil',
    'Difícil',
    'Extrema',
  ];

  return List.unmodifiable([
    for (var i = 0; i < 10; i++)
      (
        number: i + 1,
        pivot: pivots[i],
        dimension: dimensions[i],
        difficulty: difficulties[i],
      ),
  ]);
}
