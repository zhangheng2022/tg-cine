import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val telegramDefinitions = providers.gradleProperty("dart-defines").orNull.orEmpty()
    .split(',').filter { it.isNotBlank() }.associate {
        val definition = String(Base64.getDecoder().decode(it), Charsets.UTF_8)
        definition.substringBefore('=') to definition.substringAfter('=', "")
    }
val publicTelegramConfigured = listOf("TG_CINE_API_ID", "TG_CINE_API_HASH")
    .any { !telegramDefinitions[it].isNullOrEmpty() }

android {
    namespace = "io.tgcine.tg_cine"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "io.tgcine.tg_cine"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        if (publicTelegramConfigured) {
            ndk { abiFilters += setOf("arm64-v8a", "x86_64") }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

gradle.taskGraph.whenReady {
    if (publicTelegramConfigured) {
        if (listOf("TG_CINE_API_ID", "TG_CINE_API_HASH").any { telegramDefinitions[it].isNullOrEmpty() }) {
            throw GradleException("Telegram application configuration is incomplete.")
        }
        for (abi in listOf("arm64-v8a", "x86_64")) {
            if (!file("src/main/jniLibs/$abi/libtdjson.so").isFile) {
                throw GradleException("Telegram requires the verified TDLib native library for $abi. Run the mobile native build and installer first.")
            }
        }
    }
    val publicBuild = allTasks.any { it.name.contains("Release") || it.name.contains("Profile") }
    val privateConfiguration = telegramDefinitions.any { (key, value) ->
        key in setOf("TG_CINE_TELEGRAM_CONFIG", "TG_CINE_TELEGRAM_MOBILE_CONFIG") && value.isNotEmpty()
    }
    if (publicBuild && privateConfiguration) {
        throw GradleException("Private Telegram configuration is allowed only in Debug builds.")
    }
}
