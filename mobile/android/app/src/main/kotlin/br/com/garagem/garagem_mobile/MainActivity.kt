package br.com.garagem.garagem_mobile

import android.content.Intent
import android.content.ActivityNotFoundException
import android.provider.CalendarContract
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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "br.com.garagem.garagem_mobile/calendar",
        ).setMethodCallHandler { call, result ->
            if (call.method != "addEvent") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val title = call.argument<String>("title")?.trim().orEmpty()
            val start = call.argument<Long>("startMillis") ?: 0L
            val end = call.argument<Long>("endMillis") ?: 0L
            val location = call.argument<String>("location")?.trim().orEmpty()
            if (title.isEmpty() || start <= 0 || end <= start) {
                result.error("invalid_event", "Dados inválidos para a agenda.", null)
                return@setMethodCallHandler
            }
            val intent = Intent(Intent.ACTION_INSERT).apply {
                data = CalendarContract.Events.CONTENT_URI
                putExtra(CalendarContract.Events.TITLE, title)
                putExtra(CalendarContract.Events.EVENT_LOCATION, location)
                putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, start)
                putExtra(CalendarContract.EXTRA_EVENT_END_TIME, end)
            }
            try {
                startActivity(intent)
                result.success(null)
            } catch (_: ActivityNotFoundException) {
                result.error("calendar_unavailable", "Nenhum aplicativo de agenda disponível.", null)
            }
        }
    }
}
