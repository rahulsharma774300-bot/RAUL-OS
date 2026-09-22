package com.raul.os;

import android.content.Context;
import android.content.pm.PackageManager;

public final class ShizukuBridge {
    private ShizukuBridge() {}

    public static String status(Context context) {
        boolean appInstalled = false;
        try {
            context.getPackageManager().getPackageInfo("moe.shizuku.privileged.api", 0);
            appInstalled = true;
        } catch (PackageManager.NameNotFoundException ignored) {
        }

        boolean apiOnClasspath;
        try {
            Class.forName("rikka.shizuku.Shizuku");
            apiOnClasspath = true;
        } catch (ClassNotFoundException e) {
            apiOnClasspath = false;
        }

        if (appInstalled && apiOnClasspath) {
            return "Shizuku app and API detected.";
        }
        if (appInstalled) {
            return "Shizuku app detected. RAUL.OS has a privileged-action bridge boundary ready, but the optional Shizuku API module is not bundled in this build.";
        }
        return "Shizuku is not installed. RAUL.OS is currently using normal Android permissions and Accessibility.";
    }
}
