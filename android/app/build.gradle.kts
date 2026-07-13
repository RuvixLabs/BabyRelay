val releaseSigningRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val releaseStoreFile = System.getenv("BABYRELAY_UPLOAD_STORE_FILE")
val releaseStorePassword = System.getenv("BABYRELAY_UPLOAD_STORE_PASSWORD")
val releaseKeyAlias = System.getenv("BABYRELAY_UPLOAD_KEY_ALIAS")
val releaseKeyPassword = System.getenv("BABYRELAY_UPLOAD_KEY_PASSWORD")

if (
    releaseSigningRequested &&
    listOf(
        releaseStoreFile,
        releaseStorePassword,
        releaseKeyAlias,
        releaseKeyPassword,
    ).any { it.isNullOrBlank() }
) {
    throw GradleException(
        "Release signing requires the BabyRelay upload-keystore environment variables.",
    )
}

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ruvixlabs.babyrelay"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.ruvixlabs.babyrelay"
        multiDexEnabled = true
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (!releaseStoreFile.isNullOrBlank()) {
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storeFile = file(releaseStoreFile)
                storePassword = releaseStorePassword
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.window:window:1.0.0")
    implementation("androidx.window:window-java:1.0.0")
}
