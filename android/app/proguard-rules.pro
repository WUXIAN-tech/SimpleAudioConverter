# FFmpegKit rules (Release 构建必需，缺少会导致 JNI 错误)
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-dontwarn com.antonkarpenko.ffmpegkit.**

-keep class com.antonkarpenko.ffmpegkit.FFmpegKitConfig { *; }
-keep class com.antonkarpenko.ffmpegkit.AbiDetect { *; }
-keep class com.antonkarpenko.ffmpegkit.*Session { *; }
-keep class com.antonkarpenko.ffmpegkit.*Callback { *; }
-keep public class com.antonkarpenko.ffmpegkit.** { public *; }

# 保留所有 native 方法（否则 JNI_OnLoad 返回 0 导致黑屏）
-keepclasseswithmembernames class * {
    native <methods>;
}

-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
