package com.raul.os;

import android.Manifest;
import android.app.Activity;
import android.app.NotificationManager;
import android.app.role.RoleManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.service.voice.VoiceInteractionService;
import android.text.InputType;
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
    private EditText apiKeyInput;
    private EditText modelInput;

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
        content.setPadding(dp(18), dp(22), dp(18), dp(36));
        scroll.addView(content, new ScrollView.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        TextView title = text("RAUL.OS V3", 31, Color.rgb(78, 219, 255));
        content.addView(title);

        TextView subtitle = text(
                "Always-listening personal assistant • “Hey Raul” • Hindi + English • phone actions • AI brain",
                15, Color.LTGRAY);
        subtitle.setPadding(0, dp(4), 0, dp(14));
        content.addView(subtitle);

        TextView note = text(
                "Set RAUL.OS as your default assistant, grant the permissions below, then tap Activate once. " +
                "After that, say things like “Hey Raul, call Mom”, “Hey Raul, tell me time”, or ask a normal question. " +
                "Android may still require one manual activation after installation or if the phone kills the microphone service.",
                14, Color.rgb(210, 220, 228));
        note.setPadding(0, 0, 0, dp(16));
        content.addView(note);

        status = text("Checking setup…", 15, Color.WHITE);
        status.setPadding(dp(12), dp(12), dp(12), dp(12));
        status.setBackgroundColor(Color.rgb(18, 31, 43));
        content.addView(status);

        addSection("1. Make RAUL your assistant");
        addButton("Set RAUL.OS as default assistant", this::requestAssistantRole);
        addButton("Grant Mic + Contacts + Phone + Camera", this::requestRuntimePermissions);
        addButton("Enable Accessibility control", () ->
                startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)));
        addButton("Enable Notification access", () ->
                startActivity(new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)));
        addButton("Enable Modify system settings", () -> {
            Intent intent = new Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS,
                    Uri.parse("package:" + getPackageName()));
            startActivity(intent);
        });
        addButton("Enable Do Not Disturb access", () ->
                startActivity(new Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)));
        addButton("Battery optimization settings", () ->
                startActivity(new Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)));

        addSection("2. Truecaller");
        TextView truecallerHelp = text(
                "For “Hey Raul, call Mom” to go through Truecaller reliably, set Truecaller as your default Phone app. " +
                "RAUL.OS will try Truecaller directly first and fall back to the system default dialer.",
                13, Color.rgb(180, 200, 212));
        content.addView(truecallerHelp);
        addButton("Open Default Apps → set Truecaller as Phone app", () ->
                startActivity(new Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS)));

        addSection("3. AI brain");
        TextView brainHelp = text(
                "Phone commands work locally. For normal questions and conversation, add your own OpenAI API key. " +
                "The key is encrypted with Android Keystore and stays on this phone.",
                13, Color.rgb(180, 200, 212));
        content.addView(brainHelp);

        apiKeyInput = input("OpenAI API key");
        apiKeyInput.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        content.addView(apiKeyInput);

        modelInput = input("Model");
        modelInput.setSingleLine(true);
        modelInput.setText(getSharedPreferences(JarvisService.PREFS, MODE_PRIVATE)
                .getString("brain_model", "gpt-5.6-luna"));
        content.addView(modelInput);

        addButton("Save AI brain settings", () -> {
            try {
                String key = apiKeyInput.getText().toString().trim();
                if (!key.isEmpty()) {
                    SecureStore.saveApiKey(this, key);
                    apiKeyInput.setText("");
                }
                String model = modelInput.getText().toString().trim();
                if (model.isEmpty()) model = "gpt-5.6-luna";
                getSharedPreferences(JarvisService.PREFS, MODE_PRIVATE)
                        .edit().putString("brain_model", model).apply();
                Toast.makeText(this, "AI brain settings saved.", Toast.LENGTH_LONG).show();
                refreshStatus();
            } catch (Exception e) {
                Toast.makeText(this, "Could not secure the API key.", Toast.LENGTH_LONG).show();
            }
        });

        addButton("Clear conversation memory", () -> {
            ConversationHistory.clear(this);
            Toast.makeText(this, "Conversation memory cleared.", Toast.LENGTH_SHORT).show();
        });

        addSection("4. Always-listening Jarvis");
        addButton("ACTIVATE “HEY RAUL”", this::activateJarvis);
        addButton("Stop listening", () -> {
            getSharedPreferences(JarvisService.PREFS, MODE_PRIVATE)
                    .edit().putBoolean(JarvisService.KEY_ENABLED, false).apply();
            Intent stop = new Intent(this, JarvisService.class).setAction(JarvisService.ACTION_STOP);
            startService(stop);
            Toast.makeText(this, "RAUL stopped listening.", Toast.LENGTH_SHORT).show();
            refreshStatus();
        });

        TextView examples = text(
                "Try:\n" +
                        "Hey Raul, call Mom\n" +
                        "Hey Raul, tell me time\n" +
                        "Hey Raul, battery kitni hai?\n" +
                        "Hey Raul, open Spotify\n" +
                        "Hey Raul, brightness 40\n" +
                        "Hey Raul, read my notifications\n" +
                        "Hey Raul, who invented the internet?\n" +
                        "Hey Raul, aaj Chandigarh ka weather kaisa hai?\n\n" +
                        "After RAUL replies, you have about 30 seconds to continue talking without repeating “Hey Raul”.",
                14, Color.rgb(180, 200, 212));
        examples.setPadding(0, dp(10), 0, dp(12));
        content.addView(examples);

        addSection("5. Advanced phone control");
        addButton("Enable floating orb (optional)", () -> {
            if (!Settings.canDrawOverlays(this)) {
                Intent intent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:" + getPackageName()));
                startActivity(intent);
                return;
            }
            startForegroundService(new Intent(this, OrbService.class));
        });
        addButton("Check Shizuku readiness", () ->
                status.setText(ShizukuBridge.status(this)));

        setContentView(scroll);
    }

    private void requestAssistantRole() {
        RoleManager roleManager = (RoleManager) getSystemService(Context.ROLE_SERVICE);
        String role = "android.app.role.ASSISTANT";
        if (roleManager != null && roleManager.isRoleAvailable(role)) {
            startActivityForResult(roleManager.createRequestRoleIntent(role), 202);
        } else {
            try {
                startActivity(new Intent("android.settings.VOICE_INPUT_SETTINGS"));
            } catch (Exception e) {
                startActivity(new Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS));
            }
        }
    }

    private void activateJarvis() {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO)
                != PackageManager.PERMISSION_GRANTED) {
            requestRuntimePermissions();
            Toast.makeText(this, "Grant Microphone permission, then tap Activate again.", Toast.LENGTH_LONG).show();
            return;
        }

        getSharedPreferences(JarvisService.PREFS, MODE_PRIVATE)
                .edit().putBoolean(JarvisService.KEY_ENABLED, true).apply();

        try {
            Intent intent = new Intent(this, JarvisService.class).setAction(JarvisService.ACTION_START);
            startForegroundService(intent);
            Toast.makeText(this, "RAUL is listening. Say “Hey Raul”.", Toast.LENGTH_LONG).show();
        } catch (Exception e) {
            Toast.makeText(this,
                    "Android blocked the microphone service. Make RAUL your default assistant, then try again.",
                    Toast.LENGTH_LONG).show();
        }
        refreshStatus();
    }

    private void requestRuntimePermissions() {
        List<String> needed = new ArrayList<>();
        addIfMissing(needed, Manifest.permission.RECORD_AUDIO);
        addIfMissing(needed, Manifest.permission.READ_CONTACTS);
        addIfMissing(needed, Manifest.permission.CALL_PHONE);
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

    private void refreshStatus() {
        if (status == null) return;

        NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        boolean assistant = VoiceInteractionService.isActiveService(
                this, new ComponentName(this, RaulVoiceInteractionService.class));
        boolean jarvis = getSharedPreferences(JarvisService.PREFS, MODE_PRIVATE)
                .getBoolean(JarvisService.KEY_ENABLED, false);

        String value =
                "Default assistant: " + onOff(assistant) +
                "\nHey Raul enabled: " + onOff(jarvis) +
                "\nAI brain key: " + (SecureStore.hasApiKey(this) ? "CONFIGURED" : "NOT SET") +
                "\nAccessibility: " + onOff(isAccessibilityEnabled()) +
                "\nNotification access: " + onOff(isNotificationAccessEnabled()) +
                "\nMic: " + onOff(has(Manifest.permission.RECORD_AUDIO)) +
                "\nContacts: " + onOff(has(Manifest.permission.READ_CONTACTS)) +
                "\nPhone calls: " + onOff(has(Manifest.permission.CALL_PHONE)) +
                "\nModify settings: " + onOff(Settings.System.canWrite(this)) +
                "\nDND access: " + onOff(nm.isNotificationPolicyAccessGranted());

        status.setText(value);
    }

    private boolean has(String permission) {
        return checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED;
    }

    private boolean isAccessibilityEnabled() {
        String enabled = Settings.Secure.getString(
                getContentResolver(), Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
        if (enabled == null) return false;
        String lower = enabled.toLowerCase();
        return lower.contains(getPackageName().toLowerCase())
                && lower.contains("raulaccessibilityservice");
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
        TextView view = text(label, 19, Color.rgb(78, 219, 255));
        view.setPadding(0, dp(18), 0, dp(6));
        content.addView(view);
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
