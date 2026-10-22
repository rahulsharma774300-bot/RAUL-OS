package com.posepilot.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.location.Location
import android.os.Looper
import android.util.Log
import java.net.URL
import java.net.HttpURLConnection
import org.json.JSONObject
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationResult
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.foundation.shape.CircleShape
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabel
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

private val Ink = Color(0xFF11130F)
private val Panel = Color(0xFF20241D)
private val Lime = Color(0xFFD9F36A)
private val Muted = Color(0xFFB7BBAE)

data class Pose(val name: String, val category: String, val instructions: String, val framing: String, val scenes: Set<String>, val guide: String)
private val poses = listOf(
    Pose("Trail walker", "Travel", "Walk slowly away from the camera. Keep your shoulders relaxed, let your arms swing, then glance back over one shoulder.", "Full body · camera at waist height", setOf("nature", "mountain", "plant", "sky"), "walk"),
    Pose("Small in the landscape", "Cinematic", "Stand in the lower third of the frame, facing the view. Leave plenty of negative space so the landscape feels huge.", "Wide shot · subject in lower third", setOf("mountain", "sky", "nature", "water"), "wide"),
    Pose("Seated observer", "Travel", "Sit only on a safe, stable surface. Bring one knee up, rest your forearm loosely on it, and look toward the view.", "Three-quarter · scenery visible", setOf("mountain", "nature", "water"), "sit"),
    Pose("Look beyond", "Cinematic", "Turn your body about 45 degrees away. Put your weight on the back leg, relax your hands and look toward the horizon.", "Full body · slight side angle", setOf("nature", "mountain", "sky", "water"), "stand"),
    Pose("Jacket adjustment", "Fashion", "Turn slightly sideways and gently adjust a cuff, sleeve or jacket hem. Look down at the action for a candid moment.", "Mid shot · chest-height camera", setOf("building", "indoor", "street", "wall"), "hands"),
    Pose("Wall lean", "Street", "Rest one shoulder lightly against a wall, cross your ankles loosely and keep one hand in a pocket. Don't press your body flat.", "Full body · use wall lines", setOf("wall", "building", "street", "urban"), "lean"),
    Pose("Café window gaze", "Lifestyle", "Sit sideways by the window, hold your cup naturally and look outside. Keep your shoulders low and hands relaxed.", "Mid shot · soft window light", setOf("indoor", "food", "cup", "table"), "sit"),
    Pose("River-side profile", "Travel", "Stand well back from slippery edges. Turn into profile, look across the water and let one hand hold your jacket strap.", "Three-quarter · water as leading line", setOf("water", "river", "lake", "nature"), "stand"),
    Pose("Over-the-shoulder", "Portrait", "Turn your back partly toward the camera, then look back over your shoulder. Keep the chin slightly forward and down.", "Mid shot · eye level", setOf("nature", "building", "street", "mountain"), "lookback"),
    Pose("Hands in pockets", "Casual", "Shift your weight onto one leg, place thumbs in your pockets and angle one shoulder slightly toward the camera.", "Three-quarter · eye level", setOf("street", "building", "indoor", "urban"), "stand"),
    Pose("Silhouette", "Cinematic", "Stand against a bright sky or sunset. Keep arms slightly away from your torso so your outline reads clearly.", "Wide shot · expose for bright sky", setOf("sky", "sunset", "mountain", "water"), "wide"),
    Pose("Easy candid", "Candid", "Take two or three slow steps, look away from the lens and let your hands move naturally between frames.", "Full body · burst or timer", setOf("nature", "street", "building", "plant"), "walk")
)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { PosePilotApp() }
    }
}

