package com.raul.os;

import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraManager;
import android.media.AudioManager;
import android.net.Uri;
import android.provider.Settings;
import android.view.KeyEvent;

public final class DeviceActions {
    private DeviceActions() {}

    public static String setBrightness(Context context, int percent) {
        percent = Math.max(1, Math.min(100, percent));
        if (!Settings.System.canWrite(context)) {
            Intent intent = new Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS,
                    Uri.parse("package:" + context.getPackageName()));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
            return "Enable Modify system settings, then run the brightness command again.";
        }
        int raw = Math.max(1, Math.min(255, Math.round(percent * 2.55f)));
        Settings.System.putInt(context.getContentResolver(),
                Settings.System.SCREEN_BRIGHTNESS_MODE,
                Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL);
        Settings.System.putInt(context.getContentResolver(),
                Settings.System.SCREEN_BRIGHTNESS, raw);
        return "Brightness set to " + percent + "%.";
    }

    public static String setMediaVolume(Context context, int percent) {
        AudioManager audio = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        int max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
        int value = Math.round(max * (Math.max(0, Math.min(100, percent)) / 100f));
        audio.setStreamVolume(AudioManager.STREAM_MUSIC, value, AudioManager.FLAG_SHOW_UI);
        return "Media volume set to " + percent + "%.";
    }

    public static String volumeStep(Context context, int direction) {
        AudioManager audio = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        audio.adjustStreamVolume(AudioManager.STREAM_MUSIC, direction, AudioManager.FLAG_SHOW_UI);
        return "Volume adjusted.";
    }

    public static String mediaKey(Context context, int keyCode) {
        AudioManager audio = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        long now = android.os.SystemClock.uptimeMillis();
        audio.dispatchMediaKeyEvent(new KeyEvent(now, now, KeyEvent.ACTION_DOWN, keyCode, 0));
        audio.dispatchMediaKeyEvent(new KeyEvent(now, now, KeyEvent.ACTION_UP, keyCode, 0));
        return "Media command sent.";
    }

    public static String flashlight(Context context, boolean on) {
        CameraManager camera = (CameraManager) context.getSystemService(Context.CAMERA_SERVICE);
        try {
            for (String id : camera.getCameraIdList()) {
                CameraCharacteristics c = camera.getCameraCharacteristics(id);
                Boolean flash = c.get(CameraCharacteristics.FLASH_INFO_AVAILABLE);
                Integer facing = c.get(CameraCharacteristics.LENS_FACING);
                if (Boolean.TRUE.equals(flash)
                        && facing != null
                        && facing == CameraCharacteristics.LENS_FACING_BACK) {
                    camera.setTorchMode(id, on);
                    return "Flashlight " + (on ? "on." : "off.");
                }
            }
            return "No usable flashlight found.";
        } catch (Exception e) {
            return "Flashlight failed: " + e.getClass().getSimpleName() + ".";
        }
    }

    public static String setDnd(Context context, boolean on) {
        NotificationManager nm = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (!nm.isNotificationPolicyAccessGranted()) {
            Intent intent = new Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
            return "Enable Do Not Disturb access, then run the command again.";
        }
        nm.setInterruptionFilter(on
                ? NotificationManager.INTERRUPTION_FILTER_PRIORITY
                : NotificationManager.INTERRUPTION_FILTER_ALL);
        return "Do Not Disturb " + (on ? "enabled." : "disabled.");
    }

    public static void openSettings(Context context, String action) {
        Intent intent = new Intent(action);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(intent);
    }
}
