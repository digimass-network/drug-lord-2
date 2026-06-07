import Cocoa
import WebKit
import Network

// A tiny loopback HTTP server so the web origin is stable (http://127.0.0.1:<port>),
// which makes localStorage saves persist reliably across launches.
final class GameServer {
    private var listener: NWListener?
    let port: UInt16
    private let html: Data

    init(port: UInt16, html: Data) { self.port = port; self.html = html }

    func start() {
        let params = NWParameters.tcp
        // bind to loopback only — avoids the macOS "accept incoming connections" firewall prompt
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1",
                                                           port: NWEndpoint.Port(rawValue: port)!)
        guard let l = try? NWListener(using: params) else { return }
        listener = l
        l.newConnectionHandler = { [weak self] c in self?.serve(c) }
        l.start(queue: .global())
    }

    private func serve(_ conn: NWConnection) {
        conn.start(queue: .global())
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] _, _, _, _ in
            guard let self = self else { conn.cancel(); return }
            var resp = ("HTTP/1.1 200 OK\r\n" +
                        "Content-Type: text/html; charset=utf-8\r\n" +
                        "Content-Length: \(self.html.count)\r\n" +
                        "Cache-Control: no-store\r\n" +
                        "Connection: close\r\n\r\n").data(using: .utf8)!
            resp.append(self.html)
            conn.send(content: resp, completion: .contentProcessed { _ in conn.cancel() })
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var web: WKWebView!
    var server: GameServer?
    let port: UInt16 = 47615

    func applicationDidFinishLaunching(_ note: Notification) {
        let html = Bundle.main.url(forResource: "index", withExtension: "html")
            .flatMap { try? Data(contentsOf: $0) }
            ?? Data("<h1 style='color:#fff;background:#111;font-family:monospace'>index.html missing</h1>".utf8)

        server = GameServer(port: port, html: html)
        server?.start()

        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()      // persistent storage
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true

        let frame = NSRect(x: 0, y: 0, width: 1060, height: 840)
        web = WKWebView(frame: frame, configuration: cfg)
        web.autoresizingMask = [.width, .height]
        web.setValue(false, forKey: "drawsBackground")

        window = NSWindow(contentRect: frame,
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Da Trap"
        window.minSize = NSSize(width: 760, height: 600)
        window.center()
        window.contentView?.addSubview(web)
        window.makeKeyAndOrderFront(nil)

        // let the listener bind, then load
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if let url = URL(string: "http://127.0.0.1:\(self.port)/") {
                self.web.load(URLRequest(url: url))
            }
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
