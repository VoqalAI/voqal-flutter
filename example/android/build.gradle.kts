allprojects {
    repositories {
        mavenLocal() // local-test convenience; customers use the raw.githubusercontent repo below
        google()
        mavenCentral()
        // Voqal native Android SDK distribution (public, no auth). A Flutter
        // plugin cannot contribute repositories to the host app, so any app that
        // uses voqal_flutter must add this repo here (or in settings.gradle.kts
        // dependencyResolutionManagement).
        maven { url = uri("https://raw.githubusercontent.com/VoqalAI/voqal-android-maven/main") }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

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
