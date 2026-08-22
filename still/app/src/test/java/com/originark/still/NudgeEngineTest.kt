package com.originark.still

import com.originark.still.domain.audio.SpeechListener
import com.originark.still.domain.nudge.NudgeEngine
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class NudgeEngineTest {
    private lateinit var nudgeEngine: NudgeEngine
    private val minInterval = 8 * 60 * 1000L // 8 min

    @Before
    fun setup() {
        nudgeEngine = NudgeEngine(minNudgeIntervalMillis = minInterval)
    }

    @Test
    fun testNudgeMinimum8MinutesIntervalHardLock() {
        val t0 = 1000000L
        val task = "Writing clean code"

        // First nudge at t0 should succeed
        val decision1 = nudgeEngine.evaluateNudge(task, 0L, t0)
        assertTrue("First nudge should succeed", decision1.shouldNudge)
        assertNotNull(decision1.message)

        // At t0 + 4 minutes (less than 8 minutes), nudge MUST be rejected
        val t4Min = t0 + 4 * 60 * 1000L
        val decision2 = nudgeEngine.evaluateNudge(task, 4 * 60 * 1000L, t4Min)
        assertFalse("Nudge at 4 min must be rejected due to 8 min hard lock", decision2.shouldNudge)
        assertNull(decision2.message)
        assertTrue(decision2.reason.contains("cooldown"))

        // At t0 + 7.9 minutes, still rejected
        val t7Min59Sec = t0 + (8 * 60 * 1000L) - 1000L
        val decision3 = nudgeEngine.evaluateNudge(task, 7 * 60 * 1000L, t7Min59Sec)
        assertFalse("Nudge at 7m59s must be rejected", decision3.shouldNudge)

        // At t0 + 8.1 minutes, nudge should succeed again
        val t8Min10Sec = t0 + (8 * 60 * 1000L) + 10000L
        val decision4 = nudgeEngine.evaluateNudge(task, 8 * 60 * 1000L, t8Min10Sec)
        assertTrue("Nudge after 8 minutes must succeed", decision4.shouldNudge)
        assertNotNull(decision4.message)
    }

    @Test
    fun testListenFirstUserTalkingNeverInterrupted() {
        val t0 = 1000000L
        val task = "Studying algorithms"

        // Simulate user speaking
        nudgeEngine.onUserSpeechStarted(t0)

        // Even if interval is satisfied, user talking blocks nudge
        val decision = nudgeEngine.evaluateNudge(task, 0L, t0 + 1000L)
        assertFalse("Nudge must not interrupt user while speaking", decision.shouldNudge)
        assertTrue(decision.reason.contains("speaking"))

        // User finishes speaking
        nudgeEngine.onUserSpeechEnded("I'm looking at quicksort", t0 + 2000L)

        // Now can nudge
        val decisionAfterSpeech = nudgeEngine.evaluateNudge(task, 0L, t0 + 3000L)
        assertTrue("Can nudge after user finishes speaking", decisionAfterSpeech.shouldNudge)
    }

    @Test
    fun testEmptyTaskTitleDoesNotNudge() {
        val t0 = 1000000L
        val decision = nudgeEngine.evaluateNudge("", 0L, t0)
        assertFalse(decision.shouldNudge)
    }
}
