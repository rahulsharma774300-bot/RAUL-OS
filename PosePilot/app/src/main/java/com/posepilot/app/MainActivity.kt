package com.posepilot.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
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
    val permissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { cameraGranted = it }
    var detectedScene by remember { mutableStateOf("Looking at your surroundings…") }
    var labels by remember { mutableStateOf<List<String>>(emptyList()) }
    var selectedPose by remember { mutableStateOf(poses[0]) }
    var showGrid by remember { mutableStateOf(true) }
    var showPoseLines by remember { mutableStateOf(true) }
    var facingFront by remember { mutableStateOf(false) }
    val sceneKey = sceneKey(detectedScene)
    val suggestions = poses.filter { pose -> pose.scenes.any { it in sceneKey } }.ifEmpty { poses }
    LaunchedEffect(Unit) { if (!cameraGranted) permissionLauncher.launch(Manifest.permission.CAMERA) }

    MaterialTheme(colorScheme = darkColorScheme(background = Ink, surface = Panel, primary = Lime, onPrimary = Ink, onBackground = Color.White, onSurface = Color.White, secondary = Muted)) {
        Surface(Modifier.fillMaxSize(), color = Ink) {
            Column(Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 12.dp)) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
                    Column {
                        Text("POSEPILOT", color = Lime, fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 3.sp)
                        Text("Pose coach", fontSize = 25.sp, fontWeight = FontWeight.Bold)
                    }
                    TextButton(onClick = { facingFront = !facingFront }) { Text("↻ Flip", color = Lime) }
                }
                Spacer(Modifier.height(10.dp))
                Box(Modifier.weight(1f).fillMaxWidth().background(Color(0xFF090A08), RoundedCornerShape(24.dp))) {
                    if (cameraGranted) {
                        CameraPreview(
                            front = facingFront,
                            onLabels = { found ->
                                if (found.isNotEmpty()) {
                                    labels = found
                                    detectedScene = describeScene(found)
                                    val match = poses.firstOrNull { pose -> pose.scenes.any { key -> found.any { it.contains(key, true) } } }
                                    if (match != null) selectedPose = match
                                }
                            },
                            modifier = Modifier.fillMaxSize()
                        )
                        if (showGrid || showPoseLines) {
                            PoseOverlay(Modifier.fillMaxSize(), showGrid, showPoseLines, selectedPose.guide)
                        }
                        Column(Modifier.align(Alignment.TopStart).padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Surface(color = Color(0xCC11130F), shape = RoundedCornerShape(12.dp)) {
                                Column(Modifier.padding(horizontal = 12.dp, vertical = 9.dp)) {
                                    Text("SCENE ANALYSIS", color = Lime, fontSize = 9.sp, letterSpacing = 1.5.sp, fontWeight = FontWeight.Bold)
                                    Text(detectedScene, color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                                    if (labels.isNotEmpty()) Text(labels.take(3).joinToString(" · "), color = Muted, fontSize = 10.sp)
                                }
                            }
                        }
                        Column(Modifier.align(Alignment.BottomCenter).padding(12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("Guide overlay is a pose template, not a live body-tracking skeleton", color = Color.White, fontSize = 10.sp)
                            Spacer(Modifier.height(6.dp))
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                FilterChip(selected = showGrid, onClick = { showGrid = !showGrid }, label = { Text("Grid") })
                                FilterChip(selected = showPoseLines, onClick = { showPoseLines = !showPoseLines }, label = { Text("Pose lines") })
                            }
                        }
                    } else {
                        Column(Modifier.align(Alignment.Center).padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("Camera permission needed", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                            Spacer(Modifier.height(8.dp))
                            Text("PosePilot uses the camera to classify the background on your device.", color = Muted)
                            Spacer(Modifier.height(14.dp))
                            Button(onClick = { permissionLauncher.launch(Manifest.permission.CAMERA) }) { Text("Enable camera") }
                        }
                    }
                }
                Spacer(Modifier.height(12.dp))
                Text("SUGGESTED FOR THIS SCENE", color = Muted, fontSize = 10.sp, letterSpacing = 2.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(8.dp))
                Text(selectedPose.name, fontSize = 21.sp, fontWeight = FontWeight.Bold)
                Text(selectedPose.instructions, color = Muted, fontSize = 13.sp, lineHeight = 18.sp)
                Spacer(Modifier.height(8.dp))
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(suggestions) { pose ->
                        Surface(color = if (pose == selectedPose) Lime else Panel, shape = RoundedCornerShape(16.dp), modifier = Modifier.width(158.dp).clickable { selectedPose = pose }) {
                            Column(Modifier.padding(12.dp)) {
                                Text(pose.category.uppercase(), color = if (pose == selectedPose) Ink else Lime, fontSize = 9.sp, letterSpacing = 1.3.sp)
                                Spacer(Modifier.height(4.dp))
                                Text(pose.name, color = if (pose == selectedPose) Ink else Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                Spacer(Modifier.height(5.dp))
                                Text(pose.framing, color = if (pose == selectedPose) Ink else Muted, fontSize = 10.sp)
                            }
                        }
                    }
                }
                Spacer(Modifier.height(4.dp))
                Text("On-device scene labels · no photos uploaded · Pinterest-inspired original pose prompts", color = Muted, fontSize = 9.sp)
            }
        }
    }
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
    val lifecycleOwner = androidx.lifecycle.compose.LocalLifecycleOwner.current
    val executor = remember { Executors.newSingleThreadExecutor() }
    val labeler = remember { ImageLabeling.getClient(ImageLabelerOptions.Builder().setConfidenceThreshold(0.55f).build()) }
    val busy = remember { AtomicBoolean(false) }
    AndroidView(
        modifier = modifier,
        factory = { ctx ->
            val previewView = PreviewView(ctx).apply { scaleType = PreviewView.ScaleType.FILL_CENTER }
            val providerFuture = ProcessCameraProvider.getInstance(ctx)
            providerFuture.addListener({
                val provider = providerFuture.get()
                val preview = Preview.Builder().build().also { it.surfaceProvider = previewView.surfaceProvider }
                val analysis = ImageAnalysis.Builder().setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
                analysis.setAnalyzer(executor) { proxy -> analyzeFrame(proxy, labeler, busy, onLabels) }
                try {
                    provider.unbindAll()
                    provider.bindToLifecycle(lifecycleOwner, if (front) CameraSelector.DEFAULT_FRONT_CAMERA else CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis)
                } catch (_: Exception) { }
            }, ContextCompat.getMainExecutor(ctx))
            previewView
        },
        update = { view ->
            val providerFuture = ProcessCameraProvider.getInstance(context)
            providerFuture.addListener({
                try {
                    val provider = providerFuture.get()
                    val preview = Preview.Builder().build().also { it.surfaceProvider = view.surfaceProvider }
                    val analysis = ImageAnalysis.Builder().setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
                    analysis.setAnalyzer(executor) { proxy -> analyzeFrame(proxy, labeler, busy, onLabels) }
                    provider.unbindAll()
                    provider.bindToLifecycle(lifecycleOwner, if (front) CameraSelector.DEFAULT_FRONT_CAMERA else CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis)
                } catch (_: Exception) { }
            }, ContextCompat.getMainExecutor(context))
        }
    )
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
