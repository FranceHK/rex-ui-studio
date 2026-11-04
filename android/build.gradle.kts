allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Njia ya mradi ina ":" — kitenganishi cha classpath ya Java — kwa hiyo javac
// inashindwa kupata plugins. Hapo build inawekwa kwenye folda isiyo na ":"
// na build/app ya mradi inakuwa symlink ili Flutter ione APK kama kawaida.
val projectBuild = rootDir.resolve("../build").canonicalFile
val newBuildDir: Directory =
    if (projectBuild.path.contains(':')) {
        val outside = File(System.getProperty("user.home"), ".gradle/rexa-ui-studio-build")
        val app = projectBuild.resolve("app").toPath()
        outside.resolve("app").mkdirs()
        projectBuild.mkdirs()
        if (!java.nio.file.Files.isSymbolicLink(app)) {
            app.toFile().deleteRecursively()
            java.nio.file.Files.createSymbolicLink(app, outside.resolve("app").toPath())
        }
        rootProject.layout.projectDirectory.dir(outside.path)
    } else {
        rootProject.layout.buildDirectory
            .dir("../../build")
            .get()
    }
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
