package br.com.garagem.garagem_mobile

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "br.com.garagem.garagem_mobile/share",
        ).setMethodCallHandler { call, result ->
            if (call.method != "shareText") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val title = call.argument<String>("title")?.trim().orEmpty()
            val text = call.argument<String>("text")?.trim().orEmpty()
            if (text.isEmpty()) {
                result.error("invalid_share", "O texto não pode estar vazio.", null)
                return@setMethodCallHandler
            }

            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
                if (title.isNotEmpty()) putExtra(Intent.EXTRA_TITLE, title)
            }
            startActivity(Intent.createChooser(shareIntent, title.ifEmpty {
                "Compartilhar com"
            }))
            result.success(null)
        }
    }
}
