plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin") // keep after the two above
}

android {
    namespace = "com.cricjust.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.cricjust.app"
        minSdk = flutter.minSdkVersion
        //noinspection OldTargetApi
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    signingConfigs {
        create("release") {
            // change if your keystore lives elsewhere
            storeFile = file("$projectDir/cricjust.jks")
            storePassword = "cricjust"
            keyAlias = "cricjust"
            keyPassword = "cricjust"
        }
    }
    splits {
        abi {
            isEnable = true
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
            isUniversalApk = false
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "/META-INF/{AL2.0,LGPL2.1}",
                "META-INF/DEPENDENCIES","META-INF/LICENSE","META-INF/LICENSE.txt",
                "META-INF/license.txt","META-INF/NOTICE","META-INF/NOTICE.txt",
                "META-INF/notice.txt","META-INF/INDEX.LIST"
            )
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true        // ✅ first build: keep false
            isShrinkResources = true      // ✅ first build: keep false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            // nothing special
        }
    }
}
