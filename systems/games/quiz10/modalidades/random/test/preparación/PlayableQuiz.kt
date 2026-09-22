package dev.magullodev.aiapps.systems.games.quiz10.random.test.preparación

data class PlayableQuizQuestion(
    val area: String,
    val difficulty: CoverageDifficulty,
    val question: String,
    val answer: String,
    val distractors: List<String>,
) {
    init {
        require(area.isNotBlank())
        require(question.isNotBlank())
        require(answer.isNotBlank())
        require(distractors.size == 3)
        require(distractors.all { it.isNotBlank() })
    }
}

data class PlayableQuiz(
    val topic: String,
    val questions: List<PlayableQuizQuestion>,
) {
    init {
        require(topic.isNotBlank())
        require(questions.size == 10)
    }
}
