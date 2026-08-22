# Still ProGuard / R8 rules

# Retain Room annotations and classes
-keep class * extends androidx.room.RoomDatabase
-dontwarn androidx.room.paging.**

# Retain domain models
-keep class com.originark.still.data.model.** { *; }

# Retain Google Play Billing
-keep class com.android.billingclient.api.** { *; }

# Retain Coroutines & Flow
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
-dontwarn com.google.errorprone.annotations.**
