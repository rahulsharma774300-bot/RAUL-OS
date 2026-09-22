package com.raul.os;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.GestureDescription;
import android.content.ContentValues;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.Path;
import android.hardware.HardwareBuffer;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.view.Display;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;

import java.io.OutputStream;
import java.util.ArrayDeque;
import java.util.HashSet;
import java.util.List;
import java.util.Queue;
import java.util.Set;

public class RaulAccessibilityService extends AccessibilityService {
    private static RaulAccessibilityService instance;

    public static RaulAccessibilityService get() {
        return instance;
    }

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();
        instance = this;
    }

    @Override
    public void onDestroy() {
        if (instance == this) instance = null;
        super.onDestroy();
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        // Deliberately no passive logging. RAUL.OS reads UI only when a command asks it to.
    }

    @Override
    public void onInterrupt() {
    }

    public String global(int action) {
        return performGlobalAction(action) ? "Done." : "That system action was not available.";
    }

    public String currentPackage() {
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null || root.getPackageName() == null) return "No active app detected.";
        return root.getPackageName().toString();
    }

    public String clickText(String text) {
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) return "No active screen is available.";
        List<AccessibilityNodeInfo> nodes = root.findAccessibilityNodeInfosByText(text);
        if (nodes == null || nodes.isEmpty()) return "I couldn't find " + text + " on screen.";

        for (AccessibilityNodeInfo node : nodes) {
            AccessibilityNodeInfo target = node;
            int hops = 0;
            while (target != null && !target.isClickable() && hops < 6) {
                target = target.getParent();
                hops++;
            }
            if (target != null && target.isVisibleToUser() && target.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                return "Tapped " + text + ".";
            }
        }
        return "I found " + text + " but couldn't tap it.";
    }

    public String setText(String text) {
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) return "No active screen is available.";

        AccessibilityNodeInfo target = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT);
        if (target == null || !target.isEditable()) {
            target = findFirstEditable(root);
        }
        if (target == null) return "No editable field is focused.";
        if (target.isPassword()) return "RAUL.OS will not type into password fields.";

        Bundle args = new Bundle();
        args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text);
        boolean ok = target.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args);
        return ok ? "Text entered." : "I couldn't enter text in that field.";
    }

    private AccessibilityNodeInfo findFirstEditable(AccessibilityNodeInfo root) {
        Queue<AccessibilityNodeInfo> q = new ArrayDeque<>();
        q.add(root);
        int seen = 0;
        while (!q.isEmpty() && seen++ < 300) {
            AccessibilityNodeInfo n = q.remove();
            if (n.isVisibleToUser() && n.isEditable() && !n.isPassword()) return n;
            for (int i = 0; i < n.getChildCount(); i++) {
                AccessibilityNodeInfo child = n.getChild(i);
                if (child != null) q.add(child);
            }
        }
        return null;
    }

    public String scroll(boolean down) {
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) return "No active screen is available.";
        Queue<AccessibilityNodeInfo> q = new ArrayDeque<>();
        q.add(root);
        int seen = 0;
        int action = down ? AccessibilityNodeInfo.ACTION_SCROLL_FORWARD : AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD;
        while (!q.isEmpty() && seen++ < 300) {
            AccessibilityNodeInfo n = q.remove();
            if (n.isVisibleToUser() && n.isScrollable() && n.performAction(action)) {
                return down ? "Scrolled down." : "Scrolled up.";
            }
            for (int i = 0; i < n.getChildCount(); i++) {
                AccessibilityNodeInfo child = n.getChild(i);
                if (child != null) q.add(child);
            }
        }
        return "No scrollable area found.";
    }

    public String readScreen() {
        AccessibilityNodeInfo root = getRootInActiveWindow();
        if (root == null) return "No active screen is available.";

        Queue<AccessibilityNodeInfo> q = new ArrayDeque<>();
        Set<String> unique = new HashSet<>();
        q.add(root);
        int seen = 0;
        StringBuilder out = new StringBuilder();
        while (!q.isEmpty() && seen++ < 350 && out.length() < 3500) {
            AccessibilityNodeInfo n = q.remove();
            if (n.isVisibleToUser() && !n.isPassword()) {
                addText(unique, out, n.getText());
                addText(unique, out, n.getContentDescription());
            }
            for (int i = 0; i < n.getChildCount(); i++) {
                AccessibilityNodeInfo child = n.getChild(i);
                if (child != null) q.add(child);
            }
        }
        return out.length() == 0 ? "No readable text is visible." : out.toString();
    }

    private void addText(Set<String> unique, StringBuilder out, CharSequence value) {
        if (value == null) return;
        String text = value.toString().trim();
        if (text.isEmpty() || !unique.add(text)) return;
        if (out.length() > 0) out.append(" | ");
        out.append(text);
    }

    public String tap(float x, float y) {
        Path path = new Path();
        path.moveTo(x, y);
        GestureDescription gesture = new GestureDescription.Builder()
                .addStroke(new GestureDescription.StrokeDescription(path, 0, 80))
                .build();
        boolean ok = dispatchGesture(gesture, null, null);
        return ok ? "Tap sent." : "Tap could not be sent.";
    }

    public String swipe(float x1, float y1, float x2, float y2, long durationMs) {
        Path path = new Path();
        path.moveTo(x1, y1);
        path.lineTo(x2, y2);
        GestureDescription gesture = new GestureDescription.Builder()
                .addStroke(new GestureDescription.StrokeDescription(path, 0, durationMs))
                .build();
        boolean ok = dispatchGesture(gesture, null, null);
        return ok ? "Swipe sent." : "Swipe could not be sent.";
    }

    public String swipeVertical(boolean up) {
        float width = getResources().getDisplayMetrics().widthPixels;
        float height = getResources().getDisplayMetrics().heightPixels;
        float x = width / 2f;
        return up
                ? swipe(x, height * 0.75f, x, height * 0.25f, 350)
                : swipe(x, height * 0.25f, x, height * 0.75f, 350);
    }

    public String openAppByLabel(String requested) {
        String q = requested.trim().toLowerCase();
        PackageManager pm = getPackageManager();
        ApplicationInfo best = null;
        try {
            List<ApplicationInfo> apps = pm.getInstalledApplications(0);
            for (ApplicationInfo app : apps) {
                String label = pm.getApplicationLabel(app).toString().trim().toLowerCase();
                if (label.equals(q)) {
                    best = app;
                    break;
                }
                if (best == null && (label.contains(q) || q.contains(label))) {
                    best = app;
                }
            }
        } catch (Exception e) {
            return "I couldn't scan installed apps.";
        }

        if (best == null) return "I couldn't find an installed app named " + requested + ".";
        Intent launch = pm.getLaunchIntentForPackage(best.packageName);
        if (launch == null) return "That app has no launchable screen.";
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        startActivity(launch);
        return "Opened " + pm.getApplicationLabel(best) + ".";
    }

    public String takeBasicScreenshot() {
        return performGlobalAction(GLOBAL_ACTION_TAKE_SCREENSHOT)
                ? "Screenshot requested."
                : "Screenshot action was not available.";
    }

    public void captureAndShareScreenshot(java.util.function.Consumer<String> callback) {
        takeScreenshot(Display.DEFAULT_DISPLAY, getMainExecutor(), new TakeScreenshotCallback() {
            @Override
            public void onSuccess(ScreenshotResult screenshot) {
                HardwareBuffer buffer = screenshot.getHardwareBuffer();
                Bitmap hardware = Bitmap.wrapHardwareBuffer(buffer, screenshot.getColorSpace());
                if (hardware == null) {
                    buffer.close();
                    callback.accept("Screenshot capture returned no image.");
                    return;
                }
                Bitmap bitmap = hardware.copy(Bitmap.Config.ARGB_8888, false);
                buffer.close();

                ContentValues values = new ContentValues();
                values.put(MediaStore.Images.Media.DISPLAY_NAME, "raul_os_" + System.currentTimeMillis() + ".png");
                values.put(MediaStore.Images.Media.MIME_TYPE, "image/png");
                values.put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/RAUL_OS");

                Uri uri = getContentResolver().insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
                if (uri == null) {
                    callback.accept("I couldn't save the screenshot.");
                    return;
                }
                try (OutputStream out = getContentResolver().openOutputStream(uri)) {
                    if (out == null || !bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)) {
                        callback.accept("I couldn't write the screenshot.");
                        return;
                    }
                } catch (Exception e) {
                    callback.accept("Screenshot save failed: " + e.getClass().getSimpleName() + ".");
                    return;
                }

                Intent share = new Intent(Intent.ACTION_SEND);
                share.setType("image/png");
                share.putExtra(Intent.EXTRA_STREAM, uri);
                share.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_ACTIVITY_NEW_TASK);
                Intent chooser = Intent.createChooser(share, "Send screenshot for analysis");
                chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(chooser);
                callback.accept("Screenshot captured. Choose an AI app to analyze it.");
            }

            @Override
            public void onFailure(int errorCode) {
                callback.accept("Screenshot capture failed. Secure screens can block this. Error " + errorCode + ".");
            }
        });
    }
}
