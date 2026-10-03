import 'dart:math';

/// Fuente única de los pivotes y dimensiones de Quiz10.
typedef Quiz10Pivot = ({String code, String name});
typedef Quiz10Dimension = ({String code, String instruction});
typedef Quiz10Pair = ({
  int number,
  Quiz10Pivot pivot,
  Quiz10Dimension dimension,
  String difficulty,
});

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
  (code: 'D01', instruction: 'Pregunta por una entidad identificable mediante propiedades descriptivas o constitutivas propias, distintas de funciones, procedencias y relaciones especializadas.'),
  (code: 'D02', instruction: 'Pregunta por una propiedad descriptiva o constitutiva de una entidad determinada, distinta de su función, procedencia o transformación.'),
  (code: 'D03', instruction: 'Pregunta por una entidad identificable mediante su posición o relaciones estructurales dentro de una configuración determinada, sin interrogar su participación en una actividad conjunta.'),
  (code: 'D04', instruction: 'Pregunta por otro participante de una actividad o acontecimiento conjunto, dada la identidad de uno o varios participantes, sin interrogar la atribución de autoría.'),
  (code: 'D05', instruction: 'Pregunta por un acontecimiento identificable mediante relaciones cronológicas determinadas, incluida su función como referente temporal de otros acontecimientos.'),
  (code: 'D06', instruction: 'Pregunta por la relación de orden o distancia temporal entre un hecho y su referente temporal.'),
  (code: 'D07', instruction: 'Pregunta por la fecha, intervalo o período en el que ocurre un hecho determinado, sin interrogar el período de validez de una norma.'),
  (code: 'D08', instruction: 'Pregunta por la entidad o estado que procede de un antecedente mediante una relación de origen, derivación o transformación, distinta de la atribución de autoría.'),
  (code: 'D09', instruction: 'Pregunta por el antecedente material, genealógico o de estado del que procede una entidad o estado mediante una relación de origen, derivación o transformación.'),
  (code: 'D10', instruction: 'Pregunta por el hecho o efecto producido bajo determinadas condiciones causales, excluidas las respuestas reactivas de sistemas receptores y las modificaciones producidas por intervenciones intencionales.'),
  (code: 'D11', instruction: 'Pregunta por las condiciones causales de un hecho o efecto, distintas de intervenciones intencionales y de estímulos interrogados como desencadenantes de respuestas.'),
  (code: 'D12', instruction: 'Pregunta por el componente identificado mediante la función relativamente estable que desempeña dentro de un sistema.'),
  (code: 'D13', instruction: 'Pregunta por el elemento o proceso respecto del cual un componente desempeña una función operativa estable dentro de un sistema.'),
  (code: 'D14', instruction: 'Pregunta por la función relativamente estable de un componente dentro de un sistema, sin interrogar una activación particular ante un estímulo.'),
  (code: 'D15', instruction: 'Pregunta por la proposición, norma o regla cuya validez o aplicación se extiende a un ámbito determinado.'),
  (code: 'D16', instruction: 'Pregunta por el ámbito material, personal, territorial, temporal o de otro tipo al que se extiende la validez o aplicación de una proposición, norma o regla determinada.'),
  (code: 'D17', instruction: 'Pregunta por el referente o contenido representado mediante una representación determinada, sea figurativa o convencional.'),
  (code: 'D18', instruction: 'Pregunta por la obra, invención o contenido cuya autoría o creación se atribuye a un agente determinado.'),
  (code: 'D19', instruction: 'Pregunta por el agente al que se atribuye la autoría o creación de una obra, invención o contenido determinado.'),
  (code: 'D20', instruction: 'Pregunta por la representación convencional que corresponde a un referente o significado dentro de un sistema determinado de signos.'),
  (code: 'D21', instruction: 'Pregunta por el objeto o fenómeno al que se refiere una concepción determinada y documentada.'),
  (code: 'D22', instruction: 'Pregunta por el contenido de una concepción documentada que un agente sostiene acerca de un objeto o fenómeno determinado.'),
  (code: 'D23', instruction: 'Pregunta por la afirmación examinada mediante un procedimiento de contraste identificable y determinados elementos de referencia.'),
  (code: 'D24', instruction: 'Pregunta por los datos, evidencias o criterios empleados para contrastar una afirmación determinada mediante un procedimiento identificable.'),
  (code: 'D25', instruction: 'Pregunta por el estímulo, conducta, solicitud o contenido ante el cual un agente o sistema receptor produce una respuesta determinada.'),
  (code: 'D26', instruction: 'Pregunta por la respuesta propia de un agente o sistema receptor ante un estímulo, conducta, solicitud o contenido externo determinado, incluso cuando el estímulo se aplica deliberadamente.'),
  (code: 'D27', instruction: 'Pregunta por las circunstancias contextuales en las que se desarrolla una intervención determinada, distintas de su objeto, resultado y requisitos de ejecución.'),
  (code: 'D28', instruction: 'Pregunta por el agente o sistema que controla operativamente la ejecución de una intervención concreta.'),
  (code: 'D29', instruction: 'Pregunta por la realidad externa preexistente sobre la que recae una intervención concreta destinada a modificar su estado.'),
  (code: 'D30', instruction: 'Pregunta por el instrumento o medio empleado para materializar una intervención bajo el control de un ejecutor, diferenciándolo del estímulo o contenido que recibe el sistema intervenido.'),
  (code: 'D31', instruction: 'Pregunta por la intervención efectivamente realizada que produjo una modificación determinada en una realidad externa.'),
  (code: 'D32', instruction: 'Pregunta por la intervención cuya posibilidad material o técnica de ejecución se establece a partir de condiciones operativas determinadas.'),
  (code: 'D33', instruction: 'Pregunta por la intervención cuya indicación se establece conforme a criterios explícitos dentro de un marco determinado.'),
  (code: 'D34', instruction: 'Pregunta por la modificación producida directamente sobre el objeto de una intervención efectivamente realizada, sin interrogar una respuesta reactiva del sistema receptor.'),
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
