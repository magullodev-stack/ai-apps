package dev.magullodev.aiapps.core.ai

data class StructuredGeneration(
    val text: String,
    val usage: TokenUsage?,
)

data class TokenUsage(
    val inputTokens: Long?,
    val outputTokens: Long?,
    val totalTokens: Long?,
)
