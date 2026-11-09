# ONNX Runtime (smarter search) is called through JNI: keep its classes.
-keep class ai.onnxruntime.** { *; }

# Text recognition uses only the Latin script model; the plugin also
# names the other scripts' options, which are not bundled.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
