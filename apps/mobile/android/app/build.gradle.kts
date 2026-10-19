import java.util.Properties

// A build installed beside the real app, see `applicationId` below.
val isCandidate = project.findProperty("candidate") == "true"

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is driven by android/key.properties, which is gitignored and
// points at the upload keystore. There is deliberately no fallback: a release
// signed with the debug key is rejected by Play only at upload time.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.isFile) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

fun requiredKeystoreProperty(name: String): String {
    val value = keystoreProperties.getProperty(name)
    require(!value.isNullOrBlank()) {
        "${keystorePropertiesFile.absolutePath} is missing the '$name' entry."
    }
    return value
}

gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any {
        it.project == project && (it.name == "assembleRelease" || it.name == "bundleRelease")
    }
    if (buildsRelease && !keystorePropertiesFile.isFile) {
        throw GradleException(
            "Release builds need the upload keystore, but " +
                "${keystorePropertiesFile.absolutePath} does not exist. Create it with " +
                "storeFile, storePassword, keyAlias and keyPassword.",
        )
    }
}

android {
    namespace = "com.nkshub.nextcloudnotes"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // `-Pcandidate=true` builds the same app under its own package, so a
        // build under test installs beside the one somebody actually uses.
        applicationId = if (isCandidate) {
            "com.nkshub.nextcloudnotes.candidate"
        } else {
            "com.nkshub.nextcloudnotes"
        }
        manifestPlaceholders["appLabel"] = if (isCandidate) "OwnNotes Candidate" else "OwnNotes"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.isFile) {
                storeFile = rootProject.file(requiredKeystoreProperty("storeFile"))
                storePassword = requiredKeystoreProperty("storePassword")
                keyAlias = requiredKeystoreProperty("keyAlias")
                keyPassword = requiredKeystoreProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
