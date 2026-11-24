# The receipt scanner uses ML Kit's default Latin recognizer. The plugin also
# references these optional script recognizers, which are not included in this
# app. Keep R8 from treating those unused optional classes as release errors.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
