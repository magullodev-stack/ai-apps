package dev.magullodev.aiapps.ai

data class StructuredGenerationRequest(
    val profile: AiProfile,
    val input: String,
    val schemaName: String,
    val schemaJson: String,
    val operation: AiUsageOperation? = null,
    val model: String? = null,
)
