# ONNX Runtime Java ve JNI siniflari
-keep class ai.onnxruntime.** { *; }
-keep interface ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# Flutter ONNX Runtime eklentisi
-keep class com.masicai.** { *; }
-dontwarn com.masicai.**

# Reflection ve JNI tarafindan kullanilan sinif bilgileri
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod