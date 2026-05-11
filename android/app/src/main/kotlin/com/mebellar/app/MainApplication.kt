package com.mebellar.app

import android.app.Application

// Yandex MapKit API key is set in MainActivity.configureFlutterEngine()
// before super() so that YandexMapkitPlugin.onAttachedToEngine() can call
// MapKitFactory.initialize() successfully. setApiKey() is a static-string
// write and does NOT start any LocationSubscription.
class MainApplication : Application()
