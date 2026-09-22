package com.raul.os;

import android.app.Notification;
import android.os.Bundle;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class RaulNotificationService extends NotificationListenerService {
    private static RaulNotificationService instance;
    private final LinkedHashMap<String, StatusBarNotification> recent = new LinkedHashMap<>();

    public static RaulNotificationService get() {
        return instance;
    }

    @Override
    public void onListenerConnected() {
        super.onListenerConnected();
        instance = this;
        try {
            StatusBarNotification[] active = getActiveNotifications();
            if (active != null) {
                for (StatusBarNotification sbn : active) {
                    remember(sbn);
                }
            }
        } catch (Exception ignored) {
        }
    }

    @Override
    public void onListenerDisconnected() {
        super.onListenerDisconnected();
        if (instance == this) {
            instance = null;
        }
    }

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        remember(sbn);
    }

    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        recent.remove(sbn.getKey());
    }

    private synchronized void remember(StatusBarNotification sbn) {
        recent.put(sbn.getKey(), sbn);
        while (recent.size() > 50) {
            String first = recent.keySet().iterator().next();
            recent.remove(first);
        }
    }

    public synchronized String summary() {
        if (recent.isEmpty()) {
            return "No notifications available.";
        }
        List<StatusBarNotification> list = new ArrayList<>(recent.values());
        StringBuilder out = new StringBuilder();
        int start = Math.max(0, list.size() - 10);
        for (int i = list.size() - 1; i >= start; i--) {
            StatusBarNotification sbn = list.get(i);
            Bundle extras = sbn.getNotification().extras;
            CharSequence title = extras.getCharSequence(Notification.EXTRA_TITLE);
            CharSequence text = extras.getCharSequence(Notification.EXTRA_TEXT);
            if (out.length() > 0) out.append("\n");
            out.append(title == null ? sbn.getPackageName() : title);
            if (text != null && text.length() > 0) {
                out.append(": ").append(text);
            }
        }
        return out.toString();
    }

    public String dismissAllNow() {
        cancelAllNotifications();
        recent.clear();
        return "Notifications cleared.";
    }

    public synchronized String dismissFrom(String query) {
        String q = query.toLowerCase();
        int count = 0;
        List<Map.Entry<String, StatusBarNotification>> snapshot =
                new ArrayList<>(recent.entrySet());
        for (Map.Entry<String, StatusBarNotification> entry : snapshot) {
            StatusBarNotification sbn = entry.getValue();
            String pkg = sbn.getPackageName().toLowerCase();
            String label = pkg;
            try {
                label = getPackageManager()
                        .getApplicationLabel(getPackageManager().getApplicationInfo(sbn.getPackageName(), 0))
                        .toString().toLowerCase();
            } catch (Exception ignored) {
            }
            if (pkg.contains(q) || label.contains(q)) {
                cancelNotification(sbn.getKey());
                recent.remove(entry.getKey());
                count++;
            }
        }
        return count == 0 ? "No matching notifications found." : "Dismissed " + count + " notification(s).";
    }
}
