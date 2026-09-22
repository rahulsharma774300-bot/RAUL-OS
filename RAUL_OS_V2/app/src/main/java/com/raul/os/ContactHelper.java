package com.raul.os;

import android.Manifest;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.provider.ContactsContract;

public final class ContactHelper {
    private ContactHelper() {}

    public static String dialContact(Context context, String name) {
        if (context.checkSelfPermission(Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
            return "Contacts permission is not enabled.";
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
            return "No contact found for " + name + ".";
        }

        Intent intent = new Intent(Intent.ACTION_DIAL, Uri.parse("tel:" + Uri.encode(number)));
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(intent);
        return "Opened dialer for " + displayName + ".";
    }
}
