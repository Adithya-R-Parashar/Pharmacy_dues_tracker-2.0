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

subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        val javaTaskName = name.replace("Kotlin", "JavaWithJavac")
        val javaTask = project.tasks.findByName(javaTaskName) as? JavaCompile
        if (javaTask != null) {
            val targetStr = javaTask.targetCompatibility
            val jvmTargetVal = when (targetStr) {
                "1.8" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
                "11" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
                "17" -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                else -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
            }
            compilerOptions {
                jvmTarget.set(jvmTargetVal)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
