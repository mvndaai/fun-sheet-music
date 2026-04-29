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
    project.evaluationDependsOn(":app")
    
    afterEvaluate {
        if (project.hasProperty("android")) {
            project.extensions.configure<com.android.build.gradle.BaseExtension>("android") {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
        if (project.plugins.hasPlugin("org.jetbrains.kotlin.android")) {
            project.extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinJvmOptions>("kotlinOptions") {
                jvmTarget = "17"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
