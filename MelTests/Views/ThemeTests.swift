import SwiftUI
import Testing
@testable import Mel

@MainActor
struct ThemeTests {
    /// A one-line text is exactly as tall as the design's line height.
    @Test func lineHeightIsExact() throws {
        let styles = [
            Theme.Text.largeTitle, Theme.Text.title2, Theme.Text.headline, Theme.Text.toolbarTitle,
            Theme.Text.prose, Theme.Text.body, Theme.Text.callout, Theme.Text.caption, Theme.Text.codeProse,
        ]
        for style in styles {
            let renderer = ImageRenderer(content: Text("Mel Ag").textStyle(style).fixedSize())
            let image = try #require(renderer.cgImage)
            #expect(CGFloat(image.height) / renderer.scale == style.lineHeight, "\(style.size) pt")
        }
    }
}
