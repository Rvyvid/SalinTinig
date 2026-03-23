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

// Temporary workaround: for older plugins that don't declare a namespace
// (e.g., some versions in the pub cache), assign a default namespace so
// the Android Gradle Plugin configuration step doesn't fail.
subprojects {
    plugins.withId("com.android.library") {
        try {
            val androidExt = extensions.findByName("android")
            if (androidExt is com.android.build.gradle.LibraryExtension) {
                if (androidExt.namespace.isNullOrEmpty()) {
                    // NOTE: This is a fallback namespace. For long-term stability,
                    // prefer patching the plugin or using a maintained replacement.
                    androidExt.namespace = "com.example.flutter_bluetooth_serial"
                }
            }
        } catch (e: Exception) {
            // ignore; this is a best-effort workaround
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
