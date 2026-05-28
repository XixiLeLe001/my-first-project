import SwiftUI
import UIKit
import WebKit

struct JDLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AccountStore
    @State private var status = "等待登录..."
    @State private var isUploading = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text("京东登录")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button {
                    status = "正在刷新抓取..."
                } label: {
                    Label("刷新抓取", systemImage: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 22)
            .background(Color(red: 0.08, green: 0.09, blue: 0.17))

            JDWebView(status: $status) { cookie in
                handleCookie(cookie)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                    Text(status)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    if isUploading {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .padding(.horizontal, 22)
                .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
                .background(Color(red: 0.08, green: 0.09, blue: 0.17))
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func handleCookie(_ cookie: String) {
        guard !isUploading else { return }
        isUploading = true
        status = "检测到登录，正在上传数据..."

        Task { @MainActor in
            do {
                try await store.uploadCookie(cookie)
                status = "上传数据成功"
                try? await Task.sleep(nanoseconds: 700_000_000)
                dismiss()
            } catch {
                status = error.localizedDescription == "服务器已失联" ? "服务器已失联" : "上传失败，请稍后重试"
                store.showToast(status)
                isUploading = false
            }
        }
    }
}

struct JDWebView: UIViewRepresentable {
    @Binding var status: String
    let onCookie: (String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        webView.load(URLRequest(url: LeSciConfig.loginURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private var parent: JDWebView
        private var didCapture = false

        init(parent: JDWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            scanCookies(in: webView)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            webView.reload()
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let scheme = url.scheme?.lowercased() ?? ""
            if scheme == "http" || scheme == "https" || scheme == "about" {
                decisionHandler(.allow)
                return
            }

            if scheme.hasPrefix("mqq") || scheme == "wtloginmqq" {
                DispatchQueue.main.async {
                    UIApplication.shared.open(url)
                    self.parent.status = "已唤起 QQ，授权后会继续检测登录"
                }
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.cancel)
        }

        private func scanCookies(in webView: WKWebView) {
            guard !didCapture else { return }
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self else { return }
                if let cookie = CookieTools.cookieText(from: cookies) {
                    self.didCapture = true
                    DispatchQueue.main.async {
                        self.parent.status = "检测到登录，正在上传数据..."
                        self.parent.onCookie(cookie)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.parent.status = "等待登录..."
                    }
                }
            }
        }
    }
}