@Composable
fun PosePilotApp() {
    val context = LocalContext.current
    var cameraGranted by remember { mutableStateOf(ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) }
    val cameraPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { cameraGranted = it }
    var locationGranted by remember { mutableStateOf(ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED) }
    val locationPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { locationGranted = it }
    var place by remember { mutableStateOf("Location off") }
    var detectedScene by remember { mutableStateOf("Scanning background…") }
    var labels by remember { mutableStateOf<List<String>>(emptyList()) }
    var selectedPose by remember { mutableStateOf(poses[0]) }
    var showGrid by remember { mutableStateOf(true) }
    var showPoseLines by remember { mutableStateOf(true) }
    var facingFront by remember { mutableStateOf(false) }
    var showSuggestions by remember { mutableStateOf(true) }
    var autoSelect by remember { mutableStateOf(true) }
    val sceneKeys = sceneKey(detectedScene)
    val placeKeys = sceneKey(place)
    val suggestions = poses.sortedByDescending { pose ->
        pose.scenes.count { it in sceneKeys } * 2 + pose.scenes.count { it in placeKeys }
    }
    LaunchedEffect(Unit) { if (!cameraGranted) cameraPermission.launch(Manifest.permission.CAMERA) }
    LaunchedEffect(locationGranted) {
        if (locationGranted) {
            try {
                val client = LocationServices.getFusedLocationProviderClient(context)
                if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                    client.lastLocation.addOnSuccessListener { loc ->
                        if (loc != null) {
                            place = "Finding nearby place…"
                            Thread {
                                val result = lookupPlace(loc.latitude, loc.longitude)
                                android.os.Handler(Looper.getMainLooper()).post { place = result }
                            }.start()
                        } else place = "Location unavailable"
                    }.addOnFailureListener { place = "Location unavailable" }
                }
            } catch (_: Exception) { place = "Location unavailable" }
        }
    }
    MaterialTheme(colorScheme = darkColorScheme(background = Color.Black, surface = Color(0xFF1A1A1A), primary = Color.White)) {
        Column(Modifier.fillMaxSize().background(Color.Black)) {
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                IconButton(onClick = { showGrid = !showGrid }) {
                    Icon(Icons.Default.GridOn, contentDescription = "Toggle grid", tint = if (showGrid) Color.Yellow else Color.White)
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("POSEPILOT", fontSize = 12.sp, letterSpacing = 2.sp, fontWeight = FontWeight.Bold, color = Color.White)
                    Text(place, fontSize = 10.sp, color = Color.LightGray, maxLines = 1)
                }
                IconButton(onClick = {
                    if (locationGranted) {
                        place = "Finding nearby place…"
                        val client = LocationServices.getFusedLocationProviderClient(context)
                        client.lastLocation.addOnSuccessListener { loc ->
                            if (loc != null) Thread {
                                val result = lookupPlace(loc.latitude, loc.longitude)
                                android.os.Handler(Looper.getMainLooper()).post { place = result }
                            }.start() else place = "Location unavailable"
                        }
                    } else locationPermission.launch(Manifest.permission.ACCESS_COARSE_LOCATION)
                }) {
                    Icon(Icons.Default.LocationOn, contentDescription = "Enable or refresh location", tint = if (locationGranted) Color.Yellow else Color.White)
                }
            }
            Box(Modifier.fillMaxWidth().weight(1f).background(Color(0xFF101010))) {
                if (cameraGranted) {
                    CameraPreview(front = facingFront, onLabels = { found ->
                        if (found.isNotEmpty()) {
                            labels = found
                            detectedScene = describeScene(found)
                            if (autoSelect) {
                                val keys = sceneKey(detectedScene) + sceneKey(place)
                                selectedPose = poses.maxByOrNull { pose -> pose.scenes.count { it in keys } } ?: selectedPose
                            }
                        }
                    }, modifier = Modifier.fillMaxSize())
                    PoseOverlay(Modifier.fillMaxSize(), showGrid, showPoseLines, selectedPose.guide)
                    Surface(
                        modifier = Modifier.align(Alignment.TopCenter).padding(top = 14.dp),
                        shape = RoundedCornerShape(30.dp), color = Color.Black.copy(alpha = 0.6f)
                    ) {
                        Text(detectedScene, Modifier.padding(horizontal = 14.dp, vertical = 8.dp), fontSize = 11.sp, color = Color.White)
                    }
                    if (showPoseLines) Surface(
                        modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 16.dp, start = 16.dp, end = 16.dp),
                        color = Color.Black.copy(alpha = 0.7f), shape = RoundedCornerShape(14.dp)
                    ) {
                        Column(Modifier.padding(12.dp)) {
                            Text(selectedPose.name, color = Color.Yellow, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                            Text(selectedPose.instructions, color = Color.White, fontSize = 12.sp, lineHeight = 16.sp)
                        }
                    }
                } else Button(onClick = { cameraPermission.launch(Manifest.permission.CAMERA) }, modifier = Modifier.align(Alignment.Center)) { Text("Enable camera") }
            }
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween
            ) {
                IconButton(onClick = { showPoseLines = !showPoseLines }) {
                    Icon(Icons.Default.AccessibilityNew, contentDescription = "Toggle pose guide", tint = if (showPoseLines) Color.Yellow else Color.White)
                }
                Box(
                    Modifier.size(72.dp).background(Color.White, CircleShape).padding(5.dp)
                        .background(Color.Black, CircleShape).padding(3.dp)
                        .background(Color.White, CircleShape).clickable { showSuggestions = !showSuggestions },
                    contentAlignment = Alignment.Center
                ) { }
                IconButton(onClick = { facingFront = !facingFront }) {
                    Icon(Icons.Default.Cameraswitch, contentDescription = "Flip camera", tint = Color.White)
                }
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
                Text("POSE", color = Color.Yellow, fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 2.sp)
                Spacer(Modifier.width(24.dp))
                Text("SUGGESTIONS", color = Color.White, fontSize = 12.sp, modifier = Modifier.clickable { showSuggestions = !showSuggestions })
            }
            if (showSuggestions) {
                LazyRow(Modifier.padding(vertical = 10.dp), contentPadding = PaddingValues(horizontal = 14.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(suggestions) { pose ->
                        Surface(
                            modifier = Modifier.width(155.dp).clickable { selectedPose = pose; autoSelect = false },
                            shape = RoundedCornerShape(12.dp),
                            color = if (selectedPose == pose) Color(0xFF4B4922) else Color(0xFF222222)
                        ) {
                            Column(Modifier.padding(10.dp)) {
                                Text(pose.name, color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.Bold)
                                Text(pose.framing, color = Color.LightGray, fontSize = 10.sp, maxLines = 2)
                            }
                        }
                    }
                }
            }
            Text(
                "Location uses internet lookup · background analyzed on-device · tap shutter to show/hide suggestions",
                modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp), textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                color = Color.Gray, fontSize = 9.sp
            )
        }
    }
}

