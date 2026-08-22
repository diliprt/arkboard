package com.originark.still.ui.screens

import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.originark.still.data.model.VoicePreset
import com.originark.still.domain.billing.BillingState
import com.originark.still.domain.billing.SubscriptionPlan
import com.originark.still.ui.theme.SagePrimary
import com.originark.still.ui.theme.SagePrimaryContainer

@Composable
fun VoicesScreen(
    selectedVoice: VoicePreset,
    billingState: BillingState,
    onSelectVoice: (VoicePreset) -> Unit,
    onPreviewVoice: (VoicePreset) -> Unit,
    onSubscribe: (String) -> Unit,
    onRestorePurchases: () -> Unit
) {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Text(
                text = "TTS Voice Presets",
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.colorScheme.onBackground
            )
            Text(
                text = "Choose the calm voice Still uses when nudging your focus.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        // Subscription banner if not subscribed
        if (!billingState.isPremiumSubscribed) {
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = SagePrimaryContainer.copy(alpha = 0.4f)
                    ),
                    shape = RoundedCornerShape(16.dp)
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text(
                            text = "STILL VOICES SUBSCRIPTION",
                            style = MaterialTheme.typography.labelMedium,
                            color = SagePrimary,
                            fontWeight = FontWeight.Bold
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Unlock Extra TTS Voices",
                            style = MaterialTheme.typography.titleLarge,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Free tier includes Still Calm. Subscribe to access Forest Whisper, Dusk Serenity, and Zen Harbor.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )

                        Spacer(modifier = Modifier.height(12.dp))

                        if (billingState.isLoading) {
                            CircularProgressIndicator(
                                color = SagePrimary,
                                modifier = Modifier.size(24.dp)
                            )
                        } else {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                val monthlyPlan = billingState.availablePlans.find { it.productId == BillingState.PRODUCT_ID_MONTHLY }
                                val yearlyPlan = billingState.availablePlans.find { it.productId == BillingState.PRODUCT_ID_YEARLY }

                                Button(
                                    onClick = { onSubscribe(BillingState.PRODUCT_ID_MONTHLY) },
                                    modifier = Modifier.weight(1f),
                                    colors = ButtonDefaults.buttonColors(containerColor = SagePrimary),
                                    shape = RoundedCornerShape(10.dp)
                                ) {
                                    Text(
                                        text = monthlyPlan?.formattedPrice ?: "Monthly",
                                        color = Color.White,
                                        fontSize = 12.sp
                                    )
                                }

                                Button(
                                    onClick = { onSubscribe(BillingState.PRODUCT_ID_YEARLY) },
                                    modifier = Modifier.weight(1f),
                                    colors = ButtonDefaults.buttonColors(containerColor = SagePrimary),
                                    shape = RoundedCornerShape(10.dp)
                                ) {
                                    Text(
                                        text = yearlyPlan?.formattedPrice ?: "Yearly",
                                        color = Color.White,
                                        fontSize = 12.sp
                                    )
                                }
                            }
                        }
                    }
                }
            }
        } else {
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = SagePrimaryContainer.copy(alpha = 0.5f)
                    ),
                    shape = RoundedCornerShape(16.dp)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.Check,
                            contentDescription = "Subscribed",
                            tint = SagePrimary,
                            modifier = Modifier.size(28.dp)
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text(
                                text = "Still Voices Active",
                                style = MaterialTheme.typography.titleLarge,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                text = "All voice presets unlocked.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }

        items(VoicePreset.ALL_PRESETS, key = { it.id }) { preset ->
            val isSelected = selectedVoice.id == preset.id
            val isLocked = preset.isPremium && !billingState.isPremiumSubscribed

            VoicePresetCard(
                preset = preset,
                isSelected = isSelected,
                isLocked = isLocked,
                onSelect = {
                    if (!isLocked) onSelectVoice(preset)
                },
                onPreview = { onPreviewVoice(preset) }
            )
        }

        item {
            OutlinedButton(
                onClick = onRestorePurchases,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp)
            ) {
                Text(text = "Restore Purchases", color = MaterialTheme.colorScheme.onSurface)
            }
        }
    }
}

@Composable
fun VoicePresetCard(
    preset: VoicePreset,
    isSelected: Boolean,
    isLocked: Boolean,
    onSelect: () -> Unit,
    onPreview: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onSelect() }
            .then(
                if (isSelected) Modifier.border(2.dp, SagePrimary, RoundedCornerShape(14.dp))
                else Modifier
            ),
        colors = CardDefaults.cardColors(
            containerColor = if (isSelected) MaterialTheme.colorScheme.surfaceVariant else MaterialTheme.colorScheme.surface
        ),
        shape = RoundedCornerShape(14.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = preset.name,
                        style = MaterialTheme.typography.titleLarge,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    if (preset.isPremium) {
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "PREMIUM",
                            style = MaterialTheme.typography.labelMedium,
                            color = SagePrimary,
                            fontWeight = FontWeight.Bold
                        )
                    } else {
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "FREE",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = preset.description,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            IconButton(onClick = onPreview) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.VolumeUp,
                    contentDescription = "Preview Voice",
                    tint = SagePrimary
                )
            }

            if (isLocked) {
                Icon(
                    imageVector = Icons.Default.Lock,
                    contentDescription = "Locked",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(start = 8.dp)
                )
            } else if (isSelected) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = "Selected",
                    tint = SagePrimary,
                    modifier = Modifier.padding(start = 8.dp)
                )
            }
        }
    }
}
