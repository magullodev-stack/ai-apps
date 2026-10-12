import 'dart:math';

import 'package:ai_apps_ai/ai_apps_ai.dart';

import 'onboarding_dimensions.dart';
import 'onboarding_prompt_g.dart';
import 'onboarding_prompt_r.dart';
import 'onboarding_prompt_s.dart';

typedef OnboardingQuizFinalQuestion = ({
  String pivot,
  String question,
  String correct,
  List<String> options,
});

class OnboardingQuizReviewedItem {
  const OnboardingQuizReviewedItem({
    required this.source,
    required this.question,
    required this.correct,
    required this.distractors,
  });

  final OnboardingQuizLunaRow source;
  final String question;
  final String correct;
  final List<String> distractors;
}

class OnboardingQuizPipelineResult {
  const OnboardingQuizPipelineResult({
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

  final List<OnboardingQuizPair> plan;
  final List<OnboardingQuizLunaRow> lunaRows;
  final AiGeneration lunaGeneration;
  final OnboardingQuizReviewResult review;
  final List<OnboardingQuizReviewedItem> correctedItems;
  final String sortInput;
  final OnboardingQuizSortResult sort;
  final List<OnboardingQuizReviewedItem> reviewedItems;
  final List<OnboardingQuizFinalQuestion> questions;
  final Duration lunaDuration;
  final Duration reviewDuration;
  final Duration sortDuration;
}

List<OnboardingQuizReviewedItem> applyOnboardingQuizReview(
  List<OnboardingQuizLunaRow> rows,
  OnboardingQuizReviewResult review,
) {
  if (rows.length != 10) {
    throw ArgumentError('OnboardingQuiz requiere diez filas.');
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

OnboardingQuizReviewedItem _applyReviewPatch(
  OnboardingQuizLunaRow row,
  OnboardingQuizReviewPatch? patch,
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

  return OnboardingQuizReviewedItem(
    source: row,
    question: question,
    correct: correct,
    distractors: List.unmodifiable(distractors),
  );
}

List<OnboardingQuizSortItem> buildOnboardingQuizSortItems(
  List<OnboardingQuizReviewedItem> items,
) => List.unmodifiable([
  for (final item in items)
    OnboardingQuizSortItem(
      question: item.question,
      correct: item.correct,
    ),
]);

List<OnboardingQuizReviewedItem> applyOnboardingQuizOrder(
  List<OnboardingQuizReviewedItem> items,
  List<int> order,
) {
  if (items.length != 10 ||
      order.length != 10 ||
      order.toSet().length != 10 ||
      order.any((value) => value < 1 || value > 10)) {
    throw ArgumentError('OnboardingQuiz requiere una permutación de 1 a 10.');
  }

  return List.unmodifiable([
    for (final number in order) items[number - 1],
  ]);
}

List<OnboardingQuizFinalQuestion> buildOnboardingQuizFinalQuestions(
  List<OnboardingQuizReviewedItem> reviewedItems, {
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

final class AiOnboardingQuizPipeline {
  AiOnboardingQuizPipeline({
    required AiAppsClient client,
    required String lunaModel,
    required String reviewerModel,
    String? sorterModel,
  }) : luna = AiOnboardingQuizLunaGenerator(
         client: client,
         model: lunaModel,
       ),
       reviewer = AiOnboardingQuizReviewer(
         client: client,
         model: reviewerModel,
       ),
       sorter = AiOnboardingQuizSorter(
         client: client,
         model: sorterModel ?? reviewerModel,
       );

  final AiOnboardingQuizLunaGenerator luna;
  final AiOnboardingQuizReviewer reviewer;
  final AiOnboardingQuizSorter sorter;

  final Map<OnboardingQuizHistoryKey, int> _usageByPair = {};

  Map<OnboardingQuizHistoryKey, int> get usageByPair =>
      Map.unmodifiable(_usageByPair);

  Future<List<OnboardingQuizFinalQuestion>> generate() async {
    final result = await generateDetailed();
    return result.questions;
  }

  Future<OnboardingQuizPipelineResult> generateDetailed({
    Random? planRandom,
    Random? optionRandom,
  }) async {
    final plan = selectOnboardingQuizPairs(
      planRandom ?? Random(),
      usageByPair: _usageByPair,
    );

    final lunaWatch = Stopwatch()..start();
    final lunaGeneration = await luna.generateResponse(
      plan,
      commitHistory: false,
    );
    lunaWatch.stop();
    final lunaRows = parseOnboardingQuizLunaOutput(lunaGeneration.text, plan);

    final reviewWatch = Stopwatch()..start();
    final review = await reviewer.review(lunaRows);
    reviewWatch.stop();

    final correctedItems = applyOnboardingQuizReview(lunaRows, review);

    final sortItems = buildOnboardingQuizSortItems(correctedItems);
    final sortInput = onboardingQuizSortInput(sortItems);
    final sortWatch = Stopwatch()..start();
    final sort = await sorter.sort(sortItems);
    sortWatch.stop();

    final reviewedItems = applyOnboardingQuizOrder(
      correctedItems,
      sort.order,
    );

    luna.commitReviewedQuestions(
      correctedItems.map((item) => item.source).toList(growable: false),
      correctedItems.map((item) => item.question).toList(growable: false),
      correctedItems.map((item) => item.correct).toList(growable: false),
    );

    final questions = buildOnboardingQuizFinalQuestions(
      reviewedItems,
      random: optionRandom,
    );

    for (final slot in plan) {
      final key = onboardingQuizHistoryKey(slot);
      _usageByPair.update(
        key,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    return OnboardingQuizPipelineResult(
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
