plugins {
    kotlin("jvm")
    application
}

repositories {
    mavenCentral()
}

dependencies {
    implementation(project(":core:ai"))
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.9.0")
    testImplementation(kotlin("test"))
}

kotlin {
    jvmToolchain(21)
}

tasks.test {
    useJUnitPlatform()
}

application {
    mainClass.set("dev.magullodev.aiapps.tools.monitor.MonitorMainKt")
}

tasks.named<JavaExec>("run") {
    workingDir = rootProject.projectDir
}
