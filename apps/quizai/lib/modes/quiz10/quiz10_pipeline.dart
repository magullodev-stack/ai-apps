import 'dart:math';

import 'package:ai_apps_ai/ai_apps_ai.dart';

import 'quiz10_DART_Pi+Di.dart';
import 'Quiz10_PROMPT_G.dart';
import 'Quiz10_PROMPT_R.dart';
import 'Quiz10_PROMPT_S.dart';

typedef Quiz10FinalQuestion = ({
  String pivot,
  String question,
  String correct,
  List<String> options,
});

class Quiz10ReviewedItem {
  const Quiz10ReviewedItem({
    required this.source,
    required this.question,
    required this.correct,
    required this.distractors,
  });

  final Quiz10LunaRow source;
  final String question;
  final String correct;
  final List<String> distractors;
}

class Quiz10PipelineResult {
  const Quiz10PipelineResult({
    required this.plan,
    required this.lunaRows,
    required this.lunaGeneration,
    required this.review,
    required this.correctedItems,
    required this.sortInput,
    required this.sort,
    required this.reviewedItems,
    required this.questions,
    required this.lunaDuration,
    required this.reviewDuration,
    required this.sortDuration,
  });

  final List<Quiz10Pair> plan;
  final List<Quiz10LunaRow> lunaRows;
  final AiGeneration lunaGeneration;
  final Quiz10ReviewResult review;
  final List<Quiz10ReviewedItem> correctedItems;
  final String sortInput;
  final Quiz10SortResult sort;
  final List<Quiz10ReviewedItem> reviewedItems;
  final List<Quiz10FinalQuestion> questions;
  final Duration lunaDuration;
  final Duration reviewDuration;
  final Duration sortDuration;
}

List<Quiz10ReviewedItem> applyQuiz10Review(
  List<Quiz10LunaRow> rows,
  Quiz10ReviewResult review,
) {
  if (rows.length != 10) {
    throw ArgumentError('Quiz10 requiere diez filas.');
  }

  final patchesByNumber = {
    for (final patch in review.patches) patch.number: patch,
  };

  return List.unmodifiable([
    for (var i = 0; i < rows.length; i++)
      _applyReviewPatch(
        rows[i],
        patchesByNumber[i + 1],
      ),
  ]);
}

Quiz10ReviewedItem _applyReviewPatch(
  Quiz10LunaRow row,
  Quiz10ReviewPatch? patch,
) {
  var question = row.question;
  var correct = row.correct;
  final distractors = [...row.distractors];

  if (patch != null) {
    for (final change in patch.changes) {
      switch (change.field) {
        case 'Q':
          question = change.value;
          break;
        case 'R':
          correct = change.value;
          break;
        case 'd1':
          distractors[0] = change.value;
          break;
        case 'd2':
          distractors[1] = change.value;
          break;
        case 'd3':
          distractors[2] = change.value;
          break;
      }
    }
  }

  return Quiz10ReviewedItem(
    source: row,
    question: question,
    correct: correct,
    distractors: List.unmodifiable(distractors),
  );
}

List<Quiz10SortItem> buildQuiz10SortItems(
  List<Quiz10ReviewedItem> items,
) => List.unmodifiable([
  for (final item in items)
    Quiz10SortItem(
      question: item.question,
      correct: item.correct,
    ),
]);

List<Quiz10ReviewedItem> applyQuiz10Order(
  List<Quiz10ReviewedItem> items,
  List<int> order,
) {
  if (items.length != 10 ||
      order.length != 10 ||
      order.toSet().length != 10 ||
      order.any((value) => value < 1 || value > 10)) {
    throw ArgumentError('Quiz10 requiere una permutación de 1 a 10.');
  }

  return List.unmodifiable([
    for (final number in order) items[number - 1],
  ]);
}

List<Quiz10FinalQuestion> buildQuiz10FinalQuestions(
  List<Quiz10ReviewedItem> reviewedItems, {
  Random? random,
}) {
  final rng = random ?? Random();
  return List.unmodifiable([
    for (final item in reviewedItems)
      (
        pivot: item.source.slot.pivot.name,
        question: item.question,
        correct: item.correct,
        options: List<String>.unmodifiable(
          [item.correct, ...item.distractors]..shuffle(rng),
        ),
      ),
  ]);
}

final class AiQuiz10Pipeline {
  AiQuiz10Pipeline({
    required AiAppsClient client,
    required String lunaModel,
    required String reviewerModel,
    String? sorterModel,
  }) : luna = AiQuiz10LunaGenerator(
         client: client,
         model: lunaModel,
       ),
       reviewer = AiQuiz10Reviewer(
         client: client,
         model: reviewerModel,
       ),
       sorter = AiQuiz10Sorter(
         client: client,
         model: sorterModel ?? reviewerModel,
       );

  final AiQuiz10LunaGenerator luna;
  final AiQuiz10Reviewer reviewer;
  final AiQuiz10Sorter sorter;

  final Map<Quiz10HistoryKey, int> _usageByPair = {};

  Map<Quiz10HistoryKey, int> get usageByPair =>
      Map.unmodifiable(_usageByPair);

  Future<List<Quiz10FinalQuestion>> generate() async {
    final result = await generateDetailed();
    return result.questions;
  }

  Future<Quiz10PipelineResult> generateDetailed({
    Random? planRandom,
    Random? optionRandom,
  }) async {
    final plan = selectQuiz10Pairs(
      planRandom ?? Random(),
      usageByPair: _usageByPair,
    );

    final lunaWatch = Stopwatch()..start();
    final lunaGeneration = await luna.generateResponse(
      plan,
      commitHistory: false,
    );
    lunaWatch.stop();
    final lunaRows = parseQuiz10LunaOutput(lunaGeneration.text, plan);

    final reviewWatch = Stopwatch()..start();
    final review = await reviewer.review(lunaRows);
    reviewWatch.stop();

    final correctedItems = applyQuiz10Review(lunaRows, review);

    final sortItems = buildQuiz10SortItems(correctedItems);
    final sortInput = quiz10SortInput(sortItems);
    final sortWatch = Stopwatch()..start();
    final sort = await sorter.sort(sortItems);
    sortWatch.stop();

    final reviewedItems = applyQuiz10Order(
      correctedItems,
      sort.order,
    );

    luna.commitReviewedQuestions(
      correctedItems.map((item) => item.source).toList(growable: false),
      correctedItems.map((item) => item.question).toList(growable: false),
      correctedItems.map((item) => item.correct).toList(growable: false),
    );

    final questions = buildQuiz10FinalQuestions(
      reviewedItems,
      random: optionRandom,
    );

    for (final slot in plan) {
      final key = quiz10HistoryKey(slot);
      _usageByPair.update(
        key,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    return Quiz10PipelineResult(
      plan: List.unmodifiable(plan),
      lunaRows: List.unmodifiable(lunaRows),
      lunaGeneration: lunaGeneration,
      review: review,
      correctedItems: correctedItems,
      sortInput: sortInput,
      sort: sort,
      reviewedItems: reviewedItems,
      questions: questions,
      lunaDuration: lunaWatch.elapsed,
      reviewDuration: reviewWatch.elapsed,
      sortDuration: sortWatch.elapsed,
    );
  }
}
