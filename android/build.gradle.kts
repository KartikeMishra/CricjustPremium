buildscript {
    repositories {
        google()            // Required for Firebase
        mavenCentral()      // Recommended
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.4.0") // Match your gradle version
        classpath("com.google.gms:google-services:4.3.15") // Firebase plugin
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Optional: Custom build directory (keep if needed)
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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
