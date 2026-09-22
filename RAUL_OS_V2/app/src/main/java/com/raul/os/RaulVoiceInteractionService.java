package com.raul.os;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.service.voice.VoiceInteractionService;

public class RaulVoiceInteractionService extends VoiceInteractionService {
    @Override
    public void onReady() {
        super.onReady();
        boolean enabled = getSharedPreferences(JarvisService.PREFS, MODE_PRIVATE)
                .getBoolean(JarvisService.KEY_ENABLED, false);
        if (enabled && checkSelfPermission(Manifest.permission.RECORD_AUDIO)
                == PackageManager.PERMISSION_GRANTED) {
            try {
                Intent intent = new Intent(this, JarvisService.class)
                        .setAction(JarvisService.ACTION_START);
                startForegroundService(intent);
            } catch (Exception ignored) {
            }
        }
    }
}
