android {
    compileSdkVersion 33

    defaultConfig {
        applicationId "com.example.app_ar"
        minSdkVersion 24  // Mínimo para ARCore
        targetSdkVersion 33
        versionCode 1
        versionName "1.0"

        // Agregar esto para ARCore
        ndk {
            abiFilters 'armeabi-v7a', 'arm64-v8a', 'x86', 'x86_64'
        }
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
                targetCompatibility JavaVersion.VERSION_1_8
    }

    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}

dependencies {
    implementation 'com.google.ar:core:1.39.0'
}