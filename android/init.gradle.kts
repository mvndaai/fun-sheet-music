// This init script replaces all jcenter() repository declarations with mavenCentral()
// because jcenter() has been shut down and is no longer available.
// This fixes build errors from plugins that still reference jcenter().

settingsEvaluated {
    pluginManagement {
        repositories {
            gradlePluginPortal()
            google()
            mavenCentral()
        }
    }
}

beforeSettings {
    buildscript.repositories.forEach { repository ->
        when (repository) {
            is MavenArtifactRepository -> {
                if (repository.url.toString().contains("jcenter")) {
                    remove(repository)
                }
            }
        }
    }
}

allprojects {
    buildscript.repositories.configureEach {
        if (this is MavenArtifactRepository && url.toString().contains("jcenter")) {
            project.logger.lifecycle("Removing jcenter() from buildscript repositories in ${project.name}")
            // Gradle will skip this repository
        }
    }
    
    repositories.configureEach {
        if (this is MavenArtifactRepository && url.toString().contains("jcenter")) {
            project.logger.lifecycle("Removing jcenter() from repositories in ${project.name}")
            // Gradle will skip this repository
        }
    }
    
    afterEvaluate {
        buildscript.repositories {
            removeIf { 
                it is MavenArtifactRepository && it.url.toString().contains("jcenter")
            }
            // Ensure we have mavenCentral as a fallback
            if (none { it is MavenArtifactRepository && it.url.toString().contains("maven2") }) {
                mavenCentral()
            }
        }
        
        repositories {
            removeIf { 
                it is MavenArtifactRepository && it.url.toString().contains("jcenter")
            }
            // Ensure we have mavenCentral as a fallback
            if (none { it is MavenArtifactRepository && it.url.toString().contains("maven2") }) {
                mavenCentral()
            }
        }
    }
}
