package com.raul.os;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.drawable.GradientDrawable;
import android.os.IBinder;
import android.provider.Settings;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.widget.TextView;
import android.widget.Toast;

public class OrbService extends Service {
    private static final String CHANNEL = "raul_orb";
    private WindowManager windowManager;
    private View orb;
    private WindowManager.LayoutParams params;

    @Override
    public void onCreate() {
        super.onCreate();
        createChannel();

        Intent mainIntent = new Intent(this, MainActivity.class);
        PendingIntent pending = PendingIntent.getActivity(
                this, 0, mainIntent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        Notification notification = new Notification.Builder(this, CHANNEL)
                .setContentTitle("RAUL.OS orb is active")
                .setContentText("Tap the floating R to speak a command.")
                .setSmallIcon(R.drawable.ic_notification)
                .setContentIntent(pending)
                .setOngoing(true)
                .build();
        startForeground(1001, notification);

        if (!Settings.canDrawOverlays(this)) {
            Toast.makeText(this, "Enable Display over other apps for RAUL.OS.", Toast.LENGTH_LONG).show();
            stopSelf();
            return;
        }

        windowManager = (WindowManager) getSystemService(WINDOW_SERVICE);
        TextView view = new TextView(this);
        view.setText("R");
        view.setTextColor(Color.WHITE);
        view.setTextSize(23f);
        view.setGravity(Gravity.CENTER);

        GradientDrawable bg = new GradientDrawable();
        bg.setShape(GradientDrawable.OVAL);
        bg.setColor(Color.rgb(12, 106, 145));
        bg.setStroke(dp(2), Color.rgb(78, 219, 255));
        view.setBackground(bg);

        int size = dp(64);
        params = new WindowManager.LayoutParams(
                size, size,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                        | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT);
        params.gravity = Gravity.TOP | Gravity.START;
        params.x = dp(16);
        params.y = dp(180);

        view.setOnTouchListener(new View.OnTouchListener() {
            int startX, startY;
            float touchX, touchY;
            long downAt;

            @Override
            public boolean onTouch(View v, MotionEvent event) {
                switch (event.getAction()) {
                    case MotionEvent.ACTION_DOWN:
                        startX = params.x;
                        startY = params.y;
                        touchX = event.getRawX();
                        touchY = event.getRawY();
                        downAt = System.currentTimeMillis();
                        return true;
                    case MotionEvent.ACTION_MOVE:
                        params.x = startX + (int) (event.getRawX() - touchX);
                        params.y = startY + (int) (event.getRawY() - touchY);
                        windowManager.updateViewLayout(orb, params);
                        return true;
                    case MotionEvent.ACTION_UP:
                        float dx = Math.abs(event.getRawX() - touchX);
                        float dy = Math.abs(event.getRawY() - touchY);
                        if (dx < dp(10) && dy < dp(10)
                                && System.currentTimeMillis() - downAt < 700) {
                            Intent voice = new Intent(OrbService.this, VoiceCommandActivity.class);
                            voice.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                            startActivity(voice);
                        }
                        return true;
                    default:
                        return false;
                }
            }
        });

        orb = view;
        windowManager.addView(orb, params);
    }

    private void createChannel() {
        NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        NotificationChannel channel = new NotificationChannel(
                CHANNEL, "RAUL.OS floating assistant", NotificationManager.IMPORTANCE_LOW);
        nm.createNotificationChannel(channel);
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    @Override
    public void onDestroy() {
        if (windowManager != null && orb != null) {
            try {
                windowManager.removeView(orb);
            } catch (Exception ignored) {
            }
        }
        orb = null;
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
