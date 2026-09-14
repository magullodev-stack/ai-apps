package dev.magullodev.quiz10.core.ai

data class StructuredGenerationRequest(
    val profile: GenerationProfile,
    val input: String,
    val schemaName: String,
    val schemaJson: String,
)
