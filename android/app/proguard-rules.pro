# flutter_onnxruntime - Keep JNI native methods and classes
-keep class ai.onnxruntime.** { *; }
-keep class com.microsoft.onnxruntime.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep flutter_onnxruntime plugin classes
-keep class com.example.flutter_onnxruntime.** { *; }

# Keep all JNI-loaded native libraries
-keep class * {
    native <methods>;
}

# Keep generic signatures for JSON serialization
-keepattributes Signature
-keepattributes *Annotation*

# Flutter engine - Keep references needed by the engine
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