private fun lookupPlace(lat: Double, lon: Double): String {
    return try {
        val url = URL("https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&zoom=14&addressdetails=1")
        val conn = url.openConnection() as HttpURLConnection
        conn.connectTimeout = 7000
        conn.readTimeout = 7000
        conn.setRequestProperty("User-Agent", "PosePilot/0.2 (Android location-aware photography)")
        try {
            val data = JSONObject(conn.inputStream.bufferedReader().use { it.readText() })
            val address = data.optJSONObject("address")
            val nearby = listOf("tourism", "natural", "waterway", "road", "suburb", "village", "town", "city", "county", "state")
                .mapNotNull { key -> address?.optString(key)?.takeIf { it.isNotBlank() } }
                .take(2).joinToString(", ")
            nearby.ifBlank { data.optString("name", "Nearby area") }
        } finally { conn.disconnect() }
    } catch (_: Exception) { "Offline · scene-only suggestions" }
}

private fun sceneKey(scene: String): Set<String> = when {
    scene.contains("water", true) || scene.contains("river", true) || scene.contains("lake", true) -> setOf("water", "river", "lake", "nature")
    scene.contains("mountain", true) || scene.contains("hill", true) || scene.contains("sky", true) -> setOf("mountain", "sky", "nature")
    scene.contains("indoor", true) || scene.contains("food", true) || scene.contains("cup", true) || scene.contains("table", true) -> setOf("indoor", "food", "cup", "table")
    scene.contains("building", true) || scene.contains("street", true) || scene.contains("wall", true) || scene.contains("urban", true) -> setOf("building", "street", "wall", "urban")
    else -> setOf("nature", "plant", "sky")
}

private fun describeScene(labels: List<String>): String {
    val text = labels.joinToString(" ").lowercase()
    return when {
        listOf("mountain", "hill", "valley").any { it in text } -> "Mountain / hill landscape"
        listOf("river", "lake", "waterfall", "water").any { it in text } -> "Waterfront / river"
        listOf("tree", "forest", "plant", "grass", "flower").any { it in text } -> "Greenery / nature"
        listOf("building", "architecture", "street", "road", "bridge").any { it in text } -> "Street / architecture"
        listOf("indoor", "restaurant", "cafe", "food", "table", "room").any { it in text } -> "Indoor / café"
        listOf("sky", "cloud", "sunset").any { it in text } -> "Open sky / scenic view"
        else -> "Scene: ${labels.firstOrNull() ?: "analysing"}"
    }
}

@Composable
private fun CameraPreview(front: Boolean, onLabels: (List<String>) -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val executor = remember { Executors.newSingleThreadExecutor() }
    val labeler = remember { ImageLabeling.getClient(ImageLabelerOptions.Builder().setConfidenceThreshold(0.55f).build()) }
    val busy = remember { AtomicBoolean(false) }
    val previewView = remember(context) { PreviewView(context).apply { scaleType = PreviewView.ScaleType.FILL_CENTER } }

    LaunchedEffect(front, previewView, lifecycleOwner) {
        val providerFuture = ProcessCameraProvider.getInstance(context)
        providerFuture.addListener({
            try {
                val provider = providerFuture.get()
                val preview = Preview.Builder().build().also { it.surfaceProvider = previewView.surfaceProvider }
                val analysis = ImageAnalysis.Builder().setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
                analysis.setAnalyzer(executor) { proxy -> analyzeFrame(proxy, labeler, busy, onLabels) }
                provider.unbindAll()
                provider.bindToLifecycle(lifecycleOwner, if (front) CameraSelector.DEFAULT_FRONT_CAMERA else CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis)
            } catch (_: Exception) { }
        }, ContextCompat.getMainExecutor(context))
    }

    AndroidView(modifier = modifier, factory = { previewView })
    DisposableEffect(Unit) {
        onDispose {
            executor.shutdown()
            labeler.close()
        }
    }
}

