import 'dart:math';

/// Fuente única de los pivotes y dimensiones de Quiz10.
typedef Quiz10Pivot = ({String code, String name});
typedef Quiz10Dimension = ({String code, String instruction});
typedef Quiz10Pair = ({int number, Quiz10Pivot pivot, Quiz10Dimension dimension});

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
  (code: 'P18', name: 'Música'),
  (code: 'P19', name: 'Psicología'),
  (code: 'P20', name: 'Química'),
  (code: 'P21', name: 'Sociología'),
];

const quiz10Dimensions = <Quiz10Dimension>[
  (code: 'D01', instruction: 'Pregunta por la entidad a la que corresponde una caracterización determinada.'),
  (code: 'D02', instruction: 'Pregunta por la característica que corresponde a una entidad determinada.'),
  (code: 'D03', instruction: 'Pregunta por una entidad a partir de su configuración respecto de otras.'),
  (code: 'D04', instruction: 'Pregunta por otra entidad que participa en una configuración conjunta.'),
  (code: 'D05', instruction: 'Pregunta por el hecho que ocupa una posición temporal determinada.'),
  (code: 'D06', instruction: 'Pregunta por el referente temporal respecto del cual se sitúa un hecho.'),
  (code: 'D07', instruction: 'Pregunta por la relación temporal entre un hecho y su referente temporal.'),
  (code: 'D08', instruction: 'Pregunta por el marco temporal en el que se sitúa un hecho.'),
  (code: 'D09', instruction: 'Pregunta por la entidad o estado cuya procedencia se establece.'),
  (code: 'D10', instruction: 'Pregunta por el antecedente del que procede una entidad o estado.'),
  (code: 'D11', instruction: 'Pregunta por aquello que sucede a partir de las condiciones de las que depende.'),
  (code: 'D12', instruction: 'Pregunta por aquello de lo que depende que suceda un hecho determinado.'),
  (code: 'D13', instruction: 'Pregunta por el elemento que desempeña una función determinada.'),
  (code: 'D14', instruction: 'Pregunta por aquello respecto de lo cual un elemento desempeña una función.'),
  (code: 'D15', instruction: 'Pregunta por la función que corresponde a un elemento respecto de otro.'),
  (code: 'D16', instruction: 'Pregunta por el contenido al que corresponde un alcance determinado.'),
  (code: 'D17', instruction: 'Pregunta por el ámbito hasta el que se extiende la validez o aplicación de un contenido.'),
  (code: 'D18', instruction: 'Pregunta por aquello que corresponde a una representación determinada.'),
  (code: 'D19', instruction: 'Pregunta por la entidad o contenido cuya procedencia se atribuye.'),
  (code: 'D20', instruction: 'Pregunta por la persona o entidad a la que se atribuye la procedencia de una entidad o contenido.'),
  (code: 'D21', instruction: 'Pregunta por aquello representado mediante una representación convencional.'),
  (code: 'D22', instruction: 'Pregunta por la representación convencional que corresponde a aquello representado.'),
  (code: 'D23', instruction: 'Pregunta por aquello sobre lo que se sostiene una concepción determinada.'),
  (code: 'D24', instruction: 'Pregunta por la concepción que se sostiene sobre un objeto determinado.'),
  (code: 'D25', instruction: 'Pregunta por la afirmación que se examina mediante determinados elementos de referencia.'),
  (code: 'D26', instruction: 'Pregunta por los elementos a los que se remite una afirmación para examinarla.'),
  (code: 'D27', instruction: 'Pregunta por aquello que recibe una respuesta determinada por parte de agentes externos.'),
  (code: 'D28', instruction: 'Pregunta por la respuesta que recibe algo por parte de agentes externos.'),
  (code: 'D29', instruction: 'Pregunta por la situación en la que tiene lugar una intervención.'),
  (code: 'D30', instruction: 'Pregunta por el elemento que interviene de determinada manera en una realidad externa.'),
  (code: 'D31', instruction: 'Pregunta por la realidad externa en la que interviene un elemento.'),
  (code: 'D32', instruction: 'Pregunta por aquello mediante lo cual un elemento interviene en una realidad externa.'),
  (code: 'D33', instruction: 'Pregunta por la intervención de la que depende un elemento o resultado externo.'),
  (code: 'D34', instruction: 'Pregunta por la intervención cuya posibilidad o pertinencia depende de determinadas condiciones.'),
];

/// Diez P y diez D seleccionados de forma independiente, sin repeticiones en cada partida.
List<Quiz10Pair> selectQuiz10Pairs(Random random) {
  final pivots = [...quiz10Pivots]..shuffle(random);
  final dimensions = [...quiz10Dimensions]..shuffle(random);
  return List.unmodifiable([
    for (var i = 0; i < 10; i++)
      (number: i + 1, pivot: pivots[i], dimension: dimensions[i]),
  ]);
}
