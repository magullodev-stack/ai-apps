package dev.magullodev.aiapps.core.ai

data class StructuredGenerationRequest(
    val profile: AiProfile,
    val input: String,
    val schemaName: String,
    val schemaJson: String,
)
