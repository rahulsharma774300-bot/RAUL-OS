package com.raul.os;

import android.Manifest;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.provider.ContactsContract;

public final class ContactHelper {
    private static final String TRUECALLER_PACKAGE = "com.truecaller";

    private ContactHelper() {}

    public static String dialContact(Context context, String name) {
        if (context.checkSelfPermission(Manifest.permission.READ_CONTACTS)
                != PackageManager.PERMISSION_GRANTED) {
            return "Contacts permission is not enabled.";
        }
        if (context.checkSelfPermission(Manifest.permission.CALL_PHONE)
                != PackageManager.PERMISSION_GRANTED) {
            return "Phone permission is not enabled. Open RAUL.OS once and grant Phone access.";
        }

        String number = null;
        String displayName = null;
        Cursor cursor = context.getContentResolver().query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                new String[]{
                        ContactsContract.CommonDataKinds.Phone.NUMBER,
                        ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME
                },
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " LIKE ?",
                new String[]{"%" + name + "%"},
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " ASC"
        );

        if (cursor != null) {
            try {
                if (cursor.moveToFirst()) {
                    number = cursor.getString(0);
                    displayName = cursor.getString(1);
                }
            } finally {
                cursor.close();
            }
        }

        if (number == null) {
            return "I couldn't find a contact named " + name + ".";
        }

        Uri uri = Uri.parse("tel:" + Uri.encode(number));
        Intent truecaller = new Intent(Intent.ACTION_CALL, uri);
        truecaller.setPackage(TRUECALLER_PACKAGE);
        truecaller.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);

        try {
            if (truecaller.resolveActivity(context.getPackageManager()) != null) {
                context.startActivity(truecaller);
                return "Calling " + displayName + " on Truecaller.";
            }
        } catch (Exception ignored) {
        }

        try {
            Intent generic = new Intent(Intent.ACTION_CALL, uri);
            generic.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(generic);
            return "Calling " + displayName + ". Set Truecaller as your default Phone app if you want calls to open there.";
        } catch (Exception e) {
            return "I couldn't start the call.";
        }
    }
}
