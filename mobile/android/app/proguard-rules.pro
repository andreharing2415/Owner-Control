# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.embedding.**

# Keep app_links plugin
-keep class com.llfbandit.app_links.** { *; }

# Keep Kotlin metadata
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# Keep AndroidX
-keep class androidx.** { *; }
-dontwarn androidx.**

# Keep Google Play Core (used by some plugins)
-dontwarn com.google.android.play.core.**

# Prevent stripping of annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
