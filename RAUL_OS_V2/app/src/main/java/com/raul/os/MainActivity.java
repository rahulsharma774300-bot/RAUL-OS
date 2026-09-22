package com.raul.os;

import android.Manifest;
import android.app.Activity;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.List;

public class MainActivity extends Activity {
    private TextView status;
    private LinearLayout content;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        buildUi();
    }

    @Override
    protected void onResume() {
        super.onResume();
        refreshStatus();
    }

    private void buildUi() {
        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        scroll.setBackgroundColor(Color.rgb(8, 16, 24));

        content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(dp(18), dp(22), dp(18), dp(30));
        scroll.addView(content, new ScrollView.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        TextView title = text("RAUL.OS V2", 30, Color.rgb(78, 219, 255));
        content.addView(title);

        TextView subtitle = text(
                "Phone control layer • voice • accessibility • notifications • macros • floating orb",
                15, Color.LTGRAY);
        subtitle.setPadding(0, dp(4), 0, dp(14));
        content.addView(subtitle);

        TextView disclosure = text(
                "Accessibility is powerful. RAUL.OS does not passively log your screen, skips password fields, and only performs UI actions after you run a command. Secure/DRM/banking screens may block automation or screenshots.",
                14, Color.rgb(210, 220, 228));
        disclosure.setPadding(0, 0, 0, dp(16));
        content.addView(disclosure);

        status = text("Checking permissions…", 15, Color.WHITE);
        status.setPadding(dp(12), dp(12), dp(12), dp(12));
        status.setBackgroundColor(Color.rgb(18, 31, 43));
        content.addView(status);

        addSection("1. Core permissions");
        addButton("Enable Accessibility control", () ->
                startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)));

        addButton("Enable Notification access", () ->
                startActivity(new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)));

        addButton("Enable floating overlay", () -> {
            Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:" + getPackageName()));
            startActivity(intent);
        });

        addButton("Enable Modify system settings", () -> {
            Intent intent = new Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS,
                    Uri.parse("package:" + getPackageName()));
            startActivity(intent);
        });

        addButton("Enable Do Not Disturb access", () ->
                startActivity(new Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)));

        addButton("Grant microphone / contacts / camera", this::requestRuntimePermissions);

        addSection("2. Assistant");
        addButton("Start floating RAUL orb", this::startOrb);
        addButton("Stop floating RAUL orb", () -> {
            stopService(new Intent(this, OrbService.class));
            Toast.makeText(this, "Floating orb stopped.", Toast.LENGTH_SHORT).show();
        });
        addButton("Speak a command", () ->
                startActivity(new Intent(this, VoiceCommandActivity.class)));

        addSection("3. Run a command");
        EditText command = input("Example: open WhatsApp");
        content.addView(command);
        addButton("Run command", () -> {
            String value = command.getText().toString().trim();
            CommandRouter.executeAsync(this, value, result ->
                    runOnUiThread(() -> {
                        status.setText(result);
                        Toast.makeText(this, result, Toast.LENGTH_LONG).show();
                    }));
        });

        TextView examples = text(
                "Examples:\n" +
                        "open Spotify\n" +
                        "tap Search\n" +
                        "type hello\n" +
                        "read screen\n" +
                        "scroll down\n" +
                        "call Radhika\n" +
                        "read notifications\n" +
                        "brightness 40\n" +
                        "volume 70\n" +
                        "flashlight on\n" +
                        "analyze screenshot\n" +
                        "gaming mode",
                14, Color.rgb(180, 200, 212));
        examples.setPadding(0, dp(8), 0, dp(12));
        content.addView(examples);

        addSection("4. Custom aliases and macros");
        EditText alias = input("Alias phrase, e.g. message Radhika");
        EditText macro = input("Commands, e.g. open WhatsApp; wait 2; tap Radhika; wait 1; type I'll call you soon");
        content.addView(alias);
        content.addView(macro);
        addButton("Save alias / macro", () -> {
            String phrase = alias.getText().toString().trim();
            String mapped = macro.getText().toString().trim();
            if (phrase.isEmpty() || mapped.isEmpty()) {
                Toast.makeText(this, "Enter both an alias and commands.", Toast.LENGTH_SHORT).show();
                return;
            }
            LocalMemory.putAlias(this, phrase, mapped);
            Toast.makeText(this, "Saved alias: " + phrase, Toast.LENGTH_LONG).show();
        });

        TextView macroHelp = text(
                "Macros run left-to-right. Use semicolons between steps and “wait 2” when an app needs time to load. Example:\n" +
                        "open Instagram; wait 2; tap Search; wait 1; type OpenAI",
                13, Color.rgb(180, 200, 212));
        macroHelp.setPadding(0, dp(6), 0, dp(12));
        content.addView(macroHelp);

        addSection("5. Local memory");
        EditText memoryCommand = input("Example: remember parking is B2");
        content.addView(memoryCommand);
        addButton("Save / query memory command", () ->
                CommandRouter.executeAsync(this, memoryCommand.getText().toString(),
                        result -> runOnUiThread(() -> status.setText(result))));

        addSection("6. Optional deeper-control layer");
        addButton("Check Shizuku readiness", () ->
                status.setText(ShizukuBridge.status(this)));

        TextView shizuku = text(
                "This build detects Shizuku and keeps a privileged-action integration boundary ready, but it does not bypass Android security or silently gain root-level access.",
                13, Color.rgb(180, 200, 212));
        content.addView(shizuku);

        setContentView(scroll);
    }

    private void requestRuntimePermissions() {
        List<String> needed = new ArrayList<>();
        addIfMissing(needed, Manifest.permission.RECORD_AUDIO);
        addIfMissing(needed, Manifest.permission.READ_CONTACTS);
        addIfMissing(needed, Manifest.permission.CAMERA);
        if (Build.VERSION.SDK_INT >= 33) {
            addIfMissing(needed, Manifest.permission.POST_NOTIFICATIONS);
        }
        if (needed.isEmpty()) {
            Toast.makeText(this, "Runtime permissions are already granted.", Toast.LENGTH_SHORT).show();
        } else {
            requestPermissions(needed.toArray(new String[0]), 101);
        }
    }

    private void addIfMissing(List<String> list, String permission) {
        if (checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED) {
            list.add(permission);
        }
    }

    private void startOrb() {
        if (!Settings.canDrawOverlays(this)) {
            Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:" + getPackageName()));
            startActivity(intent);
            Toast.makeText(this, "Enable the overlay permission, then tap Start again.", Toast.LENGTH_LONG).show();
            return;
        }
        Intent intent = new Intent(this, OrbService.class);
        startForegroundService(intent);
        Toast.makeText(this, "Floating orb started.", Toast.LENGTH_SHORT).show();
    }

    private void refreshStatus() {
        if (status == null) return;
        NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        String value =
                "Accessibility: " + onOff(isAccessibilityEnabled()) +
                "\nNotification access: " + onOff(isNotificationAccessEnabled()) +
                "\nOverlay: " + onOff(Settings.canDrawOverlays(this)) +
                "\nModify settings: " + onOff(Settings.System.canWrite(this)) +
                "\nDND access: " + onOff(nm.isNotificationPolicyAccessGranted()) +
                "\nMic: " + onOff(checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) +
                "\nContacts: " + onOff(checkSelfPermission(Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED) +
                "\nCamera/flash: " + onOff(checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED);
        status.setText(value);
    }

    private boolean isAccessibilityEnabled() {
        String enabled = Settings.Secure.getString(
                getContentResolver(), Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
        if (enabled == null) return false;
        return enabled.toLowerCase().contains(getPackageName().toLowerCase())
                && enabled.toLowerCase().contains("raulaccessibilityservice");
    }

    private boolean isNotificationAccessEnabled() {
        String enabled = Settings.Secure.getString(
                getContentResolver(), "enabled_notification_listeners");
        return enabled != null && enabled.toLowerCase().contains(getPackageName().toLowerCase());
    }

    private String onOff(boolean value) {
        return value ? "ON" : "OFF";
    }

    private void addSection(String label) {
        TextView text = text(label, 19, Color.rgb(78, 219, 255));
        text.setPadding(0, dp(18), 0, dp(6));
        content.addView(text);
    }

    private void addButton(String label, Runnable action) {
        Button button = new Button(this);
        button.setText(label);
        button.setAllCaps(false);
        button.setOnClickListener(v -> action.run());
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.setMargins(0, dp(4), 0, dp(4));
        content.addView(button, lp);
    }

    private EditText input(String hint) {
        EditText edit = new EditText(this);
        edit.setHint(hint);
        edit.setHintTextColor(Color.rgb(130, 150, 162));
        edit.setTextColor(Color.WHITE);
        edit.setSingleLine(false);
        edit.setPadding(dp(10), dp(10), dp(10), dp(10));
        return edit;
    }

    private TextView text(String value, int size, int color) {
        TextView view = new TextView(this);
        view.setText(value);
        view.setTextSize(size);
        view.setTextColor(color);
        return view;
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
