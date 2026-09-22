plugins {
    kotlin("jvm")
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

    sourceSets {
        main {
            kotlin.srcDir("modalidades/random/test")
            kotlin.exclude("**/*Test.kt")
        }
        test {
            kotlin.srcDir("modalidades/random/test")
            kotlin.exclude { element ->
                element.file.isFile &&
                    element.file.toPath().startsWith(file("modalidades/random/test").toPath()) &&
                    !element.file.name.endsWith("Test.kt")
            }
        }
    }
}

tasks.test {
    useJUnitPlatform()
}
