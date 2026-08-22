package com.originark.still.data.model

data class VoicePreset(
    val id: String,
    val name: String,
    val description: String,
    val isPremium: Boolean,
    val pitch: Float = 1.0f,
    val speechRate: Float = 0.88f, // Calm, unhurried cadence
    val localeLanguage: String = "en",
    val localeCountry: String = "US"
) {
    companion object {
        val FREE_CALM = VoicePreset(
            id = "still_calm",
            name = "Still Calm",
            description = "Default peaceful, unhurried voice. Gentle and grounding.",
            isPremium = false,
            pitch = 0.92f,
            speechRate = 0.85f
        )

        val FOREST_WHISPER = VoicePreset(
            id = "forest_whisper",
            name = "Forest Whisper",
            description = "Soft, deep, nature-inspired timber with low resonance.",
            isPremium = true,
            pitch = 0.82f,
            speechRate = 0.82f
        )

        val DUSK_SERENITY = VoicePreset(
            id = "dusk_serenity",
            name = "Dusk Serenity",
            description = "Warm twilight tone designed to ease cognitive tension.",
            isPremium = true,
            pitch = 1.02f,
            speechRate = 0.88f
        )

        val ZEN_HARBOR = VoicePreset(
            id = "zen_harbor",
            name = "Zen Harbor",
            description = "Steady, reassuring presence for deep, immersive focus.",
            isPremium = true,
            pitch = 0.88f,
            speechRate = 0.80f
        )

        val ALL_PRESETS = listOf(FREE_CALM, FOREST_WHISPER, DUSK_SERENITY, ZEN_HARBOR)
    }
}
