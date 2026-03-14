import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

// Disable ART profile tasks (Fix: optimizeReleaseArtProfile error)
gradle.startParameter.excludedTaskNames.addAll(
    listOf(
        ":app:compileReleaseArtProfile",
        ":app:mergeReleaseArtProfile",
    )
)

android {
    namespace = "com.lwv.bridalbookermachine"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.lwv.bridalbookermachine"
        minSdk = 23
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Firebase auto init enable only for messaging
        manifestPlaceholders["firebaseMessagingAutoInitEnabled"] = "true"

        // Disable Firebase Analytics + AD ID collection
        manifestPlaceholders.putAll(
            mapOf(
                "google_analytics_adid_collection_enabled" to "false",
                "firebase_analytics_collection_enabled" to "false"
            )
        )
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        create("release") {
            storeFile = file(keystoreProperties["storeFile"] ?: "")
            storePassword = keystoreProperties["storePassword"] as String? ?: ""
            keyAlias = keystoreProperties["keyAlias"] as String? ?: ""
            keyPassword = keystoreProperties["keyPassword"] as String? ?: ""
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            signingConfig = signingConfigs.getByName("release")
        }
    }

    testOptions {
        experimentalProperties["android.experimental.art-profile-r8-rewriting"] = false
    }

    buildFeatures {
        buildConfig = true
    }

    packaging {
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/license.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/notice.txt",
                "META-INF/ASL2.0"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Firebase BOM
    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))

    // Messaging (required ktx for Flutter)
    implementation("com.google.firebase:firebase-messaging")

    // Analytics (disable AD-ID later)
    implementation("com.google.firebase:firebase-analytics")

    // Import the BoM for the Firebase platform
    implementation(platform("com.google.firebase:firebase-bom:34.9.0"))

    // Add the dependency for the Firebase Authentication library
    
    implementation("com.google.firebase:firebase-auth")

    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")
    implementation("androidx.core:core-ktx:1.13.1")

    implementation("com.facebook.android:facebook-android-sdk:[8,9)")

    debugImplementation("androidx.profileinstaller:profileinstaller:1.3.1")
}

