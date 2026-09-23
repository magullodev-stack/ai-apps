plugins {
    kotlin("jvm")
    `java-library`
    application
}

application {
    mainClass.set("dev.magullodev.aiapps.ai.AiHttpServer")
}

repositories {
    mavenCentral()
}

dependencies {
    api(project(":ai:core:contracts"))
    api(project(":ai:core:config"))
    api(project(":ai:core:network"))
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.9.0")
    testImplementation(kotlin("test"))
}

kotlin {
    jvmToolchain(21)
}

tasks.test {
    useJUnitPlatform()
}
