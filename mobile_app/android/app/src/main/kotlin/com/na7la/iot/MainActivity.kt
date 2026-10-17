package com.na7la.iot

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.na7la.iot/native_wifi"
    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
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

                            networkCallback = object : ConnectivityManager.NetworkCallback() {
                                override fun onAvailable(network: Network) {
                                    super.onAvailable(network)
                                    // Bind the app process to this network so TCP sockets go to 192.168.1.1:30300
                                    connectivityManager?.bindProcessToNetwork(network)
                                    activity.runOnUiThread {
                                        result.success(true)
                                    }
                                }

                                override fun onUnavailable() {
                                    super.onUnavailable()
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
                "releaseStripAP" -> {
                    try {
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
