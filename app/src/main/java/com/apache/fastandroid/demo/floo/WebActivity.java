/*
 * Copyright 2017 drakeet. https://github.com/drakeet
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.apache.fastandroid.demo.floo;

import android.annotation.SuppressLint;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.view.animation.AlphaAnimation;
import android.view.animation.Animation;
import android.view.animation.ScaleAnimation;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.TextView;

import com.apache.fastandroid.R;

import java.util.Arrays;
import java.util.List;
import java.util.Locale;

import androidx.appcompat.app.AppCompatActivity;

public class WebActivity extends AppCompatActivity {

  private static final String URL = "url";

  // 仅允许在应用内 WebView 加载的安全 scheme，挡住 javascript:/file:/content:/intent: 等注入与本地文件读取面
  private static final List<String> ALLOWED_SCHEMES = Arrays.asList("http", "https");

  // host 白名单：为空表示不按 host 限制（演示工程默认，避免破坏各 demo 的通用加载）。
  // 安全收紧时可在此填入可信域名（小写），仅放行这些 host 的页面在应用内加载，例如 "www.wanandroid.com"、"github.com"。
  private static final List<String> ALLOWED_HOSTS = Arrays.asList();

  private TextView loading;

  @Override
  @SuppressLint("SetJavaScriptEnabled")
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    setContentView(R.layout.activity_web);
    WebView webView = (WebView) findViewById(R.id.web_view);

    // 区分来源：getStringExtra 为应用内部调用；getData 为外部可控的 deeplink（BROWSABLE），属攻击面，需更严格校验
    String url = getIntent().getStringExtra(URL);
    boolean fromDeepLink = false;
    if (url == null && getIntent().getData() != null) {
      url = getIntent().getData().getQueryParameter(URL);
      fromDeepLink = true;
    }

    // 校验 url：scheme 必须合法；外部 deeplink 还需通过 host 白名单（若已配置）。
    // 不合法直接结束（含原本 url==null 未 return 会 loadUrl(null) 崩溃的隐患），避免加载攻击者控制的页面
    if (!isAllowedUrl(url, fromDeepLink)) {
      finish();
      return;
    }

    webView.setWebViewClient(new InnerWebViewClient());
    webView.getSettings().setJavaScriptEnabled(true);
    webView.loadUrl(url);

    loading = (TextView) findViewById(R.id.loading);
    Animation animation = new ScaleAnimation(1.0f, 1.2f, 1.0f, 1.2f,
        Animation.RELATIVE_TO_SELF, 0.5f, Animation.RELATIVE_TO_SELF, 0.5f);
    animation.setRepeatMode(Animation.REVERSE);
    animation.setRepeatCount(Animation.INFINITE);
    animation.setDuration(500);
    loading.startAnimation(animation);
    setTitle(url);
  }

  /**
   * 校验 url 是否允许在应用内 WebView 加载。
   *
   * @param url                  待加载链接
   * @param enforceHostWhitelist 是否强制 host 白名单（外部 deeplink 来源时为 true）
   * @return scheme 合法（http/https）且（必要时）host 在白名单内才返回 true
   */
  private static boolean isAllowedUrl(String url, boolean enforceHostWhitelist) {
    if (url == null || url.trim().isEmpty()) {
      return false;
    }
    Uri uri = Uri.parse(url);
    String scheme = uri.getScheme();
    if (scheme == null || !ALLOWED_SCHEMES.contains(scheme.toLowerCase(Locale.ROOT))) {
      return false;
    }
    if (enforceHostWhitelist && !ALLOWED_HOSTS.isEmpty()) {
      String host = uri.getHost();
      return host != null && ALLOWED_HOSTS.contains(host.toLowerCase(Locale.ROOT));
    }
    return true;
  }

  public class InnerWebViewClient extends WebViewClient {

    @Override @SuppressWarnings("deprecation")
    public boolean shouldOverrideUrlLoading(WebView view, String url) {
      // 页内跳转同样按 scheme 白名单校验：合法则应用内加载；否则（如 tel:/mailto: 或不可信 scheme）交给系统处理，不在本 WebView 直接加载
      if (isAllowedUrl(url, false)) {
        view.loadUrl(url);
      } else {
        try {
          startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
        } catch (Exception ignored) {
          // 系统无法处理的 scheme 直接忽略，避免崩溃
        }
      }
      return true;
    }

    @Override
    public void onPageCommitVisible(WebView view, String url) {
      super.onPageCommitVisible(view, url);
      loading.clearAnimation();
      loading.setVisibility(View.GONE);
      view.setVisibility(View.VISIBLE);
      Animation animation = new AlphaAnimation(0.1f, 1.0f);
      animation.setDuration(5000);
      view.setAnimation(animation);
      setTitle(view.getTitle());
    }
  }
}
