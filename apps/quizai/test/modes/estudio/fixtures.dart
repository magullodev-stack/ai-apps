import 'dart:convert';

import 'package:quizai/modes/estudio/estudio_generation.dart';

Map<String, dynamic> estudioJson() => {
  'preguntas': List<dynamic>.generate(
    10,
    (i) => <String, dynamic>{
      'fila': i + 1,
      'hecho': 'Hecho interno ${i + 1}',
      'pregunta': '¿Cuál es la respuesta de la pregunta ${i + 1}?',
      'correcta': 'Correcta ${i + 1}',
      'distractor1': 'Alternativa A ${i + 1}',
      'distractor2': 'Alternativa B ${i + 1}',
      'distractor3': 'Alternativa C ${i + 1}',
    },
  ),
};

List<EstudioQuestion> estudioQuestions() =>
    validateEstudioQuestions(jsonEncode(estudioJson()));
