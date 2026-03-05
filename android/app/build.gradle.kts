import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 读取签名配置
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("local.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "org.hein.heintv"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    // 添加正式签名配置
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["key.alias"] as String
            keyPassword = keystoreProperties["key.alias.password"] as String
            storeFile = file(keystoreProperties["key.store"] as String)
            storePassword = keystoreProperties["key.store.password"] as String
        }
    }

    defaultConfig {
        // Specify unique Application ID
        applicationId = "org.hein.heintv.tv"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // 使用正式签名配置
            signingConfig = signingConfigs["release"]
            
            // Enable R8 code shrinking, obfuscation, and optimization
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        
        debug {
            // Keep debug builds fast
            isMinifyEnabled = false
        }
    }
}

flutter {
    source = "../.."
}
