package com.example.number_flutter

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Required so url_launcher / app_links receive the OAuth return URL on Android.
        setIntent(intent)
    }
}
