package com.originark.still.domain.billing

import android.app.Activity
import android.content.Context
import android.content.SharedPreferences
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

interface BillingService {
    val billingState: StateFlow<BillingState>
    fun startConnection()
    fun launchBillingFlow(activity: Activity, productId: String)
    fun restorePurchases()
    fun destroy()
}

class PlayBillingManager(
    private val context: Context,
    private val coroutineScope: CoroutineScope = CoroutineScope(Dispatchers.Main)
) : BillingService, PurchasesUpdatedListener {

    private val prefs: SharedPreferences = context.getSharedPreferences("still_billing_prefs", Context.MODE_PRIVATE)
    private val _billingState = MutableStateFlow(
        BillingState(
            isPremiumSubscribed = prefs.getBoolean("is_premium_subscribed", false),
            activeSubscriptionId = prefs.getString("active_sub_id", null),
            availablePlans = listOf(BillingState.DEFAULT_MONTHLY_PLAN, BillingState.DEFAULT_YEARLY_PLAN)
        )
    )
    override val billingState: StateFlow<BillingState> = _billingState.asStateFlow()

    private var billingClient: BillingClient = BillingClient.newBuilder(context)
        .setListener(this)
        .enablePendingPurchases(com.android.billingclient.api.PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .build()

    private val productDetailsMap = mutableMapOf<String, ProductDetails>()

    override fun startConnection() {
        _billingState.value = _billingState.value.copy(isLoading = true)
        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(billingResult: BillingResult) {
                if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                    queryAvailableProducts()
                    queryActivePurchases()
                } else {
                    _billingState.value = _billingState.value.copy(
                        isLoading = false,
                        errorMessage = "Billing setup failed (${billingResult.debugMessage})"
                    )
                }
            }

            override fun onBillingServiceDisconnected() {
                // Try reconnecting or gracefully degrade
                _billingState.value = _billingState.value.copy(isLoading = false)
            }
        })
    }

    private fun queryAvailableProducts() {
        val productList = listOf(
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(BillingState.PRODUCT_ID_MONTHLY)
                .setProductType(BillingClient.ProductType.SUBS)
                .build(),
            QueryProductDetailsParams.Product.newBuilder()
                .setProductId(BillingState.PRODUCT_ID_YEARLY)
                .setProductType(BillingClient.ProductType.SUBS)
                .build()
        )

        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(productList)
            .build()

        billingClient.queryProductDetailsAsync(params) { billingResult, productDetailsList ->
            if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                productDetailsMap.clear()
                val plans = mutableListOf<SubscriptionPlan>()
                for (details in productDetailsList) {
                    productDetailsMap[details.productId] = details
                    val offer = details.subscriptionOfferDetails?.firstOrNull()
                    val pricingPhase = offer?.pricingPhases?.pricingPhaseList?.firstOrNull()
                    val formattedPrice = pricingPhase?.formattedPrice ?: if (details.productId == BillingState.PRODUCT_ID_MONTHLY) "$2.99 / mo" else "$19.99 / yr"
                    plans.add(
                        SubscriptionPlan(
                            productId = details.productId,
                            title = details.name,
                            description = details.description,
                            formattedPrice = formattedPrice,
                            billingPeriod = if (details.productId == BillingState.PRODUCT_ID_MONTHLY) "1 month" else "1 year"
                        )
                    )
                }
                if (plans.isNotEmpty()) {
                    _billingState.value = _billingState.value.copy(
                        availablePlans = plans,
                        isLoading = false
                    )
                } else {
                    _billingState.value = _billingState.value.copy(isLoading = false)
                }
            } else {
                _billingState.value = _billingState.value.copy(isLoading = false)
            }
        }
    }

    private fun queryActivePurchases() {
        val params = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.SUBS)
            .build()

        billingClient.queryPurchasesAsync(params) { billingResult, purchases ->
            if (billingResult.responseCode == BillingClient.BillingResponseCode.OK) {
                processPurchases(purchases)
            }
        }
    }

    override fun launchBillingFlow(activity: Activity, productId: String) {
        val details = productDetailsMap[productId]
        if (details == null) {
            _billingState.value = _billingState.value.copy(errorMessage = "Subscription plan not loaded yet")
            return
        }

        val offerToken = details.subscriptionOfferDetails?.firstOrNull()?.offerToken ?: ""
        val productDetailsParamsList = listOf(
            BillingFlowParams.ProductDetailsParams.newBuilder()
                .setProductDetails(details)
                .setOfferToken(offerToken)
                .build()
        )

        val billingFlowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(productDetailsParamsList)
            .build()

        billingClient.launchBillingFlow(activity, billingFlowParams)
    }

    override fun restorePurchases() {
        _billingState.value = _billingState.value.copy(isLoading = true, errorMessage = null)
        queryActivePurchases()
    }

    override fun onPurchasesUpdated(billingResult: BillingResult, purchases: MutableList<Purchase>?) {
        if (billingResult.responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {
            processPurchases(purchases)
        } else if (billingResult.responseCode == BillingClient.BillingResponseCode.USER_CANCELED) {
            _billingState.value = _billingState.value.copy(isLoading = false)
        } else {
            _billingState.value = _billingState.value.copy(
                isLoading = false,
                errorMessage = "Purchase error: ${billingResult.debugMessage}"
            )
        }
    }

    private fun processPurchases(purchases: List<Purchase>) {
        var isSubscribed = false
        var activeSubId: String? = null

        for (purchase in purchases) {
            if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED) {
                isSubscribed = true
                activeSubId = purchase.products.firstOrNull()

                if (!purchase.isAcknowledged) {
                    val acknowledgePurchaseParams = AcknowledgePurchaseParams.newBuilder()
                        .setPurchaseToken(purchase.purchaseToken)
                        .build()
                    coroutineScope.launch(Dispatchers.IO) {
                        billingClient.acknowledgePurchase(acknowledgePurchaseParams) { _ -> }
                    }
                }
            }
        }

        prefs.edit()
            .putBoolean("is_premium_subscribed", isSubscribed)
            .putString("active_sub_id", activeSubId)
            .apply()

        _billingState.value = _billingState.value.copy(
            isPremiumSubscribed = isSubscribed,
            activeSubscriptionId = activeSubId,
            isLoading = false
        )
    }

    override fun destroy() {
        if (billingClient.isReady) {
            billingClient.endConnection()
        }
    }
}
