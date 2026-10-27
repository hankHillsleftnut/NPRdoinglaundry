import SwiftUI
import WebKit

struct MarkdownView: UIViewRepresentable {
    let markdownString: String

    func makeUIView(context: Context) -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = false

        // Add navigation delegate to track loading
        webView.navigationDelegate = context.coordinator

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Log the original markdown for debugging
        print("🔍 Original Markdown: \(markdownString)")

        let htmlString = convertMarkdownToHTML(markdownString)

        // Log the generated HTML
        print("🌐 Generated HTML: \(htmlString)")

        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                html, body {
                    margin: 0;
                    padding: 10px;
                    width: 100%;
                    background-color: transparent;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', 'Helvetica Neue', sans-serif;
                    color: #e0e0e0;
                    line-height: 1.6;
                    font-size: 15px;
                    word-wrap: break-word;
                }
                h1 { 
                    color: #4287f5; 
                    font-size: 20px; 
                    margin-bottom: 10px;
                    margin-top: 0;
                    font-weight: 700;
                }
                h2 { 
                    color: #4287f5; 
                    font-size: 18px; 
                    margin-top: 10px; 
                    margin-bottom: 8px;
                    font-weight: 600;
                }
                h3 { 
                    color: #4287f5; 
                    font-size: 16px; 
                    margin-top: 8px; 
                    margin-bottom: 6px;
                    font-weight: 500;
                }
                strong { 
                    color: #4287f5; 
                    font-weight: 600;
                }
                ul { 
                    padding-left: 20px; 
                    margin: 8px 0;
                }
                li { 
                    margin-bottom: 4px;
                    color: #c0c0c0;
                }
                p {
                    margin: 6px 0;
                }
            </style>
        </head>
        <body>
            \(htmlString)
        </body>
        </html>
        """

        webView.loadHTMLString(styledHTML, baseURL: nil)
    }

    private func convertMarkdownToHTML(_ markdown: String) -> String {
        // Ensure markdown is not empty
        guard !markdown.isEmpty else {
            print("⚠️ Empty markdown string")
            return "<p>No content available</p>"
        }

        // Basic Markdown to HTML conversion
        var html = markdown

        // Escape any existing HTML to prevent injection
        html = html.replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        // Convert headers
        html = html.replacingOccurrences(of: "# ", with: "<h1>")
            .replacingOccurrences(of: "\n# ", with: "</h1>\n<h1>")
            .replacingOccurrences(of: "## ", with: "<h2>")
            .replacingOccurrences(of: "\n## ", with: "</h2>\n<h2>")
            .replacingOccurrences(of: "### ", with: "<h3>")
            .replacingOccurrences(of: "\n### ", with: "</h3>\n<h3>")

        // Close headers
        html = html.replacingOccurrences(of: "\n", with: "</h1>\n", options: .literal, range: html.range(of: html))

        // Convert bold
        html = html.replacingOccurrences(of: "**", with: "<strong>")
        html = html.replacingOccurrences(of: "**", with: "</strong>")

        // Convert lists
        html = html.replacingOccurrences(of: "- ", with: "<li>")
            .replacingOccurrences(of: "\n- ", with: "</li>\n<li>")
        html = "<ul>" + html + "</li></ul>"

        return html
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MarkdownView

        init(_ parent: MarkdownView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ Web view finished loading")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ Web view failed to load: \(error.localizedDescription)")
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: ()) {
        uiView.stopLoading()
    }
}

struct MarkdownView_Previews: PreviewProvider {
    static var previews: some View {
        MarkdownView(markdownString: "# Hello\n\n**Bold text**\n\n- List item 1\n- List item 2")
    }
}
