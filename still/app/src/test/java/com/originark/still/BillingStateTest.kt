package com.originark.still

import com.originark.still.domain.billing.BillingState
import com.originark.still.domain.billing.SubscriptionPlan
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BillingStateTest {

    @Test
    fun testDefaultBillingStateIsFree() {
        val state = BillingState()
        assertFalse("Default state must not be subscribed", state.isPremiumSubscribed)
        assertNull("Default active subscription ID must be null", state.activeSubscriptionId)
        assertFalse("Should not be loading by default", state.isLoading)
        assertNull(state.errorMessage)
    }

    @Test
    fun testSubscriptionPlanIds() {
        assertEquals("still_voices_monthly", BillingState.PRODUCT_ID_MONTHLY)
        assertEquals("still_voices_yearly", BillingState.PRODUCT_ID_YEARLY)

        val monthly = BillingState.DEFAULT_MONTHLY_PLAN
        assertEquals("still_voices_monthly", monthly.productId)
        assertTrue(monthly.title.contains("Monthly"))

        val yearly = BillingState.DEFAULT_YEARLY_PLAN
        assertEquals("still_voices_yearly", yearly.productId)
        assertTrue(yearly.title.contains("Yearly"))
    }

    @Test
    fun testSubscribedState() {
        val state = BillingState(
            isPremiumSubscribed = true,
            activeSubscriptionId = BillingState.PRODUCT_ID_YEARLY,
            availablePlans = listOf(BillingState.DEFAULT_MONTHLY_PLAN, BillingState.DEFAULT_YEARLY_PLAN)
        )

        assertTrue(state.isPremiumSubscribed)
        assertEquals("still_voices_yearly", state.activeSubscriptionId)
        assertEquals(2, state.availablePlans.size)
    }
}
