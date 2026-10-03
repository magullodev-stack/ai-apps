import 'dart:math';

import 'package:ai_apps_ai/ai_apps_ai.dart';

import 'quiz10_DART_Pi+Di.dart';
import 'quiz10_LUNA_Prompt.dart';
import 'quiz10_TERRA_Review.dart';

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
    required this.reviewInput,
    required this.review,
    required this.reviewedItems,
    required this.questions,
    required this.lunaDuration,
    required this.reviewDuration,
  });

  final List<Quiz10Pair> plan;
  final List<Quiz10LunaRow> lunaRows;
  final AiGeneration lunaGeneration;
  final String reviewInput;
  final Quiz10ReviewResult review;
  final List<Quiz10ReviewedItem> reviewedItems;
  final List<Quiz10FinalQuestion> questions;
  final Duration lunaDuration;
  final Duration reviewDuration;
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
  final byNumber = <int, Quiz10ReviewedItem>{};

  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    var question = row.question;
    var correct = row.correct;
    final distractors = [...row.distractors];

    final patch = patchesByNumber[i + 1];
    if (patch != null) {
      for (final change in patch.changes) {
        switch (change.field) {
          case 'Q':
            question = change.value;
          case 'R':
            correct = change.value;
          case 'a1':
            distractors[0] = change.value;
          case 'a2':
            distractors[1] = change.value;
          case 'a3':
            distractors[2] = change.value;
        }
      }
    }

    byNumber[i + 1] = Quiz10ReviewedItem(
      source: row,
      question: question,
      correct: correct,
      distractors: List.unmodifiable(distractors),
    );
  }

  return List.unmodifiable([
    for (final number in review.order) byNumber[number]!,
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
  }) : luna = AiQuiz10LunaGenerator(
         client: client,
         model: lunaModel,
       ),
       reviewer = AiQuiz10Reviewer(
         client: client,
         model: reviewerModel,
       );

  final AiQuiz10LunaGenerator luna;
  final AiQuiz10Reviewer reviewer;

  Future<List<Quiz10FinalQuestion>> generate() async {
    final result = await generateDetailed();
    return result.questions;
  }

  Future<Quiz10PipelineResult> generateDetailed({
    Random? planRandom,
    Random? optionRandom,
  }) async {
    final plan = selectQuiz10Pairs(planRandom ?? Random());

    final lunaWatch = Stopwatch()..start();
    final lunaGeneration = await luna.generateResponse(
      plan,
      commitHistory: false,
    );
    lunaWatch.stop();
    final lunaRows = parseQuiz10LunaOutput(lunaGeneration.text, plan);

    final reviewInput = quiz10ReviewInput(lunaRows);
    final reviewWatch = Stopwatch()..start();
    final review = await reviewer.review(lunaRows);
    reviewWatch.stop();

    final reviewedItems = applyQuiz10Review(lunaRows, review);

    luna.commitReviewedAnswers(
      reviewedItems.map((item) => item.source).toList(growable: false),
      reviewedItems.map((item) => item.correct).toList(growable: false),
    );

    final questions = buildQuiz10FinalQuestions(
      reviewedItems,
      random: optionRandom,
    );

    return Quiz10PipelineResult(
      plan: List.unmodifiable(plan),
      lunaRows: List.unmodifiable(lunaRows),
      lunaGeneration: lunaGeneration,
      reviewInput: reviewInput,
      review: review,
      reviewedItems: reviewedItems,
      questions: questions,
      lunaDuration: lunaWatch.elapsed,
      reviewDuration: reviewWatch.elapsed,
    );
  }
}
