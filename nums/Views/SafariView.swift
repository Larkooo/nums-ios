//
//  SafariView.swift
//  nums
//
//  Created by Assistant on 2025-10-29.
//

import SwiftUI
import SafariServices

// SafariView wrapper for SFSafariViewController
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let safari = SFSafariViewController(url: url, configuration: config)
        safari.dismissButtonStyle = .close
        return safari
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}




