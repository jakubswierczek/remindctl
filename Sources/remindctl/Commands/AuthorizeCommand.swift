import Commander
import Foundation
import RemindCore

enum AuthorizeCommand {
  static var spec: CommandSpec {
    CommandSpec(
      name: "authorize",
      abstract: "Request Reminders access",
      discussion: "Triggers the Reminders permission prompt when available.",
      signature: CommandSignatures.withRuntimeFlags(CommandSignature()),
      usageExamples: [
        "remindctl authorize",
        "remindctl authorize --json",
        "remindctl authorize --quiet",
      ]
    ) { _, runtime in
      let store = RemindersStore()
      let current = RemindersStore.authorizationStatus()
      let status: RemindersAuthorizationStatus

      switch current {
      case .notDetermined:
        status = try await store.requestAuthorization()
      case .denied, .restricted:
        // macOS caches the denial — re-requesting won't show the prompt
        OutputRenderer.printAuthorizationStatus(current, format: runtime.outputFormat)
        if runtime.outputFormat == .standard {
          fputs("""

            Access was previously denied. macOS will not show the prompt again.
            To fix this manually:
              1. Open System Settings > Privacy & Security > Reminders
              2. Find Terminal (or your terminal app) in the list
              3. Toggle it ON
              4. Re-run: remindctl authorize

            """, stderr)
        }
        throw RemindCoreError.accessDenied
      default:
        status = current
      }

      OutputRenderer.printAuthorizationStatus(status, format: runtime.outputFormat)

      switch status {
      case .fullAccess:
        return
      case .writeOnly:
        throw RemindCoreError.writeOnlyAccess
      case .notDetermined, .denied, .restricted:
        throw RemindCoreError.accessDenied
      }
    }
  }
}
