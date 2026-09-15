import CoreData

extension Command {
    func isPinned(in tag: Category) -> Bool {
        deletedAt == nil && tag.deletedAt == nil &&
        (tags as? Set<Category> ?? []).contains(tag) &&
        (pinnedTags as? Set<Category> ?? []).contains(tag)
    }
}

extension CabinetStore {
    /// 只改变标签内置顶关系；不改正文时间、全局常用或全局手动顺序。
    func setPinned(_ pinned: Bool, command: Command, tag: Category) throws {
        guard command.managedObjectContext === context, tag.managedObjectContext === context,
              !command.isDeleted, !tag.isDeleted, command.deletedAt == nil, tag.deletedAt == nil,
              (command.tags as? Set<Category> ?? []).contains(tag) else {
            throw CabinetError.invalid("片段已不属于这个标签，无法修改置顶")
        }
        let previous = command.pinnedTags
        var tags = previous as? Set<Category> ?? []
        if pinned { tags.insert(tag) } else { tags.remove(tag) }
        guard tags != (previous as? Set<Category> ?? []) else { return }
        command.pinnedTags = NSSet(set: tags)
        do { try context.save() }
        catch { command.pinnedTags = previous; throw error }
    }
}

extension CabinetViewModel {
    func pinningTag(for command: Command) -> Category? {
        guard case .tag(let id) = location, command.deletedAt == nil else { return nil }
        return command.activeTags.first { $0.objectID == id }
    }

    func isPinnedInCurrentTag(_ command: Command) -> Bool {
        pinningTag(for: command).map { command.isPinned(in: $0) } ?? false
    }

    @discardableResult
    func togglePin(_ command: Command) -> Bool {
        guard allowLeaving(), let tag = pinningTag(for: command) else { return false }
        do {
            try store.setPinned(!command.isPinned(in: tag), command: command, tag: tag)
            reload()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
