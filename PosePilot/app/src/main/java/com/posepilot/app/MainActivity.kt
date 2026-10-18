package com.posepilot.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val Ink = Color(0xFF151711)
private val Panel = Color(0xFF22251E)
private val Lime = Color(0xFFD9F36A)
private val Muted = Color(0xFFB6B9AC)

data class Pose(val name: String, val category: String, val instructions: String, val framing: String)
private val poses = listOf(
    Pose("Look beyond", "Cinematic", "Turn your body 45° away. Keep your shoulders relaxed and look toward the horizon.", "Full body · camera at waist height"),
    Pose("Easy walk", "Candid", "Walk slowly past the camera. Look away and let your arms move naturally.", "Full body · portrait mode"),
    Pose("Hands in pockets", "Casual", "Shift your weight onto one leg, keep one shoulder slightly forward and relax your jaw.", "Three-quarter · eye level"),
    Pose("Sit and look out", "Travel", "Sit on a safe, stable surface, lean forward slightly and look into the distance.", "Wide shot · scenery visible"),
    Pose("Jacket adjustment", "Fashion", "Adjust your cuff or jacket while looking down. Keep the movement subtle.", "Mid shot · slight low angle"),
    Pose("Silhouette", "Cinematic", "Stand against a bright sky, keep your outline clean and turn your face in profile.", "Wide shot · expose for sky"),
    Pose("Over-the-shoulder", "Portrait", "Turn away, then look back toward the camera over your shoulder.", "Mid shot · eye level"),
    Pose("Rock-side stance", "Adventure", "Stand only on safe, level ground. Place one foot slightly forward and look toward the view.", "Full body · wide lens"),
    Pose("Café candid", "Lifestyle", "Hold your cup naturally, glance out of the window and keep your shoulders relaxed.", "Mid shot · natural light"),
    Pose("Wall lean", "Street", "Lean one shoulder lightly against a wall, cross ankles loosely and look off-camera.", "Full body · straight lines"),
    Pose("Overhead selfie", "Selfie", "Raise the phone a little above eye level, angle your face toward soft light and relax your chin.", "Front camera · arm's length"),
    Pose("Group stagger", "Group", "Arrange people at slightly different depths, angle bodies inward and keep faces unobstructed.", "Wide shot · timer")
)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { PosePilotApp() }
    }
}

@Composable
fun PosePilotApp() {
    var selectedCategory by remember { mutableStateOf("All") }
    var selectedPose by remember { mutableStateOf<Pose?>(null) }
    var scene by remember { mutableStateOf("Mountains") }
    val categories = listOf("All", "Travel", "Cinematic", "Candid", "Fashion", "Lifestyle", "Group", "Selfie")
    val filtered = poses.filter { selectedCategory == "All" || it.category.equals(selectedCategory, true) }
    MaterialTheme(colorScheme = darkColorScheme(
        background = Ink, surface = Panel, primary = Lime, onPrimary = Ink,
        onBackground = Color.White, onSurface = Color.White, secondary = Muted
    )) {
        Surface(modifier = Modifier.fillMaxSize(), color = Ink) {
            if (selectedPose != null) {
                PoseDetail(selectedPose!!, onBack = { selectedPose = null })
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(start = 20.dp, end = 20.dp, top = 24.dp, bottom = 28.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    item {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                            Column {
                                Text("POSEPILOT", color = Lime, fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 3.sp)
                                Text("Your next photo.", fontSize = 30.sp, fontWeight = FontWeight.Bold)
                            }
                            Box(Modifier.size(46.dp).background(Panel, RoundedCornerShape(16.dp)), contentAlignment = Alignment.Center) {
                                Text("✳", color = Lime, fontSize = 25.sp)
                            }
                        }
                    }
                    item {
                        Column(Modifier.fillMaxWidth().background(Panel, RoundedCornerShape(24.dp)).padding(18.dp)) {
                            Text("YOUR SCENE", color = Muted, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 2.sp)
                            Spacer(Modifier.height(8.dp))
                            Text(scene, fontSize = 25.sp, fontWeight = FontWeight.Bold)
                            Text("Choose the closest setting to get better pose ideas.", color = Muted, fontSize = 13.sp)
                            Spacer(Modifier.height(12.dp))
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                listOf("Mountains", "Greenery", "City", "Indoor").forEach { label ->
                                    FilterChip(selected = scene == label, onClick = { scene = label }, label = { Text(label) })
                                }
                            }
                            Spacer(Modifier.height(8.dp))
                            Text("GPS and live scene recognition are planned integrations in this starter build.", color = Muted, fontSize = 11.sp)
                        }
                    }
                    item {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                            Text("Pose ideas", fontSize = 22.sp, fontWeight = FontWeight.Bold)
                            Text("${filtered.size} poses", color = Muted, fontSize = 12.sp)
                        }
                    }
                    item {
                        androidx.compose.foundation.lazy.LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            items(categories) { category ->
                                FilterChip(selected = selectedCategory == category, onClick = { selectedCategory = category }, label = { Text(category) })
                            }
                        }
                    }
                    items(filtered) { pose ->
                        Row(
                            modifier = Modifier.fillMaxWidth().background(Panel, RoundedCornerShape(20.dp)).clickable { selectedPose = pose }.padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Box(Modifier.size(58.dp).background(Color(0xFF34392A), RoundedCornerShape(16.dp)), contentAlignment = Alignment.Center) {
                                Text("✦", color = Lime, fontSize = 27.sp)
                            }
                            Spacer(Modifier.width(14.dp))
                            Column(Modifier.weight(1f)) {
                                Text(pose.name, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                                Text(pose.category + "  ·  " + pose.framing, color = Muted, fontSize = 12.sp)
                            }
                            Text("→", color = Lime, fontSize = 22.sp)
                        }
                    }
                    item { Text("POSEPILOT  •  STARTER EDITION", color = Muted, fontSize = 10.sp, letterSpacing = 2.sp, modifier = Modifier.padding(top = 8.dp)) }
                }
            }
        }
    }
}

@Composable
private fun PoseDetail(pose: Pose, onBack: () -> Unit) {
    Column(Modifier.fillMaxSize().padding(22.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
        Text("←  Back", color = Lime, modifier = Modifier.clickable { onBack() })
        Box(Modifier.fillMaxWidth().height(270.dp).background(Panel, RoundedCornerShape(28.dp)), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("POSE REFERENCE", color = Lime, fontSize = 11.sp, letterSpacing = 3.sp)
                Spacer(Modifier.height(12.dp))
                Text("✦", fontSize = 76.sp, color = Lime)
                Text("Match the posture, not the person.", color = Muted, fontSize = 12.sp)
            }
        }
        Text(pose.name, fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Text(pose.category.uppercase(), color = Lime, fontSize = 11.sp, letterSpacing = 2.sp)
        Text(pose.instructions, fontSize = 17.sp, lineHeight = 25.sp)
        Divider(color = Panel)
        Text("CAMERA SETUP", color = Muted, fontSize = 11.sp, letterSpacing = 2.sp)
        Text(pose.framing, fontSize = 16.sp)
        Spacer(Modifier.weight(1f))
        Button(onClick = { }, modifier = Modifier.fillMaxWidth(), colors = ButtonDefaults.buttonColors(containerColor = Lime, contentColor = Ink)) {
            Text("Open camera · coming next", fontWeight = FontWeight.Bold)
        }
    }
}
