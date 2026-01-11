plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.petWalkShare"

    // [1] 컴파일 버전을 34로 고정 (기존: flutter.compileSdkVersion)
    compileSdk = 36

    signingConfigs {
        create("release") {
            // 키스토어 파일이 android/app 폴더에 있으므로 파일명만 적으면 됩니다.
            storeFile = file("upload-keystore.jks")

            storePassword = "123456"
            keyAlias = "upload"
            keyPassword = "123456"
        }
    }

    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.petWalkShare"

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
        getByName("release") {
            // 2. release 빌드 시 위에서 만든 'release' 서명을 사용하도록 변경
            signingConfig = signingConfigs.getByName("release")

            isMinifyEnabled = false // 필요 시 true로 변경 (코드 난독화)
            isShrinkResources = false

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// ▼ [추가] 파일 맨 아래에 dependencies 블록을 추가하여 디슈가링 라이브러리를 지정합니다.
dependencies {
    // 1. 구형 안드로이드 지원 라이브러리 (기존 유지)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")

    // 2. Firebase BoM (버전 관리 도구) 추가 [이미지 가이드 반영]
    implementation(platform("com.google.firebase:firebase-bom:34.7.0"))

    // 3. Firebase Analytics 및 필요한 라이브러리 추가 [이미지 가이드 반영]
    implementation("com.google.firebase:firebase-analytics")

    // 💡 Safe Care에 꼭 필요한 추가 라이브러리
    implementation("com.google.firebase:firebase-auth")     // 로그인용
    implementation("com.google.firebase:firebase-firestore") // 데이터베이스용
}
