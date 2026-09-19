package dev.magullodev.aiapps.systems.games.quiz10.interaction

data class Quiz10InteractionContext(
    val event: Quiz10InteractionEvent,
    val playerName: String,
    val topic: String,
    val answeredQuestions: Int,
    val correctAnswers: Int,
    val totalQuestions: Int,
    val stars: Int,
    val lastAnswerCorrect: Boolean?,
    val starEarned: Boolean,
) {
    init {
        require(playerName.trim().isNotEmpty()) { "Player name must not be blank" }
        require(topic.trim().isNotEmpty()) { "Topic must not be blank" }
        require(totalQuestions in 1..10) { "Total questions must be between 1 and 10" }
        require(answeredQuestions in 0..totalQuestions) { "Answered questions out of range" }
        require(correctAnswers in 0..totalQuestions) { "Correct answers out of range" }
        require(correctAnswers <= answeredQuestions) { "Correct answers cannot exceed answered questions" }
        require(stars >= 0) { "Stars cannot be negative" }

        when (event) {
            Quiz10InteractionEvent.WELCOME -> {
                require(answeredQuestions == 0) { "WELCOME requires zero answered questions" }
                require(lastAnswerCorrect == null) { "WELCOME cannot include lastAnswerCorrect" }
                require(!starEarned) { "WELCOME cannot set starEarned" }
            }

            Quiz10InteractionEvent.AFTER_ANSWER -> {
                require(lastAnswerCorrect != null) { "AFTER_ANSWER requires lastAnswerCorrect" }
                require(!starEarned) { "AFTER_ANSWER cannot set starEarned" }
            }

            Quiz10InteractionEvent.FINISH -> {
                require(totalQuestions == 10) { "FINISH requires totalQuestions == 10" }
                require(answeredQuestions == 10) { "FINISH requires 10 answered questions" }
                require(correctAnswers in 0..10) { "FINISH correct answers out of range" }
                require(starEarned == (correctAnswers == 10)) { "starEarned must match 10/10 result" }
            }
        }
    }
}