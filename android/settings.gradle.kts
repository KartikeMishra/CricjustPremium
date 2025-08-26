// android/settings.gradle.kts  — import-free & Kotlin-DSL safe

pluginManagement {
    // Read flutter.sdk from local.properties
    val flutterSdkPath = run {
        val props = java.util.Properties().apply {
            val lp = file("local.properties")
            if (lp.exists()) lp.inputStream().use { this.load(it) }
        }
        props.getProperty("flutter.sdk")
            ?: throw GradleException("flutter.sdk not set in local.properties")
    }

    // Make Flutter’s Gradle tooling available
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"

    // Choose ONE of these combos across your project:
    // ✅ Stable & Flutter-safe:
    id("com.android.application") version "8.12.1" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false

    // If you later switch to Kotlin 2.x, update these here AND in gradle wrapper/JDK:
    // id("com.android.application") version "8.6.0" apply false
    // id("org.jetbrains.kotlin.android") version "2.0.21" apply false
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        // Needed for some Flutter artifacts
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
    }
}

include(":app")
