package com.originark.still.ui.theme

import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color

// Sage accent (#718B5F)
val SagePrimary = Color(0xFF718B5F)
val SageOnPrimary = Color(0xFFFFFFFF)
val SagePrimaryContainer = Color(0xFF3B4D2F)
val SageOnPrimaryContainer = Color(0xFFD4E8C2)

// Deep serene backgrounds
val DarkBackground = Color(0xFF101410)
val DarkSurface = Color(0xFF171C17)
val DarkSurfaceVariant = Color(0xFF222B22)
val DarkOnBackground = Color(0xFFE2E8E0)
val DarkOnSurface = Color(0xFFE2E8E0)
val DarkOnSurfaceVariant = Color(0xFFA5B3A2)

val DarkOutline = Color(0xFF434E41)
val DarkOutlineVariant = Color(0xFF2A3429)

val StillColorScheme = darkColorScheme(
    primary = SagePrimary,
    onPrimary = SageOnPrimary,
    primaryContainer = SagePrimaryContainer,
    onPrimaryContainer = SageOnPrimaryContainer,
    background = DarkBackground,
    onBackground = DarkOnBackground,
    surface = DarkSurface,
    onSurface = DarkOnSurface,
    surfaceVariant = DarkSurfaceVariant,
    onSurfaceVariant = DarkOnSurfaceVariant,
    outline = DarkOutline,
    outlineVariant = DarkOutlineVariant
)
