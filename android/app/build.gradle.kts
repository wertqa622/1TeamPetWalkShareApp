plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.untitled1"

    // [1] 컴파일 버전을 34로 고정 (기존: flutter.compileSdkVersion)
    compileSdk = 36

    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.untitled1"

        // [2] 최소 버전을 21로 고정 (기존: flutter.minSdkVersion)
        minSdk = flutter.minSdkVersion

        // [3] 타겟 버전을 34로 고정 (기존: flutter.targetSdkVersion)
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // [추가] 메서드 개수 제한 에러를 방지하기 위해 설정
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// ▼ [추가] 파일 맨 아래에 dependencies 블록을 추가하여 디슈가링 라이브러리를 지정합니다.
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}
