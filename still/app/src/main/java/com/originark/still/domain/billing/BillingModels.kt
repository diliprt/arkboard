package com.originark.still.domain.billing

data class SubscriptionPlan(
    val productId: String,
    val title: String,
    val description: String,
    val formattedPrice: String,
    val billingPeriod: String
)

data class BillingState(
    val isPremiumSubscribed: Boolean = false,
    val activeSubscriptionId: String? = null,
    val availablePlans: List<SubscriptionPlan> = emptyList(),
    val isLoading: Boolean = false,
    val errorMessage: String? = null
) {
    companion object {
        const val PRODUCT_ID_MONTHLY = "still_voices_monthly"
        const val PRODUCT_ID_YEARLY = "still_voices_yearly"

        val DEFAULT_MONTHLY_PLAN = SubscriptionPlan(
            productId = PRODUCT_ID_MONTHLY,
            title = "Still Voices Monthly",
            description = "Unlock all serene TTS voice presets (Forest Whisper, Dusk Serenity, Zen Harbor)",
            formattedPrice = "$2.99 / month",
            billingPeriod = "1 month"
        )

        val DEFAULT_YEARLY_PLAN = SubscriptionPlan(
            productId = PRODUCT_ID_YEARLY,
            title = "Still Voices Yearly",
            description = "Annual access to all present and future voice presets. Best value.",
            formattedPrice = "$19.99 / year",
            billingPeriod = "1 year"
        )
    }
}
