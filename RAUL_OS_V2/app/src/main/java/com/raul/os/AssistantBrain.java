package com.raul.os;

import android.content.Context;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.function.Consumer;

public final class AssistantBrain {
    private static final ExecutorService EXECUTOR = Executors.newSingleThreadExecutor();
    private static final String ENDPOINT = "https://api.openai.com/v1/responses";

    private AssistantBrain() {}

    public static void ask(Context context, String userText, Consumer<String> callback) {
        Context app = context.getApplicationContext();
        EXECUTOR.execute(() -> {
            String key = SecureStore.getApiKey(app);
            if (key == null || key.isBlank()) {
                callback.accept("My AI brain is not configured yet. Open RAUL.OS once and add your OpenAI API key.");
                return;
            }

            String model = app.getSharedPreferences("raul_settings", Context.MODE_PRIVATE)
                    .getString("brain_model", "gpt-5.6-luna");

            try {
                String answer = request(app, key, model, userText, shouldUseWeb(userText));
                ConversationHistory.add(app, "user", userText);
                ConversationHistory.add(app, "assistant", answer);
                callback.accept(answer);
            } catch (Exception first) {
                callback.accept("I couldn't reach my AI brain right now. " + compactError(first));
            }
        });
    }

    private static String request(Context context, String key, String model, String userText, boolean web) throws Exception {
        JSONObject body = new JSONObject();
        body.put("model", model);
        body.put("store", false);
        body.put("max_output_tokens", 350);
        body.put("instructions",
                "You are RAUL, a personal voice assistant on the user's Android phone. " +
                "Speak naturally, intelligently and concisely because your answer will be read aloud. " +
                "Reply in the same language/style as the user: English, Hindi, or natural Hinglish. " +
                "If the user speaks Hindi in Latin letters, answer in natural Hinglish using Latin letters. " +
                "If they use Devanagari, you may answer in Hindi Devanagari. " +
                "Usually answer in 1 to 4 spoken sentences unless the user asks for detail. " +
                "Do not claim that you performed a phone action unless the phone action layer actually did it. " +
                "Be useful, direct, conversational, and avoid markdown tables.");

        JSONArray input = new JSONArray();
        JSONArray history = ConversationHistory.load(context);
        for (int i = 0; i < history.length(); i++) {
            JSONObject old = history.optJSONObject(i);
            if (old == null) continue;
            JSONObject msg = new JSONObject();
            msg.put("role", old.optString("role", "user"));
            msg.put("content", old.optString("content", ""));
            input.put(msg);
        }

        JSONObject current = new JSONObject();
        current.put("role", "user");
        current.put("content", userText);
        input.put(current);
        body.put("input", input);

        if (web) {
            JSONArray tools = new JSONArray();
            JSONObject tool = new JSONObject();
            tool.put("type", "web_search");
            tools.put(tool);
            body.put("tools", tools);
        }

        HttpURLConnection connection = (HttpURLConnection) new URL(ENDPOINT).openConnection();
        connection.setConnectTimeout(15000);
        connection.setReadTimeout(45000);
        connection.setRequestMethod("POST");
        connection.setDoOutput(true);
        connection.setRequestProperty("Authorization", "Bearer " + key);
        connection.setRequestProperty("Content-Type", "application/json");

        try (OutputStream out = connection.getOutputStream()) {
            out.write(body.toString().getBytes(StandardCharsets.UTF_8));
        }

        int code = connection.getResponseCode();
        InputStream stream = code >= 200 && code < 300
                ? connection.getInputStream()
                : connection.getErrorStream();
        String raw = readAll(stream);

        if (code < 200 || code >= 300) {
            if (web) {
                return request(context, key, model, userText, false);
            }
            throw new IllegalStateException("API error " + code + ": " + trim(raw, 220));
        }

        JSONObject json = new JSONObject(raw);
        String text = extractOutputText(json);
        if (text == null || text.isBlank()) {
            throw new IllegalStateException("The AI returned no spoken answer.");
        }
        return text.trim();
    }

    private static String extractOutputText(JSONObject json) {
        JSONArray output = json.optJSONArray("output");
        if (output == null) return null;

        StringBuilder result = new StringBuilder();
        for (int i = 0; i < output.length(); i++) {
            JSONObject item = output.optJSONObject(i);
            if (item == null || !"message".equals(item.optString("type"))) continue;
            JSONArray content = item.optJSONArray("content");
            if (content == null) continue;
            for (int j = 0; j < content.length(); j++) {
                JSONObject part = content.optJSONObject(j);
                if (part == null) continue;
                if ("output_text".equals(part.optString("type"))) {
                    String text = part.optString("text", "");
                    if (!text.isBlank()) {
                        if (result.length() > 0) result.append(" ");
                        result.append(text);
                    }
                }
            }
        }
        return result.toString();
    }

    private static boolean shouldUseWeb(String text) {
        String q = text.toLowerCase(Locale.ROOT);
        String[] current = {
                "weather", "temperature", "news", "latest", "today", "tonight",
                "price", "score", "match", "stock", "market", "current", "right now",
                "aaj", "mausam", "khabar", "latest"
        };
        for (String term : current) {
            if (q.contains(term)) return true;
        }
        return false;
    }

    private static String readAll(InputStream stream) throws Exception {
        if (stream == null) return "";
        StringBuilder out = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(stream, StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) out.append(line);
        }
        return out.toString();
    }

    private static String compactError(Exception e) {
        String message = e.getMessage();
        if (message == null || message.isBlank()) return e.getClass().getSimpleName();
        return trim(message, 180);
    }

    private static String trim(String value, int max) {
        if (value == null) return "";
        return value.length() <= max ? value : value.substring(0, max) + "…";
    }
}
