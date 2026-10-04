import 'dart:math';

/// Fuente única de los pivotes y dimensiones de Quiz10.
typedef Quiz10Pivot = ({String code, String name});
typedef Quiz10Dimension = ({
  String code,
  String instruction,
});
typedef Quiz10Pair = ({
  int number,
  Quiz10Pivot pivot,
  Quiz10Dimension dimension,
});

typedef Quiz10HistoryKey = ({
  String pivotCode,
  String dimensionCode,
});

typedef Quiz10HistoryEntry = ({
  String fact,
  String answer,
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
    instruction: 'Pregunta qué posee una característica descriptiva o constitutiva determinada.',
  ),
  (
    code: 'D02',
    instruction: 'Pregunta qué característica descriptiva o constitutiva posee algo.',
  ),
  (
    code: 'D03',
    instruction: 'Pregunta cómo se llama o qué término designa un objeto, fenómeno, concepto, proceso o relación.',
  ),
  (
    code: 'D04',
    instruction: 'Pregunta a qué clase, categoría, grupo o conjunto pertenece algo.',
  ),
  (
    code: 'D05',
    instruction: 'Pregunta qué cantidad, número o medida corresponde a algo.',
  ),
  (
    code: 'D06',
    instruction: 'Pregunta qué elemento ocupa un extremo o posición destacada dentro de una comparación o clasificación bien definida.',
  ),
  (
    code: 'D07',
    instruction: 'Pregunta qué ocupa una posición o relación estructural dentro de una configuración.',
  ),
  (
    code: 'D08',
    instruction: 'Pregunta qué cargo, función, título, condición o identidad corresponde a una persona o entidad.',
  ),
  (
    code: 'D09',
    instruction: 'Pregunta quién o qué participó junto con alguien o algo en una actividad o acontecimiento.',
  ),
  (
    code: 'D10',
    instruction: 'Pregunta dónde se encuentra, ocurre, nace, se desarrolla o tiene lugar algo.',
  ),
  (
    code: 'D11',
    instruction: 'Pregunta qué entidad, hecho o acontecimiento corresponde a un lugar determinado.',
  ),
  (
    code: 'D12',
    instruction: 'Pregunta cuándo ocurrió un hecho.',
  ),
  (
    code: 'D13',
    instruction: 'Pregunta qué hecho o acontecimiento corresponde a una fecha o periodo determinado.',
  ),
  (
    code: 'D14',
    instruction: 'Pregunta cuál de varios acontecimientos ocurrió primero o cuál ocurrió más recientemente.',
  ),
  (
    code: 'D15',
    instruction: 'Pregunta qué acontecimiento, etapa o entidad precedió o sucedió inmediatamente a otro dentro de una secuencia temporal establecida.',
  ),
  (
    code: 'D16',
    instruction: 'Pregunta qué surge, procede o se obtiene a partir de algo.',
  ),
  (
    code: 'D17',
    instruction: 'Pregunta de qué surge, procede o se obtiene algo.',
  ),
  (
    code: 'D18',
    instruction: 'Pregunta qué hecho o efecto ocurre como consecuencia de unas causas o condiciones.',
  ),
  (
    code: 'D19',
    instruction: 'Pregunta qué causa o condición produce un hecho o efecto.',
  ),
  (
    code: 'D20',
    instruction: 'Pregunta qué componente cumple una función concreta dentro de un sistema.',
  ),
  (
    code: 'D21',
    instruction: 'Pregunta qué función desempeña un componente dentro de un sistema.',
  ),
  (
    code: 'D22',
    instruction: 'Pregunta qué proposición, norma o regla es válida o aplicable en un ámbito concreto.',
  ),
  (
    code: 'D23',
    instruction: 'Pregunta en qué ámbito es válida o aplicable una proposición, norma o regla.',
  ),
  (
    code: 'D24',
    instruction: 'Pregunta qué contenido o referente expresa una representación.',
  ),
  (
    code: 'D25',
    instruction: 'Pregunta qué signo, símbolo o código representa convencionalmente un significado o referente.',
  ),
  (
    code: 'D26',
    instruction: 'Pregunta qué obra, invención o contenido creó alguien.',
  ),
  (
    code: 'D27',
    instruction: 'Pregunta quién creó una obra, invención o contenido.',
  ),
  (
    code: 'D28',
    instruction: 'Pregunta sobre qué objeto o fenómeno trata una concepción documentada sostenida por alguien.',
  ),
  (
    code: 'D29',
    instruction: 'Pregunta qué concepción documentada sostiene alguien sobre un objeto o fenómeno.',
  ),
  (
    code: 'D30',
    instruction: 'Pregunta qué afirmación se contrasta mediante un procedimiento y unas evidencias concretas.',
  ),
  (
    code: 'D31',
    instruction: 'Pregunta qué dato, evidencia o criterio se usa para contrastar una afirmación mediante un procedimiento.',
  ),
  (
    code: 'D32',
    instruction: 'Pregunta ante qué estímulo, conducta, solicitud o contenido responde un sistema o una persona de una forma determinada.',
  ),
  (
    code: 'D33',
    instruction: 'Pregunta cómo responde un sistema o una persona ante un estímulo, conducta, solicitud o contenido.',
  ),
  (
    code: 'D34',
    instruction: 'Pregunta con qué instrumento o medio se ejecuta una intervención.',
  ),
];

/// Diez P distintos y diez D distintas por Quiz10.
List<Quiz10Pair> selectQuiz10Pairs(Random random) {
  final pivots = [...quiz10Pivots]..shuffle(random);
  final dimensions = [...quiz10Dimensions]..shuffle(random);

  return List.unmodifiable([
    for (var i = 0; i < 10; i++)
      (
        number: i + 1,
        pivot: pivots[i],
        dimension: dimensions[i],
      ),
  ]);
}
