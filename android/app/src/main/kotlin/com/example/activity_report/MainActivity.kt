package com.example.activity_report

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

@Suppress("DEPRECATION")
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "activity_report/usage"
        private const val DAYS = 7

        // Hidden (non-SDK) UsageEvents type. Best effort only, see README.
        private const val NOTIFICATION_INTERRUPTION = 12

        // Two foreground events closer than this count as one "open"
        // (switching activities inside the same app is not a new open).
        private const val OPEN_GAP_MS = 5_000L

        // SCREEN_NON_INTERACTIVE (16), KEYGUARD_SHOWN (17), DEVICE_SHUTDOWN (26).
        // Plain ints so older devices, which never emit them, need no API check.
        private val SESSION_END_EVENTS = setOf(16, 17, 26)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> result.success(hasUsageAccess())
                    "openPermissionSettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(null)
                    }
                    "getWeeklyReport" -> Thread {
                        try {
                            val report = buildWeeklyReport()
                            runOnUiThread { result.success(report) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("REPORT_FAILED", e.message, null) }
                        }
                    }.start()
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName
            )
        } else {
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun buildWeeklyReport(): Map<String, Any?> {
        val pm = packageManager
        val now = System.currentTimeMillis()

        // Day boundaries in local time: dayStarts[0] = midnight 6 days ago,
        // dayStarts[7] = midnight tonight (exclusive end of the last day).
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            add(Calendar.DAY_OF_YEAR, -(DAYS - 1))
        }
        val dayStarts = LongArray(DAYS + 1)
        for (i in 0..DAYS) {
            dayStarts[i] = cal.timeInMillis
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        val weekStart = dayStarts[0]

        fun isLaunchable(pkg: String) =
            pkg != packageName && pm.getLaunchIntentForPackage(pkg) != null

        fun labelOf(pkg: String): String = try {
            pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
        } catch (e: Exception) {
            pkg
        }

        // ---- 1. Walk the usage events once -------------------------------
        val daily = HashMap<String, LongArray>()
        val opens = HashMap<String, Int>()
        val notifs = HashMap<String, Int>()
        val unlocks = IntArray(DAYS)
        val unlocksAvailable = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
        val lastBackground = HashMap<String, Long>()

        // Only one app is on screen at a time, so we track ONE open session.
        // A missing background event (process killed, screen off) would
        // otherwise leave a session open for days and push a day past 24h.
        var currentPkg: String? = null
        var currentSince = 0L

        fun addInterval(pkg: String, from: Long, to: Long) {
            val arr = daily.getOrPut(pkg) { LongArray(DAYS) }
            for (d in 0 until DAYS) {
                val s = maxOf(from, dayStarts[d])
                val e = minOf(to, dayStarts[d + 1])
                if (e > s) arr[d] += e - s // splits sessions across midnight
            }
        }

        fun closeSession(pkg: String, at: Long) {
            addInterval(pkg, currentSince, at)
            lastBackground[pkg] = at
        }

        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(weekStart, now)
        val ev = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(ev)
            // Unlocks are device-level events (public API since Android 9).
            if (unlocksAvailable && ev.eventType == UsageEvents.Event.KEYGUARD_HIDDEN) {
                val d = (0 until DAYS).firstOrNull { ev.timeStamp < dayStarts[it + 1] }
                if (d != null) unlocks[d]++
                continue
            }
            // Screen off, lock or shutdown ends whatever was on screen.
            if (ev.eventType in SESSION_END_EVENTS) {
                currentPkg?.let { closeSession(it, ev.timeStamp) }
                currentPkg = null
                continue
            }
            val pkg = ev.packageName ?: continue
            when (ev.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    val prev = currentPkg
                    if (prev != null && prev != pkg) closeSession(prev, ev.timeStamp)
                    if (prev != pkg) {
                        currentPkg = pkg
                        currentSince = ev.timeStamp
                    }
                    val lastBg = lastBackground[pkg]
                    if (prev != pkg && (lastBg == null || ev.timeStamp - lastBg > OPEN_GAP_MS)) {
                        opens[pkg] = (opens[pkg] ?: 0) + 1
                    }
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    if (pkg == currentPkg) {
                        closeSession(pkg, ev.timeStamp)
                        currentPkg = null
                    }
                }
                NOTIFICATION_INTERRUPTION -> notifs[pkg] = (notifs[pkg] ?: 0) + 1
            }
        }
        // The app on screen right now.
        currentPkg?.let { addInterval(it, currentSince, now) }

        val pkgs = (daily.keys + opens.keys + notifs.keys).filter { isLaunchable(it) }.toSet()
        val apps = pkgs.map { pkg ->
            mapOf(
                "packageName" to pkg,
                "label" to labelOf(pkg),
                "dailyMillis" to (daily[pkg] ?: LongArray(DAYS)).toList(),
                "openCount" to (opens[pkg] ?: 0),
                "notificationCount" to (notifs[pkg] ?: 0),
            )
        }
        val notificationsAvailable = pkgs.any { (notifs[it] ?: 0) > 0 }

        // ---- 2. Installed this week / removed (snapshot diff) ------------
        val installedNow = pm.getInstalledPackages(0).filter { isLaunchable(it.packageName) }
        val currentSet = installedNow.map { it.packageName }.toSet()
        val installed = installedNow
            .filter { it.firstInstallTime >= weekStart }
            .map { mapOf("packageName" to it.packageName, "label" to labelOf(it.packageName)) }

        // Android has no "uninstall history" API, so we remember the previous
        // list of apps and diff it. Removals are only seen from first launch on.
        val prefs = getSharedPreferences("activity_report", Context.MODE_PRIVATE)
        val previous = prefs.getStringSet("snapshot", null)
        val removedLog = HashSet<String>(prefs.getStringSet("removed_log", emptySet())!!)
        if (previous != null) {
            for (pkg in previous - currentSet) {
                removedLog.add("$pkg|${prefs.getString("label_$pkg", pkg)}|$now")
            }
        }
        removedLog.removeAll { (it.substringAfterLast('|').toLongOrNull() ?: 0L) < weekStart }
        prefs.edit().apply {
            putStringSet("snapshot", currentSet)
            putStringSet("removed_log", removedLog)
            installedNow.forEach { putString("label_${it.packageName}", labelOf(it.packageName)) }
            apply()
        }
        val removed = removedLog
            .map { entry ->
                val pkg = entry.substringBefore('|')
                val label = entry.substringAfter('|').substringBeforeLast('|')
                pkg to label
            }
            .filter { (pkg, _) -> pkg !in currentSet }
            .map { (pkg, label) -> mapOf("packageName" to pkg, "label" to label) }

        return mapOf(
            "weekStartMillis" to weekStart,
            "apps" to apps,
            "installed" to installed,
            "removed" to removed,
            "notificationsAvailable" to notificationsAvailable,
            "dailyUnlocks" to (if (unlocksAvailable) unlocks.toList() else null),
        )
    }
}
