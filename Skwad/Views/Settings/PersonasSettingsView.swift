import SwiftUI

struct PersonasSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var sheetPersona: SheetPersona? = nil

    /// Wrapper to drive .sheet(item:) — distinguishes add (nil persona) from edit.
    private struct SheetPersona: Identifiable {
        let id = UUID()
        let persona: Persona?
    }

    var body: some View {
        Form {
            Section {
                Text("Personas shape agent behavior by appending custom instructions to the system prompt. They work with agents that support system prompts (Claude, Codex).")
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("About")
            }

            Section {
                if settings.personas.isEmpty {
                    Text("No personas defined")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(settings.personas) { persona in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(persona.name)
                                Text(persona.instructions)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Button {
                                sheetPersona = SheetPersona(persona: persona)
                            } label: {
                                Image(systemName: "square.and.pencil")
                            }
                            .buttonStyle(.plain)
                            Button {
                                settings.removePersona(persona)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button("Add Persona...") {
                    sheetPersona = SheetPersona(persona: nil)
                }
            } header: {
                Text("Manage Personas")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .padding()
        .sheet(item: $sheetPersona) { item in
            PersonaSheet(persona: item.persona) { name, instructions in
                if let existing = item.persona {
                    settings.updatePersona(id: existing.id, name: name, instructions: instructions)
                } else {
                    _ = settings.addPersona(name: name, instructions: instructions)
                }
            }
        }
    }
}
