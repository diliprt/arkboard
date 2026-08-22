package com.originark.still.ui

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.RecordVoiceOver
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import com.originark.still.StillApplication
import com.originark.still.data.model.SessionLog
import com.originark.still.data.model.Task
import com.originark.still.data.model.VoicePreset
import com.originark.still.domain.audio.AndroidSpeechManager
import com.originark.still.domain.audio.SpeechListener
import com.originark.still.domain.billing.PlayBillingManager
import com.originark.still.domain.nudge.FocusState
import com.originark.still.domain.nudge.NudgeEngine
import com.originark.still.domain.tts.StillTtsEngine
import com.originark.still.ui.screens.HomeScreen
import com.originark.still.ui.screens.SettingsScreen
import com.originark.still.ui.screens.StillScreen
import com.originark.still.ui.screens.TasksScreen
import com.originark.still.ui.screens.VoicesScreen
import com.originark.still.ui.theme.DarkBackground
import com.originark.still.ui.theme.DarkSurface
import com.originark.still.ui.theme.SagePrimary
import com.originark.still.ui.theme.StillTheme
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

@Composable
fun StillApp() {
    val context = LocalContext.current
    val app = context.applicationContext as StillApplication
    val repository = app.repository
    val scope = rememberCoroutineScope()

    var currentScreen by remember { mutableStateOf(StillScreen.HOME) }
    val tasks by repository.allTasks.collectAsState(initial = emptyList())
    val activeTask by repository.activeTask.collectAsState(initial = null)

    // Speech, TTS, Nudge, and Billing components
    val speechManager = remember { AndroidSpeechManager(context) }
    val nudgeEngine = remember { NudgeEngine() }
    val ttsEngine = remember { StillTtsEngine(context) }
    val billingManager = remember { PlayBillingManager(context, scope) }
    val billingState by billingManager.billingState.collectAsState()

    var selectedVoice by remember { mutableStateOf(VoicePreset.FREE_CALM) }
    var isSessionActive by remember { mutableStateOf(false) }
    var sessionDurationSeconds by remember { mutableLongStateOf(0L) }
    var sessionStartTime by remember { mutableLongStateOf(0L) }
    var focusState by remember { mutableStateOf(FocusState.IDLE) }
    var lastNudgeMessage by remember { mutableStateOf<String?>(null) }
    var currentSessionLogId by remember { mutableStateOf<Long?>(null) }
    var nudgeCountInSession by remember { mutableStateOf(0) }

    var hasAudioPermission by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        )
    }
    var showPermissionRationaleDialog by remember { mutableStateOf(false) }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        hasAudioPermission = isGranted
        if (!isGranted) {
            Toast.makeText(context, "Microphone permission is needed for speech detection in focus sessions", Toast.LENGTH_LONG).show()
        }
    }

    fun requestAudioPermissionWithRationale() {
        if (!hasAudioPermission) {
            showPermissionRationaleDialog = true
        }
    }

    // Initialize Billing
    LaunchedEffect(Unit) {
        billingManager.startConnection()
    }

    // Clean up on exit
    DisposableEffect(Unit) {
        onDispose {
            speechManager.stopListening()
            ttsEngine.release()
            billingManager.destroy()
        }
    }

    // Session Start & Nudge Loop
    LaunchedEffect(isSessionActive) {
        if (isSessionActive) {
            sessionStartTime = System.currentTimeMillis()
            sessionDurationSeconds = 0L
            nudgeCountInSession = 0
            nudgeEngine.onSessionStarted(sessionStartTime)
            focusState = FocusState.TALKING

            // Speak initial start prompt once, then enter silence & listen-first mode
            val startPrompt = nudgeEngine.generateSessionStartPrompt(activeTask?.title ?: "your task")
            lastNudgeMessage = startPrompt
            ttsEngine.applyPreset(selectedVoice)
            ttsEngine.speak(
                text = startPrompt,
                onStart = {
                    focusState = FocusState.TALKING
                },
                onDone = {
                    focusState = FocusState.LISTENING
                },
                onError = {
                    focusState = FocusState.LISTENING
                }
            )

            // Start SpeechRecognizer in listening mode
            lateinit var speechListener: SpeechListener
            speechListener = object : SpeechListener {
                override fun onReadyForSpeech() {}
                override fun onBeginningOfSpeech() {
                    focusState = FocusState.LISTENING
                    nudgeEngine.onUserSpeechStarted(System.currentTimeMillis())
                }

                override fun onRmsChanged(rmsdB: Float) {}

                override fun onSpeechResult(text: String) {
                    nudgeEngine.onUserSpeechEnded(text, System.currentTimeMillis())
                }

                override fun onError(errorCode: Int, message: String) {
                    // Re-arm listener if session is still active
                    if (isSessionActive && !speechManager.isListening()) {
                        scope.launch {
                            delay(1000)
                            if (isSessionActive) {
                                speechManager.startListening(speechListener)
                            }
                        }
                    }
                }

                override fun onEndOfSpeech() {
                    nudgeEngine.onUserSpeechEnded("", System.currentTimeMillis())
                    // Automatically re-listen for ongoing quiet ambient speech during session
                    if (isSessionActive) {
                        scope.launch {
                            delay(500)
                            if (isSessionActive && !speechManager.isListening()) {
                                speechManager.startListening(speechListener)
                            }
                        }
                    }
                }
            }
            speechManager.startListening(speechListener)

            while (isActive && isSessionActive) {
                delay(1000)
                sessionDurationSeconds++

                // Periodically check nudge eligibility (8-min hard lock + user speech silence check)
                val now = System.currentTimeMillis()
                val currentTask = activeTask
                if (currentTask != null) {
                    val decision = nudgeEngine.evaluateNudge(
                        taskTitle = currentTask.title,
                        sessionDurationMillis = sessionDurationSeconds * 1000L,
                        currentTimeMillis = now
                    )

                    if (decision.shouldNudge && decision.message != null) {
                        lastNudgeMessage = decision.message
                        focusState = FocusState.TALKING
                        nudgeCountInSession++

                        ttsEngine.applyPreset(selectedVoice)
                        ttsEngine.speak(
                            text = decision.message,
                            onStart = { focusState = FocusState.TALKING },
                            onDone = { focusState = FocusState.LISTENING },
                            onError = { focusState = FocusState.LISTENING }
                        )
                    }
                }
            }
        } else {
            // Guarantee mic is completely powered off and audio engine destroyed/reset
            speechManager.stopListening()
            ttsEngine.stop()
            nudgeEngine.reset()
            focusState = FocusState.IDLE
        }
    }

    StillTheme {
        Scaffold(
            containerColor = DarkBackground,
            bottomBar = {
                NavigationBar(
                    containerColor = DarkSurface,
                    contentColor = SagePrimary
                ) {
                    NavigationBarItem(
                        icon = { Icon(Icons.Default.GraphicEq, contentDescription = "Focus") },
                        label = { Text("Focus") },
                        selected = currentScreen == StillScreen.HOME,
                        onClick = { currentScreen = StillScreen.HOME },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = SagePrimary,
                            selectedTextColor = SagePrimary,
                            indicatorColor = DarkSurface
                        )
                    )
                    NavigationBarItem(
                        icon = { Icon(Icons.AutoMirrored.Filled.List, contentDescription = "Tasks") },
                        label = { Text("Tasks") },
                        selected = currentScreen == StillScreen.TASKS,
                        onClick = { currentScreen = StillScreen.TASKS },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = SagePrimary,
                            selectedTextColor = SagePrimary,
                            indicatorColor = DarkSurface
                        )
                    )
                    NavigationBarItem(
                        icon = { Icon(Icons.Default.RecordVoiceOver, contentDescription = "Voices") },
                        label = { Text("Voices") },
                        selected = currentScreen == StillScreen.VOICES,
                        onClick = { currentScreen = StillScreen.VOICES },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = SagePrimary,
                            selectedTextColor = SagePrimary,
                            indicatorColor = DarkSurface
                        )
                    )
                    NavigationBarItem(
                        icon = { Icon(Icons.Default.Settings, contentDescription = "Settings") },
                        label = { Text("Settings") },
                        selected = currentScreen == StillScreen.SETTINGS,
                        onClick = { currentScreen = StillScreen.SETTINGS },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = SagePrimary,
                            selectedTextColor = SagePrimary,
                            indicatorColor = DarkSurface
                        )
                    )
                }
            }
        ) { innerPadding ->
            Box(modifier = Modifier.padding(innerPadding)) {
                when (currentScreen) {
                    StillScreen.HOME -> HomeScreen(
                        activeTask = activeTask,
                        isSessionActive = isSessionActive,
                        sessionDurationSeconds = sessionDurationSeconds,
                        focusState = focusState,
                        lastNudgeMessage = lastNudgeMessage,
                        onStartSession = {
                            if (!hasAudioPermission) {
                                requestAudioPermissionWithRationale()
                            } else {
                                scope.launch {
                                    val logId = repository.insertSessionLog(
                                        SessionLog(
                                            taskId = activeTask?.id,
                                            taskTitle = activeTask?.title ?: "Focus Session",
                                            startedAt = System.currentTimeMillis(),
                                            endedAt = null
                                        )
                                    )
                                    currentSessionLogId = logId
                                    isSessionActive = true
                                }
                            }
                        },
                        onEndSession = {
                            isSessionActive = false
                            scope.launch {
                                currentSessionLogId?.let { id ->
                                    val log = SessionLog(
                                        id = id,
                                        taskId = activeTask?.id,
                                        taskTitle = activeTask?.title ?: "Focus Session",
                                        startedAt = sessionStartTime,
                                        endedAt = System.currentTimeMillis(),
                                        durationSeconds = sessionDurationSeconds,
                                        nudgeCount = nudgeCountInSession
                                    )
                                    repository.updateSessionLog(log)
                                }
                            }
                        },
                        onNavigateToTasks = { currentScreen = StillScreen.TASKS }
                    )

                    StillScreen.TASKS -> TasksScreen(
                        tasks = tasks,
                        onAddTask = { title, desc ->
                            scope.launch {
                                val isFirst = tasks.isEmpty()
                                repository.insertTask(
                                    Task(
                                        title = title,
                                        description = desc,
                                        isActive = isFirst
                                    )
                                )
                            }
                        },
                        onSetActiveTask = { taskId ->
                            scope.launch {
                                repository.setActiveTask(taskId)
                            }
                        },
                        onToggleComplete = { task ->
                            scope.launch {
                                repository.updateTask(
                                    task.copy(
                                        isCompleted = !task.isCompleted,
                                        completedAt = if (!task.isCompleted) System.currentTimeMillis() else null
                                    )
                                )
                            }
                        },
                        onDeleteTask = { task ->
                            scope.launch {
                                repository.deleteTask(task)
                            }
                        }
                    )

                    StillScreen.VOICES -> VoicesScreen(
                        selectedVoice = selectedVoice,
                        billingState = billingState,
                        onSelectVoice = { voice ->
                            selectedVoice = voice
                            ttsEngine.applyPreset(voice)
                        },
                        onPreviewVoice = { voice ->
                            ttsEngine.applyPreset(voice)
                            ttsEngine.speak("This is ${voice.name}. Unhurried, grounded focus.")
                        },
                        onSubscribe = { productId ->
                            (context as? Activity)?.let { activity ->
                                billingManager.launchBillingFlow(activity, productId)
                            }
                        },
                        onRestorePurchases = {
                            billingManager.restorePurchases()
                            Toast.makeText(context, "Checking for active subscriptions...", Toast.LENGTH_SHORT).show()
                        }
                    )

                    StillScreen.SETTINGS -> SettingsScreen(
                        hasAudioPermission = hasAudioPermission,
                        onRequestPermission = {
                            requestAudioPermissionWithRationale()
                        },
                        onRestorePurchases = {
                            billingManager.restorePurchases()
                            Toast.makeText(context, "Checking for active subscriptions...", Toast.LENGTH_SHORT).show()
                        }
                    )
                }
            }

            // Microphone Permission Rationale Dialog
            if (showPermissionRationaleDialog) {
                AlertDialog(
                    onDismissRequest = { showPermissionRationaleDialog = false },
                    title = { Text("Microphone Access Rationale") },
                    text = {
                        Text(
                            "Still uses your microphone solely to detect speech activity during active Focus Sessions. " +
                            "This ensures Still remains silent when you speak and avoids interrupting you.\n\n" +
                            "• Active only during explicit Focus Sessions\n" +
                            "• Processed in ephemeral device memory\n" +
                            "• Never recorded, uploaded, or shared"
                        )
                    },
                    confirmButton = {
                        Button(
                            onClick = {
                                showPermissionRationaleDialog = false
                                permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = SagePrimary)
                        ) {
                            Text("Continue", color = Color.White)
                        }
                    },
                    dismissButton = {
                        TextButton(onClick = { showPermissionRationaleDialog = false }) {
                            Text("Not Now")
                        }
                    }
                )
            }
        }
    }
}
