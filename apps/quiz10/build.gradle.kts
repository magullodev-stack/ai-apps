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
    testImplementation(kotlin("test"))
}

kotlin {
    jvmToolchain(21)
}

tasks.test {
    useJUnitPlatform()
}

tasks.jar {
    archiveBaseName.set("quiz10-app")
}

application {
    mainClass.set("dev.magullodev.quiz10.apps.quiz10.MainKt")
}
