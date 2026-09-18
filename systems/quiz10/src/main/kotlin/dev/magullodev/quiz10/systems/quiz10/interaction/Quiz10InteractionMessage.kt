package dev.magullodev.quiz10.systems.quiz10.interaction

data class Quiz10InteractionMessage(
    val message: String,
) {
    init {
        require(message.trim().isNotEmpty()) { "Interaction message must not be blank" }
    }
}