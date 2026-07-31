import com.android.build.gradle.BaseExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // The app module configures its own compileSdk directly, so it's
    // entirely excluded from this block (calling afterEvaluate on it here
    // would fail since it's already evaluated by the time this runs).
    if (project.name != "app") {
        project.evaluationDependsOn(":app")

        // Force every plugin (e.g. agora_rtc_engine) to compile against the
        // same newer Android SDK level as the app itself.
        afterEvaluate {
            if (extensions.findByName("android") != null) {
                extensions.configure<BaseExtension> {
                    compileSdkVersion(36)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}