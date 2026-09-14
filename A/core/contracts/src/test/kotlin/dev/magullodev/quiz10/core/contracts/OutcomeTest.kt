package dev.magullodev.quiz10.core.contracts

import kotlin.test.Test
import kotlin.test.assertIs
import kotlin.test.assertSame

class OutcomeTest {
    @Test
    fun successPreservesItsValue() {
        val value = Any()

        val outcome = Outcome.Success(value)

        assertSame(value, outcome.value)
    }

    @Test
    fun failurePreservesItsError() {
        val error = Any()

        val outcome = Outcome.Failure(error)

        assertSame(error, outcome.error)
    }

    @Test
    fun variantsShareTheOutcomeType() {
        val value = Any()
        val error = Any()
        val success: Outcome<Any, Any> = Outcome.Success(value)
        val failure: Outcome<Any, Any> = Outcome.Failure(error)

        assertIs<Outcome.Success<Any>>(success)
        assertSame(value, success.value)
        assertIs<Outcome.Failure<Any>>(failure)
        assertSame(error, failure.error)
    }
}
