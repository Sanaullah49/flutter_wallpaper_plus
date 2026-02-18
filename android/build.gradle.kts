plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.flutterwallpaperplus"
    compileSdk = 36

    defaultConfig {
        minSdk = 24
        // No need for targetSdk in a library plugin

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        consumerProguardFiles("proguard-rules.pro")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Suppress lint errors that shouldn't block plugin compilation
    lint {
        disable += "InvalidPackage"
        disable += "GradleDependency"
    }
}

dependencies {
    // AndroidX Core KTX
    implementation("androidx.core:core-ktx:1.17.0")

    // Lifecycle for service management
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.10.0")
    implementation("androidx.lifecycle:lifecycle-service:2.10.0")

    // Media3 ExoPlayer for video wallpaper playback
    implementation("androidx.media3:media3-exoplayer:1.9.2")
    implementation("androidx.media3:media3-common:1.9.2")

    // Kotlin Coroutines for async operations
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")

    // OkHttp for reliable HTTP downloads
    implementation("com.squareup.okhttp3:okhttp:5.3.2")

    // Testing
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
}