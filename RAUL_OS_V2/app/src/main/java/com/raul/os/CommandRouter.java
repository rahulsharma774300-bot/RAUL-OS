package com.raul.os;

import android.accessibilityservice.AccessibilityService;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.media.AudioManager;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.view.KeyEvent;

import java.util.Locale;
import java.util.function.Consumer;

public final class CommandRouter {
    private static final Handler MAIN = new Handler(Looper.getMainLooper());

    private CommandRouter() {}

    public static void executeAsync(Context context, String command, Consumer<String> callback) {
        executeInternal(context.getApplicationContext(), command, callback, 0);
    }

    private static void executeInternal(Context context, String command, Consumer<String> callback, int depth) {
        if (command == null || command.trim().isEmpty()) {
            callback.accept("No command received.");
            return;
        }
        if (depth > 5) {
            callback.accept("Alias nesting is too deep.");
            return;
        }

        String raw = command.trim();
        String lower = raw.toLowerCase(Locale.ROOT);

        String alias = LocalMemory.getAlias(context, lower);
        if (alias != null) {
            executeMacro(context, alias, callback, depth + 1);
            return;
        }

        if (raw.contains(";")) {
            executeMacro(context, raw, callback, depth + 1);
            return;
        }

        if (lower.startsWith("wait ")) {
            try {
                double seconds = Double.parseDouble(raw.substring(5).trim());
                long ms = Math.max(0, Math.min(15000, (long) (seconds * 1000)));
                MAIN.postDelayed(() -> callback.accept("Waited " + seconds + " second(s)."), ms);
            } catch (Exception e) {
                callback.accept("Use wait followed by seconds, for example: wait 2.");
            }
            return;
        }

        if (lower.startsWith("alias ")) {
            int at = lower.indexOf(" means ");
            if (at > 6) {
                String phrase = raw.substring(6, at).trim();
                String mapped = raw.substring(at + 7).trim();
                LocalMemory.putAlias(context, phrase, mapped);
                callback.accept("Alias saved: " + phrase + ".");
            } else {
                callback.accept("Use: alias phrase means command.");
            }
            return;
        }

        if (lower.startsWith("remember ")) {
            int at = lower.indexOf(" is ", 9);
            if (at > 9) {
                String key = raw.substring(9, at).trim();
                String value = raw.substring(at + 4).trim();
                LocalMemory.remember(context, key, value);
                callback.accept("Remembered " + key + ".");
            } else {
                callback.accept("Use: remember name is value.");
            }
            return;
        }

        if (lower.startsWith("what is ")) {
            String key = raw.substring(8).trim();
            String value = LocalMemory.recall(context, key);
            callback.accept(value == null ? "I don't have a local memory for " + key + "." : value);
            return;
        }

        if (lower.equals("shizuku status")) {
            callback.accept(ShizukuBridge.status(context));
            return;
        }

        if (lower.equals("read notifications")) {
            RaulNotificationService n = RaulNotificationService.get();
            callback.accept(n == null ? "Enable Notification access for RAUL.OS first." : n.summary());
            return;
        }

        if (lower.equals("clear notifications")) {
            RaulNotificationService n = RaulNotificationService.get();
            callback.accept(n == null ? "Enable Notification access for RAUL.OS first." : n.dismissAllNow());
            return;
        }

        if (lower.startsWith("dismiss notifications from ")) {
            RaulNotificationService n = RaulNotificationService.get();
            callback.accept(n == null
                    ? "Enable Notification access for RAUL.OS first."
                    : n.dismissFrom(raw.substring("dismiss notifications from ".length()).trim()));
            return;
        }

        if (lower.startsWith("copy ")) {
            ClipboardManager cm = (ClipboardManager) context.getSystemService(Context.CLIPBOARD_SERVICE);
            cm.setPrimaryClip(ClipData.newPlainText("RAUL.OS", raw.substring(5)));
            callback.accept("Copied.");
            return;
        }

        if (lower.equals("clipboard")) {
            ClipboardManager cm = (ClipboardManager) context.getSystemService(Context.CLIPBOARD_SERVICE);
            if (!cm.hasPrimaryClip() || cm.getPrimaryClip() == null || cm.getPrimaryClip().getItemCount() == 0) {
                callback.accept("Clipboard is empty or unavailable.");
            } else {
                CharSequence text = cm.getPrimaryClip().getItemAt(0).coerceToText(context);
                callback.accept(text == null ? "Clipboard has no readable text." : text.toString());
            }
            return;
        }

        if (lower.equals("clear clipboard")) {
            ClipboardManager cm = (ClipboardManager) context.getSystemService(Context.CLIPBOARD_SERVICE);
            cm.clearPrimaryClip();
            callback.accept("Clipboard cleared.");
            return;
        }

        if (lower.equals("wifi settings")) {
            DeviceActions.openSettings(context, Settings.ACTION_WIFI_SETTINGS);
            callback.accept("Opened Wi-Fi settings.");
            return;
        }
        if (lower.equals("bluetooth settings")) {
            DeviceActions.openSettings(context, Settings.ACTION_BLUETOOTH_SETTINGS);
            callback.accept("Opened Bluetooth settings.");
            return;
        }
        if (lower.equals("internet settings")) {
            DeviceActions.openSettings(context, Settings.Panel.ACTION_INTERNET_CONNECTIVITY);
            callback.accept("Opened internet controls.");
            return;
        }
        if (lower.equals("settings") || lower.equals("open settings")) {
            DeviceActions.openSettings(context, Settings.ACTION_SETTINGS);
            callback.accept("Opened Settings.");
            return;
        }

        if (lower.startsWith("brightness ")) {
            callback.accept(DeviceActions.setBrightness(context, parsePercent(raw.substring(11))));
            return;
        }

        if (lower.equals("volume up")) {
            callback.accept(DeviceActions.volumeStep(context, AudioManager.ADJUST_RAISE));
            return;
        }
        if (lower.equals("volume down")) {
            callback.accept(DeviceActions.volumeStep(context, AudioManager.ADJUST_LOWER));
            return;
        }
        if (lower.equals("mute") || lower.equals("volume mute")) {
            callback.accept(DeviceActions.setMediaVolume(context, 0));
            return;
        }
        if (lower.startsWith("volume ")) {
            callback.accept(DeviceActions.setMediaVolume(context, parsePercent(raw.substring(7))));
            return;
        }

        if (lower.equals("play") || lower.equals("pause") || lower.equals("play pause")) {
            callback.accept(DeviceActions.mediaKey(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE));
            return;
        }
        if (lower.equals("next track") || lower.equals("next")) {
            callback.accept(DeviceActions.mediaKey(context, KeyEvent.KEYCODE_MEDIA_NEXT));
            return;
        }
        if (lower.equals("previous track") || lower.equals("previous")) {
            callback.accept(DeviceActions.mediaKey(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS));
            return;
        }

        if (lower.equals("flashlight on")) {
            callback.accept(DeviceActions.flashlight(context, true));
            return;
        }
        if (lower.equals("flashlight off")) {
            callback.accept(DeviceActions.flashlight(context, false));
            return;
        }

        if (lower.equals("dnd on") || lower.equals("do not disturb on")) {
            callback.accept(DeviceActions.setDnd(context, true));
            return;
        }
        if (lower.equals("dnd off") || lower.equals("do not disturb off")) {
            callback.accept(DeviceActions.setDnd(context, false));
            return;
        }

        if (lower.startsWith("call ")) {
            callback.accept(ContactHelper.dialContact(context, raw.substring(5).trim()));
            return;
        }

        if (lower.startsWith("search ")) {
            String q = raw.substring(7).trim();
            Intent intent = new Intent(Intent.ACTION_VIEW,
                    Uri.parse("https://www.google.com/search?q=" + Uri.encode(q)));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
            callback.accept("Searching for " + q + ".");
            return;
        }

        if (lower.equals("gaming mode")) {
            executeMacro(context, "volume 85; brightness 75; dnd on", callback, depth + 1);
            return;
        }

        if (lower.equals("work mode")) {
            executeMacro(context, "volume 50; dnd off", callback, depth + 1);
            return;
        }

        RaulAccessibilityService a = RaulAccessibilityService.get();
        if (a == null) {
            callback.accept("Enable RAUL.OS Accessibility first for screen and app-control commands.");
            return;
        }

        if (lower.equals("back")) {
            callback.accept(a.global(AccessibilityService.GLOBAL_ACTION_BACK));
            return;
        }
        if (lower.equals("home")) {
            callback.accept(a.global(AccessibilityService.GLOBAL_ACTION_HOME));
            return;
        }
        if (lower.equals("recents") || lower.equals("recent apps")) {
            callback.accept(a.global(AccessibilityService.GLOBAL_ACTION_RECENTS));
            return;
        }
        if (lower.equals("notifications")) {
            callback.accept(a.global(AccessibilityService.GLOBAL_ACTION_NOTIFICATIONS));
            return;
        }
        if (lower.equals("quick settings")) {
            callback.accept(a.global(AccessibilityService.GLOBAL_ACTION_QUICK_SETTINGS));
            return;
        }
        if (lower.equals("current app")) {
            callback.accept(a.currentPackage());
            return;
        }
        if (lower.equals("read screen")) {
            callback.accept(a.readScreen());
            return;
        }
        if (lower.equals("scroll down")) {
            callback.accept(a.scroll(true));
            return;
        }
        if (lower.equals("scroll up")) {
            callback.accept(a.scroll(false));
            return;
        }
        if (lower.equals("swipe up")) {
            callback.accept(a.swipeVertical(true));
            return;
        }
        if (lower.equals("swipe down")) {
            callback.accept(a.swipeVertical(false));
            return;
        }
        if (lower.startsWith("tap ")) {
            String rest = raw.substring(4).trim();
            String[] xy = rest.split("\\s+");
            if (xy.length == 2) {
                try {
                    callback.accept(a.tap(Float.parseFloat(xy[0]), Float.parseFloat(xy[1])));
                    return;
                } catch (NumberFormatException ignored) {
                }
            }
            callback.accept(a.clickText(rest));
            return;
        }
        if (lower.startsWith("type ")) {
            callback.accept(a.setText(raw.substring(5)));
            return;
        }
        if (lower.equals("paste")) {
            ClipboardManager cm = (ClipboardManager) context.getSystemService(Context.CLIPBOARD_SERVICE);
            if (!cm.hasPrimaryClip() || cm.getPrimaryClip() == null || cm.getPrimaryClip().getItemCount() == 0) {
                callback.accept("Clipboard is empty.");
            } else {
                CharSequence text = cm.getPrimaryClip().getItemAt(0).coerceToText(context);
                callback.accept(text == null ? "Clipboard has no text." : a.setText(text.toString()));
            }
            return;
        }
        if (lower.equals("take screenshot")) {
            callback.accept(a.takeBasicScreenshot());
            return;
        }
        if (lower.equals("analyze screenshot") || lower.equals("share screenshot")) {
            a.captureAndShareScreenshot(callback);
            return;
        }
        if (lower.startsWith("open ")) {
            callback.accept(a.openAppByLabel(raw.substring(5).trim()));
            return;
        }

        callback.accept("Unknown command. Try open <app>, tap <text>, type <text>, read screen, call <name>, read notifications, or create an alias/macro.");
    }

    private static int parsePercent(String text) {
        String digits = text.replace("%", "").trim();
        try {
            return Math.max(0, Math.min(100, Integer.parseInt(digits)));
        } catch (Exception e) {
            return 50;
        }
    }

    private static void executeMacro(Context context, String macro, Consumer<String> callback, int depth) {
        String[] commands = macro.split(";");
        StringBuilder results = new StringBuilder();

        class Runner implements Runnable {
            int index = 0;

            @Override
            public void run() {
                if (index >= commands.length) {
                    callback.accept(results.length() == 0 ? "Macro complete." : results.toString());
                    return;
                }
                String next = commands[index++].trim();
                if (next.isEmpty()) {
                    MAIN.post(this);
                    return;
                }
                executeInternal(context, next, result -> {
                    if (result != null && !result.isEmpty()) {
                        if (results.length() > 0) results.append("\n");
                        results.append(result);
                    }
                    MAIN.postDelayed(this, 450);
                }, depth + 1);
            }
        }

        MAIN.post(new Runner());
    }
}
