pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val sdkPath = properties.getProperty("flutter.sdk")
        checkNotNull(sdkPath) { "flutter.sdk not set in local.properties" }
        sdkPath
    }
    settings.extra["flutterSdkPath"] = flutterSdkPath

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// This configuration prevents jcenter() errors from old plugins
gradle.settingsEvaluated {
    pluginManagement.repositories.removeIf { 
        it is MavenArtifactRepository && it.url.toString().contains("jcenter")
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
