import Foundation
import TimeZoneCore

enum AppLocalization {
    static func string(_ key: String, language: AppLanguage) -> String {
        let bundle = bundle(for: language)
        let value = bundle.localizedString(forKey: key, value: nil, table: "Localizable")
        if value != key {
            return value
        }
        return Bundle.main.localizedString(forKey: key, value: key, table: "Localizable")
    }

    private static func bundle(for language: AppLanguage) -> Bundle {
        switch language {
        case .system:
            return .main
        case .simplifiedChinese:
            return localizationBundle(named: "zh-Hans") ?? .main
        case .english:
            return localizationBundle(named: "en") ?? .main
        }
    }

    private static func localizationBundle(named name: String) -> Bundle? {
        guard let path = Bundle.main.path(forResource: name, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }
}
