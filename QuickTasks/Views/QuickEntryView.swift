import SwiftUI

/// The minimal floating text field for quick task entry.
///
/// This view is hosted inside the `QuickEntryPanel` (NSPanel).
/// It provides a single text field where the user types a task title
/// with optional inline commands (`/PROJECT`, `/bug`, `@username`).
///
/// - Press **Enter** to submit and dismiss.
/// - Press **Esc** to dismiss without submitting.
struct QuickEntryView: View {
    @State private var inputText = ""
    @FocusState private var isTextFieldFocused: Bool

    /// The view model that handles parsing and submission.
    let viewModel: QuickEntryViewModel
    /// Closure to dismiss the panel (called by AppDelegate).
    let dismissAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            TextField(
                String(localized: "quick_entry_placeholder",
                       defaultValue: "Type a task… ( /project  /bug  @assignee )",
                       comment: "Quick entry text field placeholder"),
                text: $inputText
            )
            .textFieldStyle(.plain)
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .focused($isTextFieldFocused)
            .onSubmit {
                let text = inputText.trimmingCharacters(in: .whitespaces)
                guard !text.isEmpty else { return }
                viewModel.submit(text)
                inputText = ""
                dismissAction()
            }
            .onExitCommand {
                inputText = ""
                dismissAction()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .onAppear {
            isTextFieldFocused = true
        }
    }
}
