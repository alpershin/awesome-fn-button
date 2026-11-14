import Foundation
import FnCore

// Read-only entry point: deliberately has no apply/restore flags.
do {
    let report = try Diagnostics.scan(store: SystemPreferences(), sources: Diagnostics.inputSources())
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    print(String(decoding: try encoder.encode(report), as: UTF8.self))
} catch {
    FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
    exit(1)
}
