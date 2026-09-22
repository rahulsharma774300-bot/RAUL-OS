package com.raul.os;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.os.Bundle;
import android.speech.RecognizerIntent;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.Locale;

public class VoiceCommandActivity extends Activity {
    private static final int REQ_SPEECH = 44;
    private TextView status;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(24), dp(24), dp(24), dp(24));
        root.setGravity(Gravity.CENTER_HORIZONTAL);
        root.setBackgroundColor(Color.rgb(8, 16, 24));

        TextView title = new TextView(this);
        title.setText("RAUL.OS VOICE");
        title.setTextColor(Color.rgb(78, 219, 255));
        title.setTextSize(26);
        root.addView(title, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        status = new TextView(this);
        status.setText("Listening…");
        status.setTextColor(Color.WHITE);
        status.setTextSize(18);
        status.setPadding(0, dp(30), 0, dp(30));
        root.addView(status, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        Button again = new Button(this);
        again.setText("Speak again");
        again.setOnClickListener(v -> speak());
        root.addView(again);

        setContentView(root);
        speak();
    }

    private void speak() {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            status.setText("Microphone permission is not enabled.");
            return;
        }
        Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault());
        intent.putExtra(RecognizerIntent.EXTRA_PROMPT, "Tell RAUL.OS what to do");
        try {
            startActivityForResult(intent, REQ_SPEECH);
        } catch (Exception e) {
            status.setText("No speech recognizer is available on this phone.");
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != REQ_SPEECH) return;
        if (resultCode != RESULT_OK || data == null) {
            status.setText("Voice command cancelled.");
            return;
        }

        ArrayList<String> results = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS);
        if (results == null || results.isEmpty()) {
            status.setText("I didn't catch that.");
            return;
        }

        String command = results.get(0);
        status.setText("Command: " + command + "\n\nRunning…");
        CommandRouter.executeAsync(this, command, result ->
                runOnUiThread(() -> {
                    status.setText("Command: " + command + "\n\n" + result);
                    Toast.makeText(this, result, Toast.LENGTH_LONG).show();
                }));
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
