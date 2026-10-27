# ==================== tencent_chat_uikit consumer ProGuard rules ====================
# These rules are embedded into the consumer app's R8/ProGuard run.
# Reason: chat/uikit registers custom Views via fully-qualified class names in
# res-video-recorder/layout/*.xml (RecordButtonView, ProgressRingView, BeautyStrengthSeekBar,
# BeautyHorizontalScrollView, TransformLayout). Android inflates these by reflection,
# so the classes must survive R8.

# Keep all classes & members in this plugin's package.
-keep class com.tencent.cloud.tuikit.flutter.tuichatkit.** { *; }
-keepclassmembers class com.tencent.cloud.tuikit.flutter.tuichatkit.** { *; }

# Reflection / attribute support.
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Kotlin metadata (used by reflection).
-keep class kotlin.Metadata { *; }
-keepclassmembers class **$WhenMappings {
    <fields>;
}

# Parcelable.
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

# Serializable.
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
