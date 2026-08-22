package com.originark.still.domain.tts

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import com.originark.still.data.model.VoicePreset
import java.util.Locale

class StillTtsEngine(
    private val context: Context,
    private val onInitComplete: ((Boolean) -> Unit)? = null
) : TextToSpeech.OnInitListener {

    private var textToSpeech: TextToSpeech? = null
    private var isInitialized = false
    private var currentPreset: VoicePreset = VoicePreset.FREE_CALM

    init {
        textToSpeech = TextToSpeech(context.applicationContext, this)
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            isInitialized = true
            applyPreset(currentPreset)
            onInitComplete?.invoke(true)
        } else {
            isInitialized = false
            Log.e("StillTtsEngine", "TextToSpeech initialization failed with code $status")
            onInitComplete?.invoke(false)
        }
    }

    fun applyPreset(preset: VoicePreset) {
        currentPreset = preset
        textToSpeech?.let { tts ->
            val locale = Locale(preset.localeLanguage, preset.localeCountry)
            val result = tts.setLanguage(locale)
            if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                tts.setLanguage(Locale.US)
            }
            tts.setPitch(preset.pitch)
            tts.setSpeechRate(preset.speechRate)
        }
    }

    fun speak(
        text: String,
        onStart: (() -> Unit)? = null,
        onDone: (() -> Unit)? = null,
        onError: ((String) -> Unit)? = null
    ) {
        val tts = textToSpeech
        if (!isInitialized || tts == null) {
            onError?.invoke("TextToSpeech not initialized")
            return
        }

        val utteranceId = "nudge_${System.currentTimeMillis()}"
        tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(id: String?) {
                if (id == utteranceId) onStart?.invoke()
            }

            override fun onDone(id: String?) {
                if (id == utteranceId) onDone?.invoke()
            }

            @Deprecated("Deprecated in Java")
            override fun onError(id: String?) {
                if (id == utteranceId) onError?.invoke("TTS playback error")
            }

            override fun onError(id: String?, errorCode: Int) {
                if (id == utteranceId) onError?.invoke("TTS playback error code $errorCode")
            }
        })

        tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
    }

    fun stop() {
        textToSpeech?.stop()
    }

    fun release() {
        try {
            textToSpeech?.stop()
            textToSpeech?.shutdown()
        } catch (e: Exception) {
            Log.e("StillTtsEngine", "Error shutting down TTS", e)
        } finally {
            textToSpeech = null
            isInitialized = false
        }
    }
}
