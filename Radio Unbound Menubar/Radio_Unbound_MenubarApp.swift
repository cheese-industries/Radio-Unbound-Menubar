//
//  Radio_Unbound_MenubarApp.swift
//  Radio Unbound Menubar
//
//  Created by Daniel Lee on 2/18/26.
//

import SwiftUI

@main
struct YourAppNameApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }  // no windows
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
    }
}
