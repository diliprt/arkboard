package com.originark.still.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable

@Composable
fun StillTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = StillColorScheme,
        typography = StillTypography,
        content = content
    )
}
