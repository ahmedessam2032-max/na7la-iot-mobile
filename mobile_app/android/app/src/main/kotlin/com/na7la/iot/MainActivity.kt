package com.na7la.iot

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.InputStream
import java.io.OutputStream
import java.net.InetSocketAddress
import java.net.Socket

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.na7la.iot/native_wifi"
    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var currentStripNetwork: Network? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestWifiPermissions" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val perms = mutableListOf(
                            android.Manifest.permission.ACCESS_FINE_LOCATION,
                            android.Manifest.permission.ACCESS_COARSE_LOCATION
                        )
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            perms.add(android.Manifest.permission.NEARBY_WIFI_DEVICES)
                            perms.add(android.Manifest.permission.POST_NOTIFICATIONS)
                        }
                        requestPermissions(perms.toTypedArray(), 999)
                        result.success(true)
                    } else {
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
                        wifiManager?.startScan()
                        val results = wifiManager?.scanResults ?: emptyList()
                        val list = mutableListOf<Map<String, Any>>()
                        val seen = mutableSetOf<String>()

                        for (r in results) {
                            val ssid = r.SSID ?: ""
                            if (ssid.isNotBlank() && ssid != "<unknown ssid>" && !seen.contains(ssid)) {
                                seen.add(ssid)
                                val is24 = r.frequency in 2400..2500
                                list.add(mapOf(
                                    "ssid" to ssid,
                                    "frequency" to r.frequency,
                                    "is24GHz" to is24,
                                    "level" to r.level
                                ))
                            }
                        }
                        result.success(list)
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

                            // Release previous callback if any
                            networkCallback?.let {
                                try { connectivityManager?.unregisterNetworkCallback(it) } catch (_: Exception) {}
                            }

                            networkCallback = object : ConnectivityManager.NetworkCallback() {
                                override fun onAvailable(network: Network) {
                                    super.onAvailable(network)
                                    currentStripNetwork = network
                                    // Bind the app process to this network so TCP sockets go directly to strip
                                    connectivityManager?.bindProcessToNetwork(network)
                                    activity.runOnUiThread {
                                        result.success(true)
                                    }
                                }

                                override fun onUnavailable() {
                                    super.onUnavailable()
                                    currentStripNetwork = null
                                    activity.runOnUiThread {
                                        result.error("UNAVAILABLE", "Failed to connect to strip Wi-Fi", null)
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
                        // Android 9 and below
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

                        // 1. Gather candidate IPs: Gateway from network properties, 192.168.1.1, 192.168.4.1
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
                                s.soTimeout = 6000
                                s.connect(InetSocketAddress(ip, port), 4000)

                                val out: OutputStream = s.getOutputStream()
                                val inStream: InputStream = s.getInputStream()
                                val buf = ByteArray(512)

                                // Step 1: Set Cloud Destination IP (up:ip:<serverIp>\r\n)
                                val cmdIp = "up:ip:$serverIp\r\n".toByteArray(Charsets.UTF_8)
                                out.write(cmdIp)
                                out.flush()
                                Thread.sleep(600)

                                // Step 2: Set Home Wi-Fi credentials (up:connect:<ssid>:<password>\r\n)
                                val cmdConnect = "up:connect:$routerSsid:$routerPassword\r\n".toByteArray(Charsets.UTF_8)
                                out.write(cmdConnect)
                                out.flush()
                                Thread.sleep(600)

                                // Step 3: Trigger reboot (up:reboot:0\r\n)
                                val cmdReboot = "up:reboot:0\r\n".toByteArray(Charsets.UTF_8)
                                out.write(cmdReboot)
                                out.flush()
                                Thread.sleep(300)

                                succeeded = true
                                break
                            } catch (e: Exception) {
                                lastError = "${e.javaClass.simpleName}: ${e.message}"
                            } finally {
                                try { socket?.close() } catch (_: Exception) {}
                            }
                        }

                        activity.runOnUiThread {
                            if (succeeded) {
                                result.success(mapOf("success" to true, "message" to "Provisioned successfully"))
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
                            connectivityManager?.unregisterNetworkCallback(it)
                            networkCallback = null
                        }
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
