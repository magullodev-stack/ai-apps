pluginManagement {
    repositories {
        gradlePluginPortal()
    }
}

rootProject.name = "quiz10"

include(":core:contracts")
include(":core:config")
include(":core:network")
include(":core:ai")
include(":systems:quiz10")

project(":core").projectDir = file("A/core")
project(":core:contracts").projectDir = file("A/core/contracts")
project(":core:config").projectDir = file("A/core/config")
project(":core:network").projectDir = file("A/core/network")
project(":core:ai").projectDir = file("A/core/ai")
project(":systems").projectDir = file("B/systems")
project(":systems:quiz10").projectDir = file("B/systems/quiz10")
