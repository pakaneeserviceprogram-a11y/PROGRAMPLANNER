allprojects {
    repositories {
        google()
        // DNS ของบางเครือข่ายแก้ชื่อ repo.maven.apache.org ไม่ได้ ทำให้ build ล้มตอนโหลด
        // dependency — ใส่ mirror ของ Maven Central ที่ Google โฮสต์ไว้เป็นตัวแรก แล้วค่อยถอยไปใช้ตัวจริง
        maven { url = uri("https://maven-central.storage-download.googleapis.com/maven2/") }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
