package dev.magullodev.quiz10.systems.quiz10.preparation

import dev.magullodev.aiapps.core.contracts.Outcome
import dev.magullodev.quiz10.systems.quiz10.coverage.CoverageDifficulty
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

class QuizPreparerTest {
    private fun plan() = QuizContentPlan.of(List(10) { index ->
        QuizContentPlanItem(
            difficulty = when (index) {
                in 0..3 -> CoverageDifficulty.EASY
                in 4..6 -> CoverageDifficulty.MODERATE
                in 7..8 -> CoverageDifficulty.HARD
                else -> CoverageDifficulty.VERY_HARD
            },
            area = if (index % 2 == 0) "History" else "Culture",
            group = if (index % 3 == 0) "Ancient Rome" else "Republic",
            referent = "Referent $index",
            knowledge = "Knowledge $index",
            answer = "Answer $index",
            question = "Question $index",
            correctExplanation = "Correct explanation $index",
            distractors = listOf(
                QuizContentDistractor("Distractor A$index", "Feedback A$index"),
                QuizContentDistractor("Distractor B$index", "Feedback B$index"),
                QuizContentDistractor("Distractor C$index", "Feedback C$index"),
            ),
        )
    })

    @Test
    fun preparesFromSinglePlanCallAndBuildsExactlyTenQuestions() {
        var planCalls = 0
        val flow = QuizPreparer(
            planTopic = {
                planCalls += 1
                Outcome.Success(plan())
            },
        )

        val prepared = assertIs<Outcome.Success<PreparedQuiz>>(flow.prepare("IA")).value

        assertEquals(1, planCalls)
        assertEquals(10, prepared.route.size)
        assertEquals(10, prepared.questions.size)
        assertEquals(listOf(0, 1, 2, 3, 0, 1, 2, 3, 0, 1), prepared.questions.map { it.correctOptionIndex })
    }

    @Test
    fun alignsQuestionAnswerDistractorsAndFeedbackDeterministically() {
        val sourcePlan = plan()
        val prepared = assertIs<Outcome.Success<PreparedQuiz>>(
            QuizPreparer { Outcome.Success(sourcePlan) }.prepare("IA"),
        ).value

        assertEquals(listOf(0, 1, 2, 3, 0, 1, 2, 3, 0, 1), prepared.questions.map { it.correctOptionIndex })

        prepared.questions.forEachIndexed { index, question ->
            val source = sourcePlan.items[index]
            val correctOptionIndex = PreparedQuiz.correctOptionSequence[index]
            assertEquals(source.question, question.text)
            assertEquals(source.answer, question.options[correctOptionIndex])
            assertEquals(source.correctExplanation, question.feedbackFor(correctOptionIndex))

            val expectedDistractors = source.distractors.map { it.text }
            val expectedFeedback = source.distractors.map { it.explanation }
            val actualDistractors = question.options.filterIndexed { optionIndex, _ -> optionIndex != correctOptionIndex }
            val actualFeedback = (0..3)
                .filter { optionIndex -> optionIndex != correctOptionIndex }
                .map { optionIndex -> question.feedbackFor(optionIndex) }

            assertEquals(expectedDistractors, actualDistractors)
            assertEquals(expectedFeedback, actualFeedback)
        }
    }

    @Test
    fun failsWhenPlanningFails() {
        val flow = QuizPreparer(
            planTopic = { Outcome.Failure(QuizContentPlanningError.BlankTopic) },
        )

        val error = assertIs<Outcome.Failure<QuizPreparationError>>(flow.prepare("IA")).error
        assertEquals(QuizContentPlanningError.BlankTopic, (error as QuizPreparationError.PlanningFailed).cause)
    }
}
