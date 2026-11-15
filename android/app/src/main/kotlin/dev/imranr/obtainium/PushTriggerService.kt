package dev.imranr.obtainium

import io.flutter.embedding.engine.FlutterEngine
import org.unifiedpush.flutter.connector.Plugin
import org.unifiedpush.flutter.connector.UnifiedPushService

class PushTriggerService : UnifiedPushService() {
    override fun onCreate() {
        if (Plugin.calls.subscriptionCount.value == 0) {
            backgroundEngine?.destroy()
            val engine = getEngine(this)
            if (engine.plugins.get(Plugin::class.java) == null) {
                engine.plugins.add(Plugin())
            }
            backgroundEngine = engine
        }
        super.onCreate()
    }

    companion object {
        private var backgroundEngine: FlutterEngine? = null
    }
}
