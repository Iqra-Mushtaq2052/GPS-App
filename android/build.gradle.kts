allprojects {
    repositories {
        google()
        mavenCentral()
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

// Some plugins (e.g. geofence_foreground_service) still pin an old
// compileSdk in their own module's build.gradle, which conflicts with
// newer androidx transitive dependencies. Force every Android library
// subproject to compile against the same SDK level as the app, applied
// *after* that subproject's own script (and its own compileSdk line) has
// run, regardless of project-evaluation order.
subprojects {
    val overrideCompileSdk: () -> Unit = {
        extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.let { it.compileSdk = 37 }
    }
    if (state.executed) {
        overrideCompileSdk()
    } else {
        afterEvaluate { overrideCompileSdk() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
