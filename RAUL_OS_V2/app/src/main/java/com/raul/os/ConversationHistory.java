package com.raul.os;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONObject;

public final class ConversationHistory {
    private static final String STORE = "raul_brain_history";
    private static final String KEY = "history";
    private static final int MAX_MESSAGES = 12;

    private ConversationHistory() {}

    public static synchronized JSONArray load(Context context) {
        String raw = context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
                .getString(KEY, "[]");
        try {
            return new JSONArray(raw);
        } catch (Exception e) {
            return new JSONArray();
        }
    }

    public static synchronized void add(Context context, String role, String content) {
        JSONArray old = load(context);
        JSONArray trimmed = new JSONArray();

        int start = Math.max(0, old.length() - (MAX_MESSAGES - 1));
        for (int i = start; i < old.length(); i++) {
            trimmed.put(old.opt(i));
        }

        JSONObject item = new JSONObject();
        try {
            item.put("role", role);
            item.put("content", content);
            trimmed.put(item);
        } catch (Exception ignored) {
        }

        context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
                .edit().putString(KEY, trimmed.toString()).apply();
    }

    public static synchronized void clear(Context context) {
        context.getSharedPreferences(STORE, Context.MODE_PRIVATE)
                .edit().remove(KEY).apply();
    }
}
