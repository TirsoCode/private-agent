package com.orailnoor.privateagent

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

/// Pure native (no Flutter) crash-report screen.
///
/// MainActivity redirects here on launch when a crash log exists. Created
/// deliberately WITHOUT any Flutter dependency so it always renders even if
/// the Flutter engine itself is what crashed on the previous run.
class CrashReportActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val pending = pendingReportBodies(this)
        val report = if (pending.isNotEmpty()) {
            pending.joinToString("\n=====\n")
        } else {
            // No exception file: this is the engine-abort path. Show what the
            // platform logged for our own process.
            "La app se cerró antes de terminar de abrirse (sin excepción " +
                "capturada).\n\nRegistro del proceso:\n\n" +
                captureLogTail().ifBlank { "(no se pudo leer el registro)" }
        }

        val scroll = ScrollView(this).apply {
            isFillViewport = true
            setBackgroundColor(Color.rgb(11, 15, 25))
        }

        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(24, 24, 24, 24)
        }

        val title = TextView(this).apply {
            text = "PrivateAgent — registro de error"
            setTextColor(Color.WHITE)
            textSize = 18f
            setPadding(0, 0, 0, 12)
        }

        val body = TextView(this).apply {
            text = report
            setTextColor(Color.rgb(210, 220, 235))
            textSize = 12f
            typeface = android.graphics.Typeface.MONOSPACE
            setPadding(0, 8, 0, 16)
        }

        val hint = TextView(this).apply {
            text =
                "Haz una captura de pantalla de este texto y envíalo. " +
                    "Después pulsa el botón para volver a abrir la app."
            setTextColor(Color.rgb(160, 175, 195))
            textSize = 13f
            setPadding(0, 0, 0, 16)
        }

        val button = Button(this).apply {
            text = "LIMPIAR Y REABRIR LA APP"
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.rgb(79, 70, 229))
        }

        button.setOnClickListener {
            clearLogs(this)
            startActivity(Intent(this, MainActivity::class.java))
            finish()
        }

        column.addView(title)
        column.addView(body)
        column.addView(hint)
        column.addView(button)
        scroll.addView(column)
        setContentView(scroll)
    }

    companion object {
        private fun logFiles(context: Activity): List<File> {
            val names = listOf(
                "private_agent_crash.txt",
                "private_agent_native_crash.txt",
            )
            val roots = listOfNotNull(
                context.cacheDir,
                context.filesDir,
                context.getExternalFilesDir(null),
            )
            return roots.flatMap { root -> names.map { File(root, it) } }
        }

        fun pendingReportBodies(context: Activity): List<String> {
            val seen = mutableListOf<String>()
            return logFiles(context)
                .filter { it.exists() && it.length() > 0 }
                .map { it.readText().trim() }
                .filter { it.isNotEmpty() }
                .filter { if (seen.contains(it)) false else seen.add(it) }
        }

        fun pendingReport(context: Activity): String? {
            val parts = pendingReportBodies(context)
            return if (parts.isEmpty()) null else parts.joinToString("\n\n=====\n\n")
        }

        fun clearLogs(context: Activity) {
            logFiles(context).forEach { if (it.exists()) it.delete() }
            try {
                val boot = File(context.cacheDir, "boot_marks.txt")
                if (boot.exists()) boot.delete()
            } catch (_: Throwable) {}
        }

        fun captureLogTail(): String {
            return try {
                val process = ProcessBuilder(
                    "logcat", "-d", "-t", "500",
                    "PrivateAgentCrash:*", "PrivateAgentKotlin:*", "PrivateAgentDart:*",
                    "Flutter:*", "AndroidRuntime:E", "libc:F", "DEBUG:F", "crash_dump:F", "*:S"
                ).redirectErrorStream(true).start()
                val reader = BufferedReader(InputStreamReader(process.inputStream))
                val out = StringBuilder()
                val deadline = System.currentTimeMillis() + 2500
                while (System.currentTimeMillis() < deadline) {
                    val line = reader.readLine() ?: break
                    out.append(line).append('\n')
                    if (out.length > 20000) break
                }
                try { process.destroy() } catch (_: Throwable) {}
                out.toString()
            } catch (ignored: Throwable) {
                ""
            }
        }
    }
}