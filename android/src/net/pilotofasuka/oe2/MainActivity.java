package net.pilotofasuka.oe2;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.os.Build;
import android.view.WindowInsets;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.Toast;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.Collections;

/** Private offline test shell. The packaged browser game remains the BREW core. */
public final class MainActivity extends Activity {
    private static final String HOST = "appassets.androidplatform.net";
    private static final String HOME = "https://" + HOST + "/assets/index.html";
    private static final int IMPORT_SAVE = 1, EXPORT_SAVE = 2;
    private WebView game;
    private FrameLayout root;
    private ValueCallback<Uri[]> fileCallback;
    private String pendingBackup;
    private View fullscreen;
    private WebChromeClient.CustomViewCallback fullscreenCallback;

    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        root = new FrameLayout(this);
        root.setBackgroundColor(Color.rgb(9,18,13));
        setContentView(root);
        root.setOnApplyWindowInsetsListener((view,insets) -> {
            if (Build.VERSION.SDK_INT >= 30) {
                android.graphics.Insets safe=insets.getInsets(WindowInsets.Type.systemBars()|WindowInsets.Type.displayCutout());
                root.setPadding(safe.left,safe.top,safe.right,safe.bottom);
            } else {
                int left=insets.getSystemWindowInsetLeft(),top=insets.getSystemWindowInsetTop(),right=insets.getSystemWindowInsetRight(),bottom=insets.getSystemWindowInsetBottom();
                if(Build.VERSION.SDK_INT>=28&&insets.getDisplayCutout()!=null){android.view.DisplayCutout cut=insets.getDisplayCutout();left=Math.max(left,cut.getSafeInsetLeft());top=Math.max(top,cut.getSafeInsetTop());right=Math.max(right,cut.getSafeInsetRight());bottom=Math.max(bottom,cut.getSafeInsetBottom());}
                root.setPadding(left,top,right,bottom);
            }
            return insets;
        });
        game = new WebView(this);
        game.setBackgroundColor(Color.rgb(9,18,13));
        root.addView(game, new FrameLayout.LayoutParams(-1,-1));
        WebSettings settings = game.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(true); // Only user-selected backup documents.
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setMediaPlaybackRequiresUserGesture(true);
        settings.setSupportMultipleWindows(false);
        settings.setBuiltInZoomControls(false);
        settings.setDisplayZoomControls(false);
        game.addJavascriptInterface(new SaveBridge(), "BrewAndroid");
        game.setWebViewClient(new WebViewClient() {
            @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                return !local(request.getUrl());
            }
            @Override public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                String path = uri.getPath();
                if (!local(uri) || path == null || !path.startsWith("/assets/") || path.contains("..")) return missing();
                String file = path.substring(8);
                try {
                    InputStream stream = getAssets().open("game/" + file);
                    WebResourceResponse response = new WebResourceResponse(mime(file), null, stream);
                    response.setResponseHeaders(Collections.singletonMap("Cache-Control", "no-cache"));
                    return response;
                } catch (Exception ignored) { return missing(); }
            }
        });
        game.setWebChromeClient(new WebChromeClient() {
            @Override public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback, FileChooserParams parameters) {
                if (fileCallback != null) fileCallback.onReceiveValue(null);
                fileCallback = callback;
                Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                intent.setType("*/*");
                intent.putExtra(Intent.EXTRA_MIME_TYPES, new String[]{"application/json","text/plain","application/octet-stream"});
                try { startActivityForResult(intent, IMPORT_SAVE); }
                catch (Exception error) { fileCallback.onReceiveValue(null); fileCallback=null; }
                return true;
            }
            @Override public void onShowCustomView(View view, CustomViewCallback callback) {
                if (fullscreen != null) { callback.onCustomViewHidden(); return; }
                fullscreen = view; fullscreenCallback = callback;
                root.addView(view, new FrameLayout.LayoutParams(-1,-1));game.setVisibility(View.INVISIBLE);immersive();
            }
            @Override public void onHideCustomView() { hideFullscreen(); }
        });
        immersive();
        game.loadUrl(HOME);
    }
    private static boolean local(Uri uri) { return "https".equals(uri.getScheme()) && HOST.equals(uri.getHost()); }
    private static WebResourceResponse missing() {
        return new WebResourceResponse("text/plain", "UTF-8", 404, "Not Found", Collections.emptyMap(),
                new ByteArrayInputStream(new byte[0]));
    }
    private static String mime(String file) {
        if (file.endsWith(".html")) return "text/html";
        if (file.endsWith(".js")) return "application/javascript";
        if (file.endsWith(".wasm")) return "application/wasm";
        if (file.endsWith(".json")) return "application/json";
        if (file.endsWith(".png")) return "image/png";
        if (file.endsWith(".svg")) return "image/svg+xml";
        return "application/octet-stream";
    }
    private void immersive() {
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_FULLSCREEN |
            View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY |
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
    }
    private void hideFullscreen() {
        if (fullscreen == null) return;
        root.removeView(fullscreen);fullscreen=null;game.setVisibility(View.VISIBLE);
        if (fullscreenCallback != null) fullscreenCallback.onCustomViewHidden();fullscreenCallback=null;immersive();
    }
    public final class SaveBridge {
        @JavascriptInterface public void saveBackup(String filename, String json) {
            if (json == null || json.length() > 8000000) return;
            runOnUiThread(() -> {
                if (pendingBackup != null) return;
                pendingBackup=json;
                Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);intent.setType("application/json");
                intent.putExtra(Intent.EXTRA_TITLE, filename.replaceAll("[^a-zA-Z0-9_.-]", "_"));
                try { startActivityForResult(intent, EXPORT_SAVE); }
                catch (Exception error) { pendingBackup=null;report("Не удалось скачать сохранение"); }
            });
        }
    }
    private void report(String text) {
        game.evaluateJavascript("if(window.Brew)Brew.backupStatus=" + org.json.JSONObject.quote(text), null);
    }
    @Override protected void onActivityResult(int request, int result, Intent data) {
        super.onActivityResult(request,result,data);
        if (request == IMPORT_SAVE && fileCallback != null) {
            Uri uri = result == RESULT_OK && data != null ? data.getData() : null;
            fileCallback.onReceiveValue(uri == null ? null : new Uri[]{uri});fileCallback=null;
        }
        if (request == EXPORT_SAVE && pendingBackup != null) {
            if (result == RESULT_OK && data != null && data.getData() != null) {
                try (OutputStream out = getContentResolver().openOutputStream(data.getData())) {
                    if (out == null) throw new java.io.IOException();
                    out.write(pendingBackup.getBytes(StandardCharsets.UTF_8));
                    report("Копия сохранения скачана");
                } catch (Exception error) { report("Не удалось скачать сохранение");Toast.makeText(this,"Save export failed",Toast.LENGTH_LONG).show(); }
            } else report("");
            pendingBackup=null;
        }
        immersive();
    }
    @Override public void onBackPressed() {
        if (fullscreen != null) { hideFullscreen(); return; }
        game.evaluateJavascript("if(window.Brew&&Brew.ready){var s=JSON.parse(Brew.json()).state;" +
            "if(s===19)Brew.key(0xe030);else if(s===2||s===7)Brew.key(0xe036);else Brew.action(5);}",null);
    }
    @Override public void onWindowFocusChanged(boolean focused) { super.onWindowFocusChanged(focused);if(focused)immersive(); }
    @Override protected void onPause() {
        if(game!=null){game.evaluateJavascript("if(window.Brew){Brew.paused=true;Brew.flush();}if(window.BrewAudio&&BrewAudio.context)BrewAudio.context.suspend();",null);game.onPause();game.pauseTimers();}
        super.onPause();
    }
    @Override protected void onResume() { super.onResume();if(game!=null){game.onResume();game.resumeTimers();} }
    @Override protected void onDestroy() {
        if(fileCallback!=null)fileCallback.onReceiveValue(null);
        if(game!=null){game.removeJavascriptInterface("BrewAndroid");game.destroy();}
        super.onDestroy();
    }
}
