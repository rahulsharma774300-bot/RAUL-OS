package com.raul.os;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ServiceInfo;
import android.media.AudioAttributes;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import android.speech.tts.TextToSpeech;
import android.speech.tts.UtteranceProgressListener;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.Locale;
import java.util.UUID;

public class JarvisService extends Service implements RecognitionListener, TextToSpeech.OnInitListener {
    public static final String ACTION_START = "com.raul.os.action.START_JARVIS";
    public static final String ACTION_STOP = "com.raul.os.action.STOP_JARVIS";
    public static final String PREFS = "raul_settings";
    public static final String KEY_ENABLED = "jarvis_enabled";

    private static final String CHANNEL = "raul_jarvis";
    private static final int NOTIFICATION_ID = 3001;

    private final Handler handler = new Handler(Looper.getMainLooper());
    private final Runnable listenRunnable = this::startListening;
    private SpeechRecognizer recognizer;
    private Intent recognizerIntent;
    private TextToSpeech tts;
    private boolean ttsReady = false;
    private boolean listening = false;
    private boolean speaking = false;
    private boolean shuttingDown = false;
    private long conversationUntil = 0L;

    @Override
    public void onCreate() {
        super.onCreate();
        createChannel();
        tts = new TextToSpeech(this, this);
        setupRecognizer();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        String action = intent == null ? ACTION_START : intent.getAction();
        if (ACTION_STOP.equals(action)) {
            getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean(KEY_ENABLED, false).apply();
            shuttingDown = true;
            stopListening();
            stopForeground(STOP_FOREGROUND_REMOVE);
            stopSelf();
            return START_NOT_STICKY;
        }

        getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean(KEY_ENABLED, true).apply();
        startAsForeground();
        scheduleListen(300);
        return START_STICKY;
    }

    private void startAsForeground() {
        Intent open = new Intent(this, MainActivity.class);
        PendingIntent openPi = PendingIntent.getActivity(
                this, 1, open,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        Intent stop = new Intent(this, JarvisService.class).setAction(ACTION_STOP);
        PendingIntent stopPi = PendingIntent.getService(
                this, 2, stop,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        Notification.Builder builder = new Notification.Builder(this, CHANNEL)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle("RAUL is listening")
                .setContentText("Say “Hey Raul” and then your command.")
                .setOngoing(true)
                .setContentIntent(openPi)
                .addAction(new Notification.Action.Builder(
                        null, "Stop listening", stopPi).build());

        Notification notification = builder.build();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE);
        } else {
            startForeground(NOTIFICATION_ID, notification);
        }
    }

    private void createChannel() {
        NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        NotificationChannel channel = new NotificationChannel(
                CHANNEL, "RAUL always-listening assistant", NotificationManager.IMPORTANCE_LOW);
        channel.setDescription("Required while RAUL listens for the wake phrase.");
        nm.createNotificationChannel(channel);
    }

