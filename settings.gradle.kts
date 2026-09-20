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
include(":systems:games:quiz10")
include(":apps:quiz10")
include(":ui:quiz10-web")
include(":apps:quiz10-web")
include(":tools:monit-ai")
