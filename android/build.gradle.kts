// Force all subprojects to use mavenCentral instead of jcenter
gradle.projectsLoaded {
    rootProject.allprojects {
        buildscript.repositories.removeIf { 
            it is MavenArtifactRepository && it.url.toString().contains("jcenter")
        }
        buildscript.repositories {
            google()
            mavenCentral()
        }
        
        repositories.removeIf { 
            it is MavenArtifactRepository && it.url.toString().contains("jcenter")
        }
        repositories {
            google()
            mavenCentral()
        }
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    // Override jcenter() in all subprojects to use mavenCentral() instead
    buildscript.repositories {
        google()
        mavenCentral()
    }
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
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
