allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.layout.buildDirectory.set(rootProject.file("../build"))

subprojects {
    layout.buildDirectory.set(rootProject.layout.buildDirectory.dir(project.name))
}

subprojects {
    if (project.path != ":app") {
        project.evaluationDependsOn(":app")
    }

    plugins.withId("com.android.application") {
        project.extensions.configure<com.android.build.gradle.BaseExtension>("android") {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }
    plugins.withId("com.android.library") {
        project.extensions.configure<com.android.build.gradle.BaseExtension>("android") {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }
    plugins.withId("org.jetbrains.kotlin.android") {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            kotlinOptions {
                jvmTarget = "17"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
