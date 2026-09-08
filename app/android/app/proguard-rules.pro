# Play Core is referenced by Flutter's deferred-components support, which this
# app does not use. Without these rules R8 fails the release build on missing
# classes rather than simply dropping them.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# flutter_local_notifications serialises its scheduled-notification models with
# Gson, so their fields must survive shrinking.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
