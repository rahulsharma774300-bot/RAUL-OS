package com.raul.os;

import android.content.Context;
import android.content.SharedPreferences;

public final class LocalMemory {
    private static final String PREFS = "raul_os_memory";

    private LocalMemory() {}

    private static SharedPreferences prefs(Context context) {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    private static String key(String value) {
        return value == null ? "" : value.trim().toLowerCase();
    }

    public static void putAlias(Context context, String phrase, String command) {
        prefs(context).edit().putString("alias_" + key(phrase), command.trim()).apply();
    }

    public static String getAlias(Context context, String phrase) {
        return prefs(context).getString("alias_" + key(phrase), null);
    }

    public static void remember(Context context, String name, String value) {
        prefs(context).edit().putString("mem_" + key(name), value.trim()).apply();
    }

    public static String recall(Context context, String name) {
        return prefs(context).getString("mem_" + key(name), null);
    }
}
