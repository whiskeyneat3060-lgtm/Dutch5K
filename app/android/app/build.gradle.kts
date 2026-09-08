plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Reads android/app/google-services.json, written by `flutterfire configure`.
    id("com.google.gms.google-services")
}

android {
    namespace = "com.dutchtogo.dutch_to_go"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // flutter_local_notifications uses java.time on older API levels.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.dutchtogo.dutch_to_go"
        // Firebase Auth requires 23; Play Billing and the notification APIs are
        // all available from there.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            // Populated from android/key.properties, which is gitignored.
            // See README.md, section "Release signing".
            val props = java.util.Properties()
            val propsFile = rootProject.file("key.properties")
            if (propsFile.exists()) {
                props.load(propsFile.inputStream())
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
                storeFile = props.getProperty("storeFile")?.let { file(it) }
                storePassword = props.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Falls back to debug keys when key.properties is absent so a
            // fresh clone can still run in release mode locally.
            signingConfig = if (rootProject.file("key.properties").exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
