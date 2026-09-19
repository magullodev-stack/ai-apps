package dev.magullodev.aiapps.systems.games.quiz10.interaction

data class Quiz10InteractionMessage(
    val message: String,
) {
    init {
        require(message.trim().isNotEmpty()) { "Interaction message must not be blank" }
    }
}