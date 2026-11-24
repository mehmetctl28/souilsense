import com.android.build.api.variant.LibraryAndroidComponentsExtension

plugins {
    id("com.android.application") apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

// These FlutterFire modules use API 33, but their dependencies require API 34.
val firebasePluginsRequiringApi34 = setOf("firebase_auth", "firebase_messaging", "firebase_storage")
configure(subprojects.filter { it.name in firebasePluginsRequiringApi34 }) {
    pluginManager.withPlugin("com.android.library") {
        extensions.configure<LibraryAndroidComponentsExtension> {
            finalizeDsl { android ->
                if ((android.compileSdk ?: 0) < 34) {
                    android.compileSdk = 34
                }
            }
        }
    }
}

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
