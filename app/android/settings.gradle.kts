pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// These are the versions the Flutter 3.50 Android template ships. Flutter's
// tooling refuses to build below Gradle 9.3.1, AGP 9.1.1 and KGP 2.4.10, and
// CI follows the stable channel, so keep this trio on the template values
// (Gradle 9.5.0 in gradle/wrapper/gradle-wrapper.properties).
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.3.1" apply false
    id("org.jetbrains.kotlin.android") version "2.4.20" apply false
    id("com.google.gms.google-services") version "4.4.4" apply false
}

include(":app")
