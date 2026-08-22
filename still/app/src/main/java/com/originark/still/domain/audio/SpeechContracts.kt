package com.originark.still.domain.audio

interface SpeechListener {
    fun onReadyForSpeech()
    fun onBeginningOfSpeech()
    fun onRmsChanged(rmsdB: Float)
    fun onSpeechResult(text: String)
    fun onError(errorCode: Int, message: String)
    fun onEndOfSpeech()
}

interface AudioController {
    fun startListening(listener: SpeechListener)
    fun stopListening()
    fun isListening(): Boolean
}
