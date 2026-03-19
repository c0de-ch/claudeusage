#!/usr/bin/env swift
// Run on macOS: swift generate-icon.swift
// Generates app icon PNGs from SF Symbol "brain" with a gradient background

import AppKit

let sizes: [(name: String, size: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

let outputDir = "ClaudeUsage/Assets.xcassets/AppIcon.appiconset"

func renderIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = CGFloat(size) * 0.22

    // Rounded rect clip
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    path.addClip()

    // Gradient background (dark teal to deep blue)
    let gradient = NSGradient(
        starting: NSColor(red: 0.15, green: 0.25, blue: 0.35, alpha: 1.0),
        ending: NSColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 1.0)
    )!
    gradient.draw(in: rect, angle: -45)

    // Draw "brain" SF Symbol
    let symbolSize = CGFloat(size) * 0.55
    let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .medium)
    if let symbol = NSImage(systemSymbolName: "brain", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let symbolRect = NSRect(
            x: (CGFloat(size) - symbol.size.width) / 2,
            y: (CGFloat(size) - symbol.size.height) / 2,
            width: symbol.size.width,
            height: symbol.size.height
        )
        // White with slight transparency
        NSColor(white: 1.0, alpha: 0.9).set()
        symbol.draw(in: symbolRect, from: .zero, operation: .sourceAtop, fraction: 1.0)
        // Draw again composited
        let tinted = NSImage(size: symbol.size)
        tinted.lockFocus()
        NSColor(red: 0.85, green: 0.75, blue: 0.55, alpha: 1.0).set()
        symbol.draw(in: NSRect(origin: .zero, size: symbol.size), from: .zero, operation: .sourceOver, fraction: 1.0)
        NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        tinted.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    image.unlockFocus()
    return image
}

// Generate all sizes
for (name, size) in sizes {
    let image = renderIcon(size: size)
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to render \(name)")
        continue
    }
    let path = "\(outputDir)/\(name).png"
    do {
        try png.write(to: URL(fileURLWithPath: path))
        print("✓ \(name).png (\(size)x\(size))")
    } catch {
        print("✗ \(name): \(error)")
    }
}

// Update Contents.json
let images = sizes.enumerated().map { idx, item -> [String: String] in
    let scale = item.name.contains("@2x") ? "2x" : "1x"
    let pointSize: Int
    switch item.size {
    case 16: pointSize = 16
    case 32: pointSize = item.name.contains("@2x") ? 16 : 32
    case 64: pointSize = 32
    case 128: pointSize = 128
    case 256: pointSize = item.name.contains("@2x") ? 128 : 256
    case 512: pointSize = item.name.contains("@2x") ? 256 : 512
    case 1024: pointSize = 512
    default: pointSize = item.size
    }
    return [
        "filename": "\(item.name).png",
        "idiom": "mac",
        "scale": scale,
        "size": "\(pointSize)x\(pointSize)"
    ]
}

let contents: [String: Any] = [
    "images": images,
    "info": ["author": "xcode", "version": 1]
]

if let json = try? JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]) {
    try? json.write(to: URL(fileURLWithPath: "\(outputDir)/Contents.json"))
    print("✓ Contents.json updated")
}

print("\nDone! Rebuild in Xcode to see the new icon.")
