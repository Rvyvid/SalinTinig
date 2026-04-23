# Keep ML Kit Text Recognition classes
-keep class com.google.mlkit.vision.text.** { *; }

# Ignore optional language-specific ML Kit classes if they're not included
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep ML Kit common classes
-keep class com.google_mlkit_commons.** { *; }

# Keep all Flutter plugins
-keep class io.flutter.plugin.** { *; }

# Keep core Android classes
-keepclasseswithmembernames class * {
    native <methods>;
}
