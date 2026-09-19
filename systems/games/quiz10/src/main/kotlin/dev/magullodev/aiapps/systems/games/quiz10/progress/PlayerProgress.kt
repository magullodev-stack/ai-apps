package dev.magullodev.aiapps.systems.games.quiz10.progress

class PlayerProgress private constructor(
    val playerName: String,
    val answeredQuestions: Int,
    val correctAnswers: Int,
    val stars: Int,
) {
    val incorrectAnswers: Int
        get() = answeredQuestions - correctAnswers

    val accuracyPercent: Int
        get() = if (answeredQuestions == 0) 0 else (correctAnswers * 100) / answeredQuestions

    companion object {
        fun start(playerName: String): PlayerProgress {
            val normalizedName = playerName.trim()
            require(normalizedName.isNotEmpty()) { "Player name must not be blank" }
            return PlayerProgress(
                playerName = normalizedName,
                answeredQuestions = 0,
                correctAnswers = 0,
                stars = 0,
            )
        }
    }

    fun recordQuiz(correctAnswers: Int): PlayerProgress {
        require(correctAnswers in 0..10) { "Quiz correct answers must be between 0 and 10" }

        return PlayerProgress(
            playerName = playerName,
            answeredQuestions = answeredQuestions + 10,
            correctAnswers = this.correctAnswers + correctAnswers,
            stars = stars + if (correctAnswers == 10) 1 else 0,
        )
    }
}
