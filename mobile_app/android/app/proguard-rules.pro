# flutter_gemma / MediaPipe keep rules
-keep class com.google.mediapipe.** { *; }
-keep class com.google.mediapipe.proto.** { *; }
-dontwarn com.google.mediapipe.proto.**

# AutoValue annotation processor (pulled in by MediaPipe)
-dontwarn javax.annotation.processing.**
-dontwarn javax.lang.model.**
-dontwarn com.google.auto.value.**

# Keep Flutter plugin classes
-keep class dev.flutterberlin.flutter_gemma.** { *; }
-keep class io.flutter.** { *; }

# Flutter Play Core (deferred components — not used, suppress R8 warnings)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# General rules
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
