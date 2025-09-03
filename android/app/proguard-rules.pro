# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# Play Core rules
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Firebase rules
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable classes
-keep class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator *;
}

# Keep Serializable classes
-keepnames class * implements java.io.Serializable

# Keep WebView
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep audio/video related classes
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media.** { *; }

# Keep chart related classes
-keep class com.github.mikephil.charting.** { *; }

# Keep Hive database
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }
-keep class * implements androidx.sqlite.db.SupportSQLiteOpenHelper { *; }

# General optimization
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification 