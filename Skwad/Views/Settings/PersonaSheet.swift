import SwiftUI

struct PersonaSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var instructions: String

    let persona: Persona?
    let onSave: (String, String) -> Void

    init(persona: Persona? = nil, onSave: @escaping (String, String) -> Void) {
        self.persona = persona
        self.onSave = onSave
        _name = State(initialValue: persona?.name ?? "")
        _instructions = State(initialValue: persona?.instructions ?? "")
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(persona == nil ? "New Persona" : "Edit Persona")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Define a persona to shape agent behavior")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g. Kent Beck TDD Expert", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Instructions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $instructions)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            HStack(spacing: 20) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(persona == nil ? "Add" : "Save") {
                    onSave(
                        name.trimmingCharacters(in: .whitespacesAndNewlines),
                        instructions.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding(.vertical, 16)
        }
        .frame(width: 450, height: 360)
    }
}
