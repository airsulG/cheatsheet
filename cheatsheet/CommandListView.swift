import SwiftUI
import AppKit

struct CommandListView: View {
    @Binding var category: CheatCategory
    @ObservedObject var store: CheatStore

    @State private var showingAddCommand = false
    @State private var editCommand: CheatCommand?
    @State private var commandName = ""
    @State private var commandText = ""
    @State private var showCopied = false

    var body: some View {
        VStack {
            List {
                ForEach(category.commands) { command in
                    HStack {
                        Text(command.name)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(command.command, forType: .string)
                        withAnimation { showCopied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            withAnimation { showCopied = false }
                        }
                    }
                    .contextMenu {
                        Button("编辑") {
                            editCommand = command
                            commandName = command.name
                            commandText = command.command
                            showingAddCommand = true
                        }
                        Button("删除", role: .destructive) {
                            if let index = category.commands.firstIndex(where: { $0.id == command.id }) {
                                store.deleteCommands(in: category, at: IndexSet(integer: index))
                            }
                        }
                    }
                }
                .onMove { indices, newOffset in
                    store.moveCommands(in: category, from: indices, to: newOffset)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        editCommand = nil
                        commandName = ""
                        commandText = ""
                        showingAddCommand = true
                    }) {
                        Label("新增命令", systemImage: "plus")
                    }
                }
            }
            if showCopied {
                Text("已复制!")
                    .padding(6)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showingAddCommand) {
            AddCommandSheet(name: $commandName, command: $commandText) { name, cmd in
                if let editing = editCommand {
                    store.renameCommand(editing, in: category, newName: name, newCommand: cmd)
                } else {
                    store.addCommand(to: category, name: name, command: cmd)
                }
            }
        }
    }
}

struct AddCommandSheet: View {
    @Binding var name: String
    @Binding var command: String
    var onSave: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("命令").font(.headline)
            TextField("名称", text: $name)
                .textFieldStyle(.roundedBorder)
            TextField("命令内容", text: $command)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Button("保存") {
                    onSave(name, command)
                    dismiss()
                }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || command.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
