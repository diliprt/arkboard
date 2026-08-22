package com.originark.still.domain.nudge

enum class FocusState {
    IDLE,
    LISTENING,
    TALKING,
    REFLECTING
}

data class NudgeDecision(
    val shouldNudge: Boolean,
    val message: String? = null,
    val reason: String = ""
)

class NudgeEngine(
    private val minNudgeIntervalMillis: Long = MIN_INTERVAL_MILLIS
) {
    companion object {
        const val MIN_INTERVAL_MILLIS = 8 * 60 * 1000L // 8 minutes minimum hard lock
        const val DISTRACTION_QUIET_THRESHOLD_MILLIS = 45 * 1000L // 45s of off-task discussion / quiet confusion
    }

    private var lastNudgeTimeMillis: Long = 0L
    private var isUserCurrentlyTalking: Boolean = false
    private var lastUserSpeechTimeMillis: Long = 0L
    private var lastHeardTranscript: String = ""

    fun onUserSpeechStarted(currentTimeMillis: Long) {
        isUserCurrentlyTalking = true
        lastUserSpeechTimeMillis = currentTimeMillis
    }

    fun onUserSpeechEnded(transcript: String, currentTimeMillis: Long) {
        isUserCurrentlyTalking = false
        lastUserSpeechTimeMillis = currentTimeMillis
        lastHeardTranscript = transcript
    }

    fun canNudge(currentTimeMillis: Long): Boolean {
        // Rule 1: Never interrupt user while talking (Listen-first)
        if (isUserCurrentlyTalking) {
            return false
        }

        // Rule 2: Hard lock - Minimum 8 minutes between nudges
        if (lastNudgeTimeMillis > 0 && (currentTimeMillis - lastNudgeTimeMillis) < minNudgeIntervalMillis) {
            return false
        }

        return true
    }

    fun evaluateNudge(
        taskTitle: String,
        sessionDurationMillis: Long,
        currentTimeMillis: Long
    ): NudgeDecision {
        if (taskTitle.isBlank()) {
            return NudgeDecision(false, null, "No active task title")
        }

        if (!canNudge(currentTimeMillis)) {
            val waitRemaining = if (lastNudgeTimeMillis > 0) {
                (minNudgeIntervalMillis - (currentTimeMillis - lastNudgeTimeMillis)) / 1000
            } else 0
            val reason = if (isUserCurrentlyTalking) "User is currently speaking" else "In 8-minute cooldown (${waitRemaining}s left)"
            return NudgeDecision(false, null, reason)
        }

        // Generate one calm sentence nudge
        val message = generateCalmNudge(taskTitle)
        lastNudgeTimeMillis = currentTimeMillis

        return NudgeDecision(
            shouldNudge = true,
            message = message,
            reason = "Calm interval reached"
        )
    }

    fun generateCalmNudge(taskTitle: String): String {
        // Calm, grounding, single-sentence reminder of the started task
        val templates = listOf(
            "Gently returning your focus to $taskTitle.",
            "Take a calm breath, and continue with $taskTitle.",
            "Whenever you're ready, let's keep moving forward with $taskTitle.",
            "Still here with you on $taskTitle."
        )
        val index = (Math.abs(taskTitle.hashCode() + lastNudgeTimeMillis) % templates.size).toInt()
        return templates[index]
    }

    fun reset() {
        lastNudgeTimeMillis = 0L
        isUserCurrentlyTalking = false
        lastUserSpeechTimeMillis = 0L
        lastHeardTranscript = ""
    }

    fun setLastNudgeTimeForTesting(timeMillis: Long) {
        lastNudgeTimeMillis = timeMillis
    }
}
