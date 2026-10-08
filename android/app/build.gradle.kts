plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.finacc.mobile"
    compileSdk = flutter.compileSdkVersion
    // التطبيق Dart خالص بلا كود أصلي — NDK غير مستخدم فعلياً؛ وجود هذا السطر مع
    // علامة الوهم في ANDROID_HOME/ndk يمنع flutter-gradle-plugin من تنزيل NDK (~4GB)
    // على قرص محدود (الإضافة تفرض التنزيل إن لم يجد الإصدار "مثبتاً").
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // معرّف التطبيق الفريد (قابل للتغيير قبل أي نشر على المتاجر — قرر مع المالك حينها)
        applicationId = "app.finacc.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // توقيع بمفاتيح debug مؤقتاً لأول APK تجريبي — إنشاء keystore إنتاجي قرارٌ مع المالك قبل النشر
            signingConfig = signingConfigs.getByName("debug")
            // جداول رموز الأصناف الأصلية لرصد الأعطال ميزة نشرٍ على Play — تُعطّل هنا
            // (حزمة تجريبية أصغر + مهمة extractNativeSymbolTables بلا objcopy).
            ndk {
                debugSymbolLevel = "none"
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