    private void setupRecognizer() {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) return;
        recognizer = SpeechRecognizer.createSpeechRecognizer(this);
        recognizer.setRecognitionListener(this);
        recognizerIntent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        recognizerIntent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true);
        recognizerIntent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5);
        recognizerIntent.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, getPackageName());
    }

    private void scheduleListen(long delayMs) {
        handler.removeCallbacks(listenRunnable);
        handler.postDelayed(listenRunnable, delayMs);
    }

    private void startListening() {
        if (shuttingDown || speaking || listening) return;
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            Toast.makeText(this, "RAUL needs microphone permission.", Toast.LENGTH_LONG).show();
            return;
        }
        if (recognizer == null) {
            setupRecognizer();
            if (recognizer == null) return;
        }

        try {
            listening = true;
            recognizer.startListening(recognizerIntent);
        } catch (Exception e) {
            listening = false;
            scheduleListen(1200);
        }
    }

    private void stopListening() {
        listening = false;
        if (recognizer != null) {
            try { recognizer.cancel(); } catch (Exception ignored) {}
        }
    }

    private void processTranscript(String transcript) {
        if (transcript == null || transcript.isBlank()) {
            scheduleListen(300);
            return;
        }

        String original = transcript.trim();
        String lower = original.toLowerCase(Locale.ROOT);
        String command = null;

        String[] wakes = {
                "hey raul", "hey rahul", "hi raul", "hi rahul",
                "raul", "rahul", "हे राउल", "हाय राउल", "राउल", "राहुल"
        };

        for (String wake : wakes) {
            int idx = lower.indexOf(wake);
            if (idx >= 0 && idx <= 6) {
                command = original.substring(Math.min(original.length(), idx + wake.length())).trim();
                break;
            }
        }

        if (command == null) {
            if (System.currentTimeMillis() < conversationUntil) {
                command = original;
            } else {
                scheduleListen(250);
                return;
            }
        }

        conversationUntil = System.currentTimeMillis() + 30000;

        if (command.isBlank()) {
            speak("Haan, bolo.");
            return;
        }

        final String spokenCommand = command;
        String normalized = normalizeNaturalCommand(spokenCommand);
        stopListening();

        if (normalized.equalsIgnoreCase("stop listening")
                || normalized.equalsIgnoreCase("go to sleep")
                || normalized.equalsIgnoreCase("sleep")) {
            speakThenStop("Okay. Going quiet.");
            return;
        }

        CommandRouter.executeAsync(this, normalized, result ->
                handler.post(() -> {
                    if (result != null && result.startsWith("Unknown command.")) {
                        AssistantBrain.ask(this, spokenCommand,
                                answer -> handler.post(() -> speak(answer)));
                    } else {
                        speak(result);
                    }
                }));
    }

    private String normalizeNaturalCommand(String command) {
        String lower = command.toLowerCase(Locale.ROOT).trim();

        if (lower.startsWith("open truecaller and call ")) {
            return "call " + command.substring("open truecaller and call ".length()).trim();
        }
        if (lower.startsWith("truecaller call ")) {
            return "call " + command.substring("truecaller call ".length()).trim();
        }
        if (lower.startsWith("call ") && lower.endsWith(" using truecaller")) {
            return command.substring(0, command.length() - " using truecaller".length()).trim();
        }

        String[] callEndings = {" ko call karo", " ko call kar do", " ko phone karo", " को कॉल करो", " को फोन करो"};
        for (String ending : callEndings) {
            if (lower.endsWith(ending) && command.length() > ending.length()) {
                return "call " + command.substring(0, command.length() - ending.length()).trim();
            }
        }

        if (lower.endsWith(" kholo") && command.length() > 6) {
            return "open " + command.substring(0, command.length() - 6).trim();
        }
        if (lower.endsWith(" खोलो") && command.length() > 5) {
            return "open " + command.substring(0, command.length() - 5).trim();
        }

        if (lower.contains("brightness")) {
            Integer value = firstNumber(lower);
            if (value != null) return "brightness " + value;
        }
        if (lower.contains("volume")) {
            Integer value = firstNumber(lower);
            if (value != null) return "volume " + value;
        }

        if (lower.equals("what is the time")
                || lower.equals("what's the time")
                || lower.equals("tell me the time")
                || lower.equals("tell me time")
                || lower.equals("time kya hai")
                || lower.equals("time batao")
                || lower.equals("kitne baje hain")
                || lower.equals("कितने बजे हैं")
                || lower.equals("समय बताओ")) {
            return "time";
        }

        if (lower.contains("battery") && (lower.contains("kitni") || lower.contains("level") || lower.contains("percent"))) {
            return "battery";
        }

        if (lower.equals("torch on") || lower.equals("flashlight chalao") || lower.equals("torch chalao")) {
            return "flashlight on";
        }
        if (lower.equals("torch off") || lower.equals("flashlight band karo") || lower.equals("torch band karo")) {
            return "flashlight off";
        }

        return command;
    }

    private Integer firstNumber(String text) {
        java.util.regex.Matcher matcher = java.util.regex.Pattern.compile("(\\d{1,3})").matcher(text);
        if (!matcher.find()) return null;
        try {
            return Math.max(0, Math.min(100, Integer.parseInt(matcher.group(1))));
        } catch (Exception e) {
            return null;
        }
    }

    private void speak(String text) {
        if (text == null || text.isBlank()) {
            scheduleListen(300);
            return;
        }
        if (!ttsReady) {
            Toast.makeText(this, text, Toast.LENGTH_LONG).show();
            scheduleListen(800);
            return;
        }

        stopListening();
        speaking = true;
        String clean = cleanForSpeech(text);

        if (containsDevanagari(clean)) {
            int result = tts.setLanguage(new Locale("hi", "IN"));
            if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                tts.setLanguage(new Locale("en", "IN"));
            }
        } else {
            tts.setLanguage(new Locale("en", "IN"));
        }

        Bundle params = new Bundle();
        params.putInt(TextToSpeech.Engine.KEY_PARAM_STREAM, android.media.AudioManager.STREAM_MUSIC);
        String id = UUID.randomUUID().toString();
        tts.speak(clean, TextToSpeech.QUEUE_FLUSH, params, id);
    }

    private void speakThenStop(String text) {
        shuttingDown = true;
        if (!ttsReady) {
            stopForeground(STOP_FOREGROUND_REMOVE);
            stopSelf();
            return;
        }
        speaking = true;
        tts.setLanguage(new Locale("en", "IN"));
        String id = "stop-" + UUID.randomUUID();
        tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, id);
    }

    private String cleanForSpeech(String text) {
        return text.replace("**", "")
                .replace("\u0060", "")
                .replace("#", "")
                .replaceAll("\\[(.*?)\\]\\((.*?)\\)", "$1")
                .trim();
    }

    private boolean containsDevanagari(String text) {
        for (int i = 0; i < text.length(); i++) {
            char c = text.charAt(i);
            if (c >= '\u0900' && c <= '\u097F') return true;
        }
        return false;
    }

    @Override
    public void onInit(int status) {
        if (status == TextToSpeech.SUCCESS) {
            ttsReady = true;
            tts.setLanguage(new Locale("en", "IN"));
            tts.setSpeechRate(1.0f);
            tts.setPitch(1.0f);
            tts.setAudioAttributes(new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build());
            tts.setOnUtteranceProgressListener(new UtteranceProgressListener() {
                @Override public void onStart(String utteranceId) {}

                @Override
                public void onDone(String utteranceId) {
                    handler.post(() -> {
                        speaking = false;
                        if (utteranceId != null && utteranceId.startsWith("stop-")) {
                            getSharedPreferences(PREFS, MODE_PRIVATE)
                                    .edit().putBoolean(KEY_ENABLED, false).apply();
                            stopForeground(STOP_FOREGROUND_REMOVE);
                            stopSelf();
                        } else {
                            scheduleListen(350);
                        }
                    });
                }

                @Override
                public void onError(String utteranceId) {
                    handler.post(() -> {
                        speaking = false;
                        scheduleListen(500);
                    });
                }
            });
        }
    }

    @Override public void onReadyForSpeech(Bundle params) {}
    @Override public void onBeginningOfSpeech() {}
    @Override public void onRmsChanged(float rmsdB) {}
    @Override public void onBufferReceived(byte[] buffer) {}

    @Override
    public void onEndOfSpeech() {
        listening = false;
    }

    @Override
    public void onError(int error) {
        listening = false;
        if (!speaking && !shuttingDown) {
            long delay = (error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY) ? 1200 : 500;
            scheduleListen(delay);
        }
    }

    @Override
    public void onResults(Bundle results) {
        listening = false;
        ArrayList<String> matches = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
        processTranscript(matches == null || matches.isEmpty() ? null : matches.get(0));
    }

    @Override
    public void onPartialResults(Bundle partialResults) {}

    @Override
    public void onEvent(int eventType, Bundle params) {}

    @Override
    public void onDestroy() {
        shuttingDown = true;
        handler.removeCallbacksAndMessages(null);
        stopListening();
        if (recognizer != null) {
            try { recognizer.destroy(); } catch (Exception ignored) {}
            recognizer = null;
        }
        if (tts != null) {
            try { tts.stop(); tts.shutdown(); } catch (Exception ignored) {}
            tts = null;
        }
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
