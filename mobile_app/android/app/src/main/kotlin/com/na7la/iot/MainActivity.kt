package com.na7la.iot

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.InputStream
import java.io.OutputStream
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.na7la.iot/native_wifi"
    private val PERMISSION_REQ_CODE = 999
    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var currentStripNetwork: Network? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    private fun getRequiredWifiPermissions(): List<String> {
        val perms = mutableListOf(
            android.Manifest.permission.ACCESS_FINE_LOCATION,
            android.Manifest.permission.ACCESS_COARSE_LOCATION
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            perms.add(android.Manifest.permission.NEARBY_WIFI_DEVICES)
        }
        return perms
    }

    private fun hasAllWifiPermissions(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val fineGranted = ContextCompat.checkSelfPermission(
            this,
            android.Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val nearbyGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                this,
                android.Manifest.permission.NEARBY_WIFI_DEVICES
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
        return fineGranted && nearbyGranted
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQ_CODE) {
            val res = pendingPermissionResult
            pendingPermissionResult = null
            res?.success(hasAllWifiPermissions())
        }
    }

    private fun collectAggregatedScanResults(wifiManager: WifiManager?): List<Map<String, Any>> {
        val rawResults = try {
            wifiManager?.scanResults ?: emptyList()
        } catch (_: Exception) {
            emptyList()
        }

        data class AggNet(
            val ssid: String,
            var frequency: Int,
            var is24GHz: Boolean,
            var level: Int
        )

        val mapBySsid = linkedMapOf<String, AggNet>()
        for (r in rawResults) {
            val ssid = (r.SSID ?: "").trim()
            if (ssid.isEmpty() || ssid == "<unknown ssid>") continue
            val is24 = r.frequency in 2400..2500
            val existing = mapBySsid[ssid]
            if (existing == null) {
                mapBySsid[ssid] = AggNet(
                    ssid = ssid,
                    frequency = r.frequency,
                    is24GHz = is24,
                    level = r.level
                )
            } else {
                // If any BSSID for this SSID is 2.4GHz, mark network as 2.4GHz-capable
                if (is24 && !existing.is24GHz) {
                    existing.is24GHz = true
                    existing.frequency = r.frequency
                }
                if (r.level > existing.level) {
                    existing.level = r.level
                }
            }
        }

        val sorted = mapBySsid.values.sortedWith(
            compareByDescending<AggNet> {
                val u = it.ssid.uppercase()
                u.startsWith("TONLY_TAP_") || u.startsWith("ONLY_TAP_")
            }.thenByDescending { it.level }
        )

        return sorted.map {
            mapOf(
                "ssid" to it.ssid,
                "frequency" to it.frequency,
                "is24GHz" to it.is24GHz,
                "level" to it.level
            )
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasWifiPermissions" -> {
                    result.success(hasAllWifiPermissions())
                }

                "requestWifiPermissions" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val missing = getRequiredWifiPermissions().filter {
                            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
                        }
                        if (missing.isEmpty()) {
                            result.success(true)
                        } else {
                            pendingPermissionResult?.success(hasAllWifiPermissions())
                            pendingPermissionResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                missing.toTypedArray(),
                                PERMISSION_REQ_CODE
                            )
                        }
                    } else {
                        result.success(true)
                    }
                }

                "isLocationEnabled" -> {
                    try {
                        val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                        val isEnabled = if (lm != null) {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                                lm.isLocationEnabled
                            } else {
                                lm.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                                lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
                            }
                        } else {
                            true
                        }
                        result.success(isEnabled)
                    } catch (e: Exception) {
                        result.success(true)
                    }
                }

                "openLocationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                "openWifiSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val panelIntent = Intent(Settings.Panel.ACTION_WIFI)
                            startActivity(panelIntent)
                        } else {
                            val wifiIntent = Intent(Settings.ACTION_WIFI_SETTINGS)
                            wifiIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(wifiIntent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val wifiIntent = Intent(Settings.ACTION_WIFI_SETTINGS)
                            wifiIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(wifiIntent)
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                }

                "hasInternetConnection" -> {
                    try {
                        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                        val activeNet = cm?.activeNetwork
                        val caps = if (activeNet != null) cm.getNetworkCapabilities(activeNet) else null
                        val hasNet = caps != null &&
                            caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                            currentStripNetwork == null
                        result.success(hasNet)
                    } catch (_: Exception) {
                        result.success(true)
                    }
                }

                "getCurrentSsid" -> {
                    try {
                        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                        val info = wifiManager?.connectionInfo
                        var ssid = info?.ssid ?: ""
                        if (ssid.startsWith("\"") && ssid.endsWith("\"") && ssid.length > 2) {
                            ssid = ssid.substring(1, ssid.length - 1)
                        }
                        if (ssid == "<unknown ssid>" || ssid == "0x") {
                            ssid = ""
                        }
                        result.success(ssid)
                    } catch (e: Exception) {
                        result.success("")
                    }
                }

                "scanNearbyWifi" -> {
                    try {
                        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                        if (wifiManager == null) {
                            result.success(emptyList<Map<String, Any>>())
                            return@setMethodCallHandler
                        }

                        val completed = AtomicBoolean(false)
                        val handler = Handler(Looper.getMainLooper())
                        var receiver: BroadcastReceiver? = null

                        fun finishScan() {
                            if (completed.compareAndSet(false, true)) {
                                receiver?.let {
                                    try {
                                        applicationContext.unregisterReceiver(it)
                                    } catch (_: Exception) {}
                                }
                                handler.removeCallbacksAndMessages(null)
                                val list = collectAggregatedScanResults(wifiManager)
                                runOnUiThread {
                                    result.success(list)
                                }
                            }
                        }

                        receiver = object : BroadcastReceiver() {
                            override fun onReceive(context: Context?, intent: Intent?) {
                                finishScan()
                            }
                        }

                        val filter = IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            applicationContext.registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
                        } else {
                            applicationContext.registerReceiver(receiver, filter)
                        }

                        val scanStarted = try {
                            @Suppress("DEPRECATION")
                            wifiManager.startScan()
                        } catch (_: Exception) {
                            false
                        }

                        // Wait up to 2.2s for fresh hardware scan broadcast, or 500ms if OS throttled startScan()
                        val timeoutMs = if (scanStarted) 2200L else 500L
                        handler.postDelayed({ finishScan() }, timeoutMs)
                    } catch (e: Exception) {
                        result.success(emptyList<Map<String, Any>>())
                    }
                }

                "connectToStripAP" -> {
                    val ssid = call.argument<String>("ssid") ?: ""
                    val password = call.argument<String>("password") ?: ""

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        try {
                            connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

                            val specifier = WifiNetworkSpecifier.Builder()
                                .setSsid(ssid)
                                .setWpa2Passphrase(password)
                                .build()

                            val request = NetworkRequest.Builder()
                                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                                .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                                .setNetworkSpecifier(specifier)
                                .build()

                            networkCallback?.let {
                                try { connectivityManager?.unregisterNetworkCallback(it) } catch (_: Exception) {}
                            }

                            val responded = AtomicBoolean(false)
                            networkCallback = object : ConnectivityManager.NetworkCallback() {
                                override fun onAvailable(network: Network) {
                                    super.onAvailable(network)
                                    currentStripNetwork = network
                                    connectivityManager?.bindProcessToNetwork(network)
                                    if (responded.compareAndSet(false, true)) {
                                        this@MainActivity.runOnUiThread {
                                            result.success(true)
                                        }
                                    }
                                }

                                override fun onUnavailable() {
                                    super.onUnavailable()
                                    currentStripNetwork = null
                                    if (responded.compareAndSet(false, true)) {
                                        this@MainActivity.runOnUiThread {
                                            result.error("UNAVAILABLE", "Failed to connect to strip Wi-Fi", null)
                                        }
                                    }
                                }
                            }

                            networkCallback?.let {
                                connectivityManager?.requestNetwork(request, it)
                            }
                        } catch (e: Exception) {
                            result.error("ERROR", e.localizedMessage, null)
                        }
                    } else {
                        result.success(false)
                    }
                }

                "sendNativeProvisioning" -> {
                    val routerSsid = call.argument<String>("routerSsid") ?: ""
                    val routerPassword = call.argument<String>("routerPassword") ?: ""
                    val serverIp = call.argument<String>("serverIp") ?: "13.61.25.9"
                    val port = call.argument<Int>("port") ?: 30300

                    Thread {
                        var socket: Socket? = null
                        var succeeded = false
                        var lastError = "Could not reach strip"
                        var matchedIp = ""

                        fun readLine(inStream: InputStream, maxMs: Long = 1800): String {
                            val start = System.currentTimeMillis()
                            val sb = StringBuilder()
                            val buf = ByteArray(1)
                            while (System.currentTimeMillis() - start < maxMs) {
                                if (inStream.available() > 0) {
                                    val r = inStream.read(buf)
                                    if (r == -1) break
                                    val ch = buf[0].toInt().toChar()
                                    if (ch == '\n') break
                                    if (ch != '\r') sb.append(ch)
                                } else {
                                    Thread.sleep(50)
                                }
                            }
                            return sb.toString().trim()
                        }

                        val candidateIps = mutableListOf<String>()
                        try {
                            currentStripNetwork?.let { net ->
                                val lp = connectivityManager?.getLinkProperties(net)
                                lp?.routes?.forEach { route ->
                                    val gw = route.gateway?.hostAddress
                                    if (gw != null && gw != "0.0.0.0" && !candidateIps.contains(gw)) {
                                        candidateIps.add(gw)
                                    }
                                }
                            }
                        } catch (_: Exception) {}

                        if (!candidateIps.contains("192.168.1.1")) candidateIps.add("192.168.1.1")
                        if (!candidateIps.contains("192.168.4.1")) candidateIps.add("192.168.4.1")

                        for (ip in candidateIps) {
                            try {
                                val s = if (currentStripNetwork != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                    currentStripNetwork!!.socketFactory.createSocket()
                                } else {
                                    Socket()
                                }
                                socket = s
                                s.soTimeout = 5000
                                s.connect(InetSocketAddress(ip, port), 3500)

                                val out: OutputStream = s.getOutputStream()
                                val inStream: InputStream = s.getInputStream()

                                val cmdIp = "up:ip:$serverIp\r\n".toByteArray(Charsets.UTF_8)
                                out.write(cmdIp)
                                out.flush()
                                readLine(inStream, 1500)

                                val cmdConnect = "up:connect:$routerSsid:$routerPassword\r\n".toByteArray(Charsets.UTF_8)
                                out.write(cmdConnect)
                                out.flush()
                                val respConnect = readLine(inStream, 2000)

                                if (respConnect.contains("err", ignoreCase = true) || respConnect.contains("fail", ignoreCase = true)) {
                                    lastError = "Strip rejected Wi-Fi credentials: $respConnect"
                                    continue
                                }

                                try {
                                    val cmdReboot = "up:reboot:0\r\n".toByteArray(Charsets.UTF_8)
                                    out.write(cmdReboot)
                                    out.flush()
                                    Thread.sleep(300)
                                } catch (_: Exception) {}

                                succeeded = true
                                matchedIp = ip
                                break
                            } catch (e: Exception) {
                                lastError = "${e.javaClass.simpleName}: ${e.message}"
                            } finally {
                                try { socket?.close() } catch (_: Exception) {}
                            }
                        }

                        this@MainActivity.runOnUiThread {
                            if (succeeded) {
                                result.success(mapOf(
                                    "success" to true,
                                    "message" to "Provisioned successfully",
                                    "ip" to matchedIp
                                ))
                            } else {
                                result.success(mapOf("success" to false, "error" to lastError))
                            }
                        }
                    }.start()
                }

                "releaseStripAP" -> {
                    try {
                        currentStripNetwork = null
                        connectivityManager?.bindProcessToNetwork(null)
                        networkCallback?.let {
                            try {
                                connectivityManager?.unregisterNetworkCallback(it)
                            } catch (_: Exception) {}
                            networkCallback = null
                        }
                        try {
                            @Suppress("DEPRECATION")
                            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                            @Suppress("DEPRECATION")
                            wifiManager?.reconnect()
                        } catch (_: Exception) {}
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
