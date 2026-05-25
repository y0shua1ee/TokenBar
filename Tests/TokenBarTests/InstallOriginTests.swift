import Foundation
import Testing
@testable import TokenBar

struct InstallOriginTests {
    @Test
    func `detects homebrew caskroom`() {
        #expect(
            InstallOrigin
                .isHomebrewCask(
                    appBundleURL: URL(fileURLWithPath: "/opt/homebrew/Caskroom/tokenbar/1.0.0/TokenBar.app")))
        #expect(
            InstallOrigin
                .isHomebrewCask(appBundleURL: URL(fileURLWithPath: "/usr/local/Caskroom/tokenbar/1.0.0/TokenBar.app")))
        #expect(!InstallOrigin.isHomebrewCask(appBundleURL: URL(fileURLWithPath: "/Applications/TokenBar.app")))
    }
}
