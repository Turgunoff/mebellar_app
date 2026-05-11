package com.mebellar.app

import android.app.Application

// Yandex MapKit was previously initialized here at app boot, which caused
// MapKit's native runtime to start a LocationSubscription before the user
// had granted ACCESS_FINE_LOCATION — flooding logcat with SecurityExceptions
// on cold start. Initialization is now deferred to MainActivity's
// "yandex_mapkit/init" MethodChannel, which the Dart side calls only when
// the map screen is about to open (and after requesting location permission).
class MainApplication : Application()
