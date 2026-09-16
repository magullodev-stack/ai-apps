pluginManagement {
    repositories {
        gradlePluginPortal()
    }
}

rootProject.name = "ai-apps"

include(":core:contracts")
include(":core:config")
include(":core:network")
include(":core:ai")
include(":systems:quiz10")
include(":apps:quiz10")
