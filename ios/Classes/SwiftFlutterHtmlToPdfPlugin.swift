import Flutter
import UIKit
import WebKit

public class SwiftFlutterHtmlToPdfPlugin: NSObject, FlutterPlugin {
    var wkWebView: WKWebView!
    var urlObservation: NSKeyValueObservation?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_html_to_pdf", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterHtmlToPdfPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "convertHtmlToPdf":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid argument for htmlFilePath", details: nil))
                return
            }
            
            guard let htmlFilePath = args["htmlFilePath"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "htmlFilePath argument is missing or invalid", details: nil))
                return
            }

            let viewController: UIViewController
            if let window = UIApplication.shared.delegate?.window {
                viewController = window?.rootViewController ?? UIViewController()
            } else {
                viewController = UIViewController()
            }

            wkWebView = WKWebView(frame: viewController.view.bounds)
            wkWebView.isHidden = true
            wkWebView.tag = 100
            viewController.view.addSubview(wkWebView)

            if let htmlFileContent = FileHelper.getContent(from: htmlFilePath) as? String {
                wkWebView.loadHTMLString(htmlFileContent, baseURL: Bundle.main.bundleURL)

                urlObservation = wkWebView.observe(\.isLoading, changeHandler: { [weak self] (webView, change) in
                    guard let self = self else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        let convertedFileURL = PDFCreator.create(printFormatter: self.wkWebView.viewPrintFormatter())
                        let convertedFilePath = convertedFileURL.absoluteString.replacingOccurrences(of: "file://", with: "")

                        if let viewWithTag = viewController.view.viewWithTag(100) {
                            viewWithTag.removeFromSuperview()

                            if #available(iOS 9.0, *) {
                                WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                                    records.forEach { record in
                                        WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
                                    }
                                }
                            }
                        }

                        self.urlObservation = nil
                        self.wkWebView = nil
                        result(convertedFilePath)
                    }
                })
            } else {
                result(FlutterError(code: "HTML_CONTENT_ERROR", message: "HTML file content could not be retrieved or converted to String.", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
