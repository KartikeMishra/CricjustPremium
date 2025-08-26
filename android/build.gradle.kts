// android/build.gradle.kts
allprojects { repositories { google(); mavenCentral() } }

tasks.register<Delete>("clean") { delete(layout.buildDirectory) }
