plugins {
    kotlin("jvm")
    application
}

repositories {
    mavenCentral()
}

dependencies {
    implementation(project(":core:config"))
    implementation(project(":core:network"))
    implementation(project(":core:ai"))
    implementation(project(":systems:quiz10"))
    implementation(project(":ui:quiz10-web"))
    testImplementation(kotlin("test"))
}

kotlin {
    jvmToolchain(21)
}

tasks.test {
    useJUnitPlatform()
}

application {
    mainClass.set("dev.magullodev.quiz10.apps.quiz10.web.WebMainKt")
}
