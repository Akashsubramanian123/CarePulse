package com.carepulse.carepulse

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    companion object {
        init {
            try { System.loadLibrary("ggml") } catch (_: Throwable) {}
            try { System.loadLibrary("llama") } catch (_: Throwable) {}
            try { System.loadLibrary("mtmd") } catch (_: Throwable) {}
        }
    }
}
