package dev.magullodev.aiapps.core.ai

data class StructuredGenerationRequest(
    val model: String,
    val input: String,
    val schemaName: String,
    val schemaJson: String,
)