private fun analyzeFrame(proxy: ImageProxy, labeler: com.google.mlkit.vision.label.ImageLabeler, busy: AtomicBoolean, onLabels: (List<String>) -> Unit) {
    val mediaImage = proxy.image
    if (mediaImage == null || !busy.compareAndSet(false, true)) {
        proxy.close()
        return
    }
    val input = InputImage.fromMediaImage(mediaImage, proxy.imageInfo.rotationDegrees)
    labeler.process(input)
        .addOnSuccessListener { labels: List<ImageLabel> ->
            val top = labels.sortedByDescending { it.confidence }.take(5).map { it.text }
            onLabels(top)
        }
        .addOnCompleteListener {
            busy.set(false)
            proxy.close()
        }
}

@Composable
private fun PoseOverlay(modifier: Modifier, grid: Boolean, poseLines: Boolean, guide: String) {
    Canvas(modifier) {
        val w = size.width
        val h = size.height
        val gridColor = Color.White.copy(alpha = 0.48f)
        if (grid) {
            for (i in 1..2) {
                drawLine(gridColor, Offset(w * i / 3f, 0f), Offset(w * i / 3f, h), 1.dp.toPx())
                drawLine(gridColor, Offset(0f, h * i / 3f), Offset(w, h * i / 3f), 1.dp.toPx())
            }
            drawLine(Color.White.copy(alpha = 0.2f), Offset(w / 2f, 0f), Offset(w / 2f, h), 1.dp.toPx())
        }
        if (poseLines) {
            val c = Lime
            val cx = when (guide) { "wide" -> w * 0.50f; "sit" -> w * 0.53f; else -> w * 0.50f }
            val headY = when (guide) { "sit" -> h * 0.43f; "wide" -> h * 0.48f; else -> h * 0.20f }
            val scale = if (guide == "wide") 0.60f else 1f
            val headR = w * 0.045f * scale
            val shoulderY = headY + h * 0.09f * scale
            val hipY = shoulderY + h * 0.19f * scale
            val footY = minOf(h * 0.91f, hipY + h * 0.28f * scale)
            drawCircle(c, headR, Offset(cx, headY), style = Stroke(3.dp.toPx()))
            drawLine(c, Offset(cx, headY + headR), Offset(cx, hipY), 3.dp.toPx())
            drawLine(c, Offset(cx - w * 0.13f * scale, shoulderY), Offset(cx + w * 0.13f * scale, shoulderY), 3.dp.toPx())
            if (guide == "sit") {
                drawLine(c, Offset(cx, shoulderY), Offset(cx - w * 0.14f, hipY - h * 0.01f), 3.dp.toPx())
                drawLine(c, Offset(cx - w * 0.14f, hipY - h * 0.01f), Offset(cx + w * 0.10f, hipY), 3.dp.toPx())
                drawLine(c, Offset(cx + w * 0.10f, hipY), Offset(cx + w * 0.19f, footY * 0.96f), 3.dp.toPx())
                drawLine(c, Offset(cx, hipY), Offset(cx - w * 0.02f, footY), 3.dp.toPx())
            } else {
                drawLine(c, Offset(cx - w * 0.13f * scale, shoulderY), Offset(cx - w * 0.19f * scale, hipY - h * 0.02f), 3.dp.toPx())
                drawLine(c, Offset(cx + w * 0.13f * scale, shoulderY), Offset(cx + w * 0.18f * scale, hipY - h * 0.01f), 3.dp.toPx())
                val leftKnee = Offset(cx - w * 0.07f * scale, hipY + (footY - hipY) * 0.52f)
                val rightKnee = Offset(cx + w * 0.08f * scale, hipY + (footY - hipY) * 0.50f)
                drawLine(c, Offset(cx, hipY), leftKnee, 3.dp.toPx())
                drawLine(c, leftKnee, Offset(cx - w * 0.10f * scale, footY), 3.dp.toPx())
                drawLine(c, Offset(cx, hipY), rightKnee, 3.dp.toPx())
                drawLine(c, rightKnee, Offset(cx + w * 0.12f * scale, footY), 3.dp.toPx())
            }
            drawCircle(c.copy(alpha = 0.9f), 5.dp.toPx(), Offset(cx, shoulderY))
            drawCircle(c.copy(alpha = 0.9f), 5.dp.toPx(), Offset(cx, hipY))
        }
    }
}
