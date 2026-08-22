package com.originark.still.domain.audio

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log

class AndroidSpeechManager(
    private val context: Context
) : AudioController {
    private var speechRecognizer: SpeechRecognizer? = null
    private var listening: Boolean = false

    override fun startListening(listener: SpeechListener) {
        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            listener.onError(-1, "Speech recognition is not available on this device")
            return
        }

        stopListening()

        try {
            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context).apply {
                setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) {
                        listener.onReadyForSpeech()
                    }

                    override fun onBeginningOfSpeech() {
                        listener.onBeginningOfSpeech()
                    }

                    override fun onRmsChanged(rmsdB: Float) {
                        listener.onRmsChanged(rmsdB)
                    }

                    override fun onBufferReceived(buffer: ByteArray?) {}

                    override fun onEndOfSpeech() {
                        listener.onEndOfSpeech()
                    }

                    override fun onError(error: Int) {
                        val errorMessage = getErrorDescription(error)
                        listener.onError(error, errorMessage)
                        // If it's a transient error during continuous session, recreate or re-listen gracefully
                        listening = false
                    }

                    override fun onResults(results: Bundle?) {
                        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val text = matches?.firstOrNull() ?: ""
                        listener.onSpeechResult(text)
                    }

                    override fun onPartialResults(partialResults: Bundle?) {
                        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        val text = matches?.firstOrNull() ?: ""
                        if (text.isNotBlank()) {
                            listener.onSpeechResult(text)
                        }
                    }

                    override fun onEvent(eventType: Int, params: Bundle?) {}
                })
            }

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            }

            speechRecognizer?.startListening(intent)
            listening = true
        } catch (e: Exception) {
            Log.e("AndroidSpeechManager", "Failed to start speech recognition", e)
            listener.onError(-2, e.localizedMessage ?: "Unknown speech recognition error")
            listening = false
        }
    }

    override fun stopListening() {
        listening = false
        try {
            speechRecognizer?.stopListening()
            speechRecognizer?.cancel()
            speechRecognizer?.destroy()
        } catch (e: Exception) {
            Log.e("AndroidSpeechManager", "Error stopping speech recognizer", e)
        } finally {
            speechRecognizer = null
        }
    }

    override fun isListening(): Boolean = listening

    private fun getErrorDescription(errorCode: Int): String = when (errorCode) {
        SpeechRecognizer.ERROR_AUDIO -> "Audio recording error"
        SpeechRecognizer.ERROR_CLIENT -> "Client-side error"
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions"
        SpeechRecognizer.ERROR_NETWORK -> "Network error"
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout"
        SpeechRecognizer.ERROR_NO_MATCH -> "No speech match"
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognition service busy"
        SpeechRecognizer.ERROR_SERVER -> "Server error"
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech input detected"
        else -> "Speech recognition error ($errorCode)"
    }
}
