import SwiftUI
import SwiftData
import PhotosUI
import Contacts
import QuickLook
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct RecordDetailView: View {
    let id: UUID
    let store: OperatorStore

    @State private var showingEdit = false
    @State private var showingDocumentPicker = false
    @State private var showingPhotoPicker = false
    @State private var showingDocumentScanner = false
    @State private var photoItem: PhotosPickerItem?
    @State private var quickLookURL: URL?
    @State private var aiResult: AIResult?
    @State private var showingDeleteConfirmation = false
    @State private var newTagText: String = ""
    @State private var secureToast: ToastInfo?
    @State private var showingLogInteraction = false
    @State private var showingShareAccessSheet = false
    @Environment(\.dismiss) private var dismiss

    @Bindable private var ai = AIService.shared

    private var item: OperatorItem? {
        store.item(id: id)
    }

    private var contact: CNContact? {
        guard let item, item.type == .person else { return nil }
        guard let identifier = item.source, !identifier.isEmpty else { return nil }
        return lookupContact(identifier: identifier)
    }

    var body: some View {
        Group {
            if let item {
                content(for: item)
            } else {
                ContentUnavailableView("Record Removed", systemImage: "trash")
            }
        }
        .navigationTitle(item?.title ?? "")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if let item {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingEdit = true } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        store.togglePin(id: item.id)
                    } label: {
                        Label(item.pinned ? "Unpin" : "Pin",
                              systemImage: item.pinned ? "pin.fill" : "pin")
                    }
                    .tint(item.pinned ? .red : nil)
                }
                ToolbarItem(placement: .secondaryAction) {
                    ShareLink(item: shareText(for: item), preview: SharePreview(item.title)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        Button {
                            store.toggleArchive(id: item.id)
                        } label: {
                            Label(item.archived ? "Unarchive" : "Archive",
                                  systemImage: "archivebox")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            RecordEditSheet(mode: .edit(id), store: store)
        }
        .sheet(isPresented: $showingLogInteraction) {
            if let item {
                LogInteractionSheet(person: item, store: store)
            }
        }
        .sheet(isPresented: $showingShareAccessSheet) {
            if let item {
                ShareAccessSheet(record: item, store: store)
            }
        }
        .toast($secureToast)
    }

    private func logInteractionButton(for item: OperatorItem) -> some View {
        Button {
            showingLogInteraction = true
        } label: {
            Label("Log Interaction", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
    }

    /// Plain-text representation of a record for the iOS share sheet.
    /// Recipients can read this in iMessage / email / etc.; tapping the deep
    /// link opens the record in their HOS install (deep-link routing — Phase 3+).
    private func shareText(for item: OperatorItem) -> String {
        var parts: [String] = ["\(item.title)"]
        if !item.subtitle.isEmpty { parts.append(item.subtitle) }
        parts.append("Type: \(item.type.label)")
        parts.append("Status: \(item.status.label)")
        if let due = item.dueDate {
            parts.append("Due: \(due.formatted(date: .abbreviated, time: .omitted))")
        }
        if !item.body.isEmpty { parts.append("\n\(item.body)") }
        if !item.tags.isEmpty { parts.append("Tags: " + item.tags.joined(separator: ", ")) }
        parts.append("\nShared from OPerationsHOS · operationshos://record/\(item.id.uuidString)")
        return parts.joined(separator: "\n")
    }

    // MARK: - Sharing (per-record)

    private func sharedWithSection(for item: OperatorItem) -> some View {
        let grants = item.accessGrants
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Shared With", systemImage: "person.2")
                    .font(.headline)
                Spacer()
                Button {
                    showingShareAccessSheet = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if grants.isEmpty {
                Text("Not shared with anyone. Tap the + button to grant a person access.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(grants) { grant in
                    sharedWithRow(grant: grant, recordID: item.id)
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func sharedWithRow(grant: AccessGrant, recordID: UUID) -> some View {
        let personName = store.item(id: grant.personID)?.title ?? "Unknown person"
        return HStack(spacing: 10) {
            Image(systemName: "person.crop.circle")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(personName).font(.subheadline)
                HStack(spacing: 4) {
                    Image(systemName: grant.permission.symbol)
                        .font(.caption2)
                    Text(grant.permission.label)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                ForEach(AccessPermission.allCases) { level in
                    Button {
                        store.grantAccess(to: recordID, person: grant.personID, permission: level)
                    } label: {
                        Label(level.label, systemImage: level.symbol)
                    }
                }
                Divider()
                Button(role: .destructive) {
                    store.revokeAccess(to: recordID, person: grant.personID)
                } label: {
                    Label("Revoke", systemImage: "minus.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.tint)
            }
        }
    }

    // MARK: - Sharing (per-Person view)

    private func recordsSharedWithPersonSection(for person: OperatorItem) -> some View {
        let shared = store.recordsShared(with: person.id)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Records Shared With \(person.title)", systemImage: "tray.full")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if !shared.isEmpty {
                    Button(role: .destructive) {
                        store.revokeAllAccess(person: person.id)
                    } label: {
                        Label("Revoke All", systemImage: "minus.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if shared.isEmpty {
                Text("No records currently shared with this person. Open any record and tap Shared With → Add to grant access.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(shared) { record in
                    recordSharedWithPersonRow(record: record, personID: person.id)
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func recordSharedWithPersonRow(record: OperatorItem, personID: UUID) -> some View {
        let grant = record.accessGrants.first(where: { $0.personID == personID })
        return NavigationLink(value: record.id) {
            HStack(spacing: 10) {
                Image(systemName: record.type.symbol)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.title).font(.subheadline)
                    if let grant {
                        HStack(spacing: 4) {
                            Image(systemName: grant.permission.symbol)
                                .font(.caption2)
                            Text(grant.permission.label)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(role: .destructive) {
                    store.revokeAccess(to: record.id, person: personID)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func content(for item: OperatorItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                header(for: item)
                if let contact {
                    contactPhoto(for: contact)
                    quickActions(for: contact)
                    contactDetails(for: contact)
                }
                if item.type == .person {
                    logInteractionButton(for: item)
                    recordsSharedWithPersonSection(for: item)
                }
                metadata(for: item)
                if item.type == .timer {
                    timerSection(for: item)
                }
                if !item.body.isEmpty {
                    bodySection(for: item)
                }
                tagsSection(for: item)
                if item.type != .person {
                    sharedWithSection(for: item)
                }
                aiSection(for: item)
                attachmentsSection(for: item)
                activityLogSection(for: item)
                deleteSection(for: item)
            }
            .padding()
        }
        #if os(iOS)
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: [.pdf, .image, .data],
            allowsMultipleSelection: true
        ) { result in
            handleDocumentImport(result, into: item)
        }
        .quickLookPreview($quickLookURL)
        #endif
        .onChange(of: photoItem) { _, newItem in
            handlePhotoPick(newItem, into: item)
        }
    }

    private func contactPhoto(for contact: CNContact) -> some View {
        HStack {
            Spacer()
            Group {
                if contact.imageDataAvailable, let data = contact.imageData, let img = platformImage(from: data) {
                    img.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, height: 96)
            .clipShape(Circle())
            Spacer()
        }
    }

    private func quickActions(for contact: CNContact) -> some View {
        let phone = contact.phoneNumbers.first?.value.stringValue
        let email = contact.emailAddresses.first?.value as String?
        return HStack(spacing: 16) {
            quickActionButton(title: "Call", icon: "phone.fill", enabled: phone != nil) {
                if let p = phone { open("tel://\(p.filter { $0.isNumber || $0 == "+" })") }
            }
            quickActionButton(title: "Message", icon: "message.fill", enabled: phone != nil) {
                if let p = phone { open("sms:\(p.filter { $0.isNumber || $0 == "+" })") }
            }
            quickActionButton(title: "Email", icon: "envelope.fill", enabled: email != nil) {
                if let e = email { open("mailto:\(e)") }
            }
        }
    }

    private func quickActionButton(title: String, icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title2)
                Text(title).font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.4)
    }

    private func contactDetails(for contact: CNContact) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Contact Info").font(.headline)
            ForEach(contact.phoneNumbers, id: \.identifier) { phone in
                HStack {
                    Image(systemName: "phone").foregroundStyle(.tint)
                    Text(phone.value.stringValue)
                    Spacer()
                    if let label = phone.label {
                        Text(CNLabeledValue<NSString>.localizedString(forLabel: label))
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
            ForEach(contact.emailAddresses, id: \.identifier) { email in
                HStack {
                    Image(systemName: "envelope").foregroundStyle(.tint)
                    Text(email.value as String)
                    Spacer()
                    if let label = email.label {
                        Text(CNLabeledValue<NSString>.localizedString(forLabel: label))
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
            if let bday = contact.birthday, let date = Calendar.current.date(from: bday) {
                HStack {
                    Image(systemName: "birthday.cake").foregroundStyle(.tint)
                    Text(date, style: .date)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.cardPadding)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }

    private func header(for item: OperatorItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: item.type.symbol)
                    .font(.title)
                    .foregroundStyle(.tint)
                Text(item.type.label)
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.thinMaterial, in: Capsule())
                Button {
                    store.togglePin(id: item.id)
                } label: {
                    Image(systemName: item.pinned ? "pin.fill" : "pin.slash")
                        .font(.title3)
                        .foregroundStyle(item.pinned ? Color.red : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.pinned ? "Unpin" : "Pin")
                Button {
                    let wasSecure = item.isSecure
                    let id = item.id
                    store.toggleSecure(id: id)
                    secureToast = ToastInfo(
                        message: wasSecure ? "Removed from Vault" : "Moved to Vault > Secure Records",
                        undoAction: { store.toggleSecure(id: id) }
                    )
                } label: {
                    Image(systemName: item.isSecure ? "lock.shield.fill" : "lock.shield")
                        .font(.title3)
                        .foregroundStyle(item.isSecure ? Color.blue : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.isSecure ? "Remove from Vault" : "Move to Vault")
                if item.archived {
                    Image(systemName: "archivebox.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Text(item.title).font(.title2.weight(.semibold))
            if !item.subtitle.isEmpty {
                Text(item.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func metadata(for item: OperatorItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Status", statusDisplay(for: item))
            row("Priority", item.priority.label)
            if let due = item.dueDate {
                row("Due", due.formatted(date: .abbreviated, time: .omitted))
            }
            if let system = item.relatedSystem {
                row("Related System", system)
            }
            row("Created", item.createdDate.formatted(date: .abbreviated, time: .omitted))
            row("Updated", item.updatedDate.formatted(date: .abbreviated, time: .omitted))
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    /// Surface the status-date gap explicitly: "Scheduled" without a date is
    /// incomplete data; the user needs to either set a date or change the status.
    private func statusDisplay(for item: OperatorItem) -> String {
        if item.status == .scheduled && item.dueDate == nil {
            return "\(item.status.label) (date pending)"
        }
        return item.status.label
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }

    private func bodySection(for item: OperatorItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes").font(.headline)
            TextEditor(text: Binding(
                get: { item.body },
                set: { newValue in
                    item.body = newValue
                    item.updatedDate = Date()
                }
            ))
            .frame(minHeight: 80, maxHeight: 240)
            .scrollContentBackground(.hidden)
            .font(.body)
            .foregroundStyle(.primary)
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func tagsSection(for item: OperatorItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(item.tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag).font(.caption)
                            Button {
                                item.tags.removeAll { $0 == tag }
                                item.updatedDate = Date()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove tag \(tag)")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                    }
                    TextField("+ tag", text: $newTagText)
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .frame(minWidth: 60)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial.opacity(0.5), in: Capsule())
                        .onSubmit {
                            let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty && !item.tags.contains(trimmed) {
                                item.tags.append(trimmed)
                                item.updatedDate = Date()
                            }
                            newTagText = ""
                        }
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    @ViewBuilder
    private func attachmentsSection(for item: OperatorItem) -> some View {
        let attachments = (item.attachments ?? []).sorted { $0.createdDate > $1.createdDate }
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Attachments").font(.headline)
                Spacer()
                Menu {
                    Button {
                        showingPhotoPicker = true
                    } label: {
                        Label("Photo from Library", systemImage: "photo")
                    }
                    Button {
                        showingDocumentPicker = true
                    } label: {
                        Label("File", systemImage: "doc")
                    }
                    #if os(iOS)
                    Button {
                        showingDocumentScanner = true
                    } label: {
                        Label("Scan a Document", systemImage: "doc.viewfinder")
                    }
                    #endif
                } label: {
                    Label("Add", systemImage: "plus.circle")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
                .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItem, matching: .images)
                #if os(iOS)
                .sheet(isPresented: $showingDocumentScanner) {
                    DocumentScannerView { pages in
                        handleScannedPages(pages, into: item)
                    }
                    .ignoresSafeArea()
                }
                #endif
            }
            if attachments.isEmpty {
                Text("No attachments yet. Tap + to add a photo or file.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(attachments) { attachment in
                    attachmentRow(attachment)
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func attachmentRow(_ attachment: Attachment) -> some View {
        Button {
            quickLookURL = AttachmentStorage.url(for: attachment.filename)
        } label: {
            HStack {
                Image(systemName: attachment.kind.symbol)
                    .foregroundStyle(.tint)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.originalName.isEmpty ? attachment.filename : attachment.originalName)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(attachment.kind.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                deleteAttachment(attachment)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func deleteAttachment(_ attachment: Attachment) {
        AttachmentStorage.delete(filename: attachment.filename)
        store.deleteAttachment(attachment)
    }

    private func handleDocumentImport(_ result: Result<[URL], Error>, into item: OperatorItem) {
        guard case let .success(urls) = result else { return }
        for url in urls {
            do {
                let info = try AttachmentStorage.copy(from: url)
                let attachment = Attachment(
                    filename: info.filename,
                    originalName: info.originalName,
                    kind: AttachmentStorage.kind(for: url)
                )
                store.attach(attachment, to: item)
            } catch {
                continue
            }
        }
    }

    private func handlePhotoPick(_ pickerItem: PhotosPickerItem?, into item: OperatorItem) {
        guard let pickerItem else { return }
        Task {
            do {
                guard let data = try await pickerItem.loadTransferable(type: Data.self) else { return }
                let info = try AttachmentStorage.write(data: data, suggestedExtension: "jpg")
                let attachment = Attachment(
                    filename: info.filename,
                    originalName: info.originalName,
                    kind: .image
                )
                await MainActor.run {
                    store.attach(attachment, to: item)
                    photoItem = nil
                }
            } catch {
                await MainActor.run { photoItem = nil }
            }
        }
    }

    #if os(iOS)
    private func handleScannedPages(_ pages: [UIImage], into item: OperatorItem) {
        Task {
            for page in pages {
                guard let data = page.jpegData(compressionQuality: 0.85) else { continue }
                do {
                    let info = try AttachmentStorage.write(data: data, suggestedExtension: "jpg")
                    let attachment = Attachment(
                        filename: info.filename,
                        originalName: info.originalName,
                        kind: .image
                    )
                    await MainActor.run {
                        store.attach(attachment, to: item)
                    }
                } catch {
                    continue
                }
            }
        }
    }
    #endif

    private func timerSection(for item: OperatorItem) -> some View {
        TimerSectionView(item: item, store: store)
    }

    @ViewBuilder
    private func aiSection(for item: OperatorItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkles").foregroundStyle(.tint)
                Text("AI Actions").font(.headline)
                Spacer()
                if ai.isProcessing {
                    ProgressView().controlSize(.small)
                }
            }

            if !ai.hasAPIKey {
                Text("Add an Anthropic API key in Settings to enable AI actions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("These send this record's content to Claude via your Anthropic API key for AI processing.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 12) {
                    aiActionButton(
                        title: "Summarize",
                        systemImage: "text.alignleft",
                        caption: "Ask Claude for a short overview of this record's notes.",
                        kind: .summary,
                        item: item
                    )
                    aiActionButton(
                        title: "Extract Dates",
                        systemImage: "calendar",
                        caption: "Find dates mentioned in this record's notes and surface them.",
                        kind: .dates,
                        item: item
                    )
                    aiActionButton(
                        title: "Suggest Category",
                        systemImage: "tag",
                        caption: "Ask Claude to recommend an ItemType for this record's content.",
                        kind: .category,
                        item: item
                    )
                }
            }

            if let result = aiResult {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.kind.label).font(.caption).foregroundStyle(.secondary)
                    Text(result.text).font(.body)
                    if result.kind == .category, let suggested = matchType(for: result.text) {
                        Button {
                            apply(suggestedType: suggested, to: item)
                        } label: {
                            Label("Apply category", systemImage: "checkmark")
                                .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }

            if let error = ai.lastError, aiResult == nil {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func runAI(_ kind: AIResult.Kind, on item: OperatorItem) {
        aiResult = nil
        Task {
            let text: String?
            switch kind {
            case .summary:
                text = await ai.summarize(item)
            case .dates:
                text = await ai.extractDates(from: item)
            case .category:
                text = await ai.suggestCategory(for: item)
            }
            if let text {
                aiResult = AIResult(kind: kind, text: text)
            }
        }
    }

    @ViewBuilder
    private func aiActionButton(title: String, systemImage: String, caption: String, kind: AIResult.Kind, item: OperatorItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                runAI(kind, on: item)
            } label: {
                Label(title, systemImage: systemImage)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(ai.isProcessing)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
        }
    }

    private func matchType(for text: String) -> ItemType? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ItemType.allCases.first { $0.label.lowercased() == cleaned }
    }

    private func apply(suggestedType: ItemType, to item: OperatorItem) {
        item.type = suggestedType
        store.update(item)
        aiResult = nil
    }

    @ViewBuilder
    private func activityLogSection(for item: OperatorItem) -> some View {
        let events = (item.events ?? []).sorted { $0.timestamp > $1.timestamp }
        VStack(alignment: .leading, spacing: 8) {
            Text("Activity").font(.headline)
            if events.isEmpty {
                Text("Edits, pins, and attachments are logged here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(events) { event in
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: event.kind.symbol)
                            .foregroundStyle(.tint)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.kind.label)
                                .font(.subheadline)
                            if !event.details.isEmpty {
                                Text(event.details)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Text(event.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    @ViewBuilder
    private func deleteSection(for item: OperatorItem) -> some View {
        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            Label("Delete Record?", systemImage: "trash.fill")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .alert("Delete this record?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                store.delete(id: item.id)
                dismiss()
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

}

struct AIResult: Equatable {
    enum Kind: String, Equatable {
        case summary
        case dates
        case category

        var label: String {
            switch self {
            case .summary: return "Summary"
            case .dates: return "Extracted dates"
            case .category: return "Suggested category"
            }
        }
    }

    let kind: Kind
    let text: String
}

#if canImport(UIKit)
private func platformImage(from data: Data) -> Image? {
    UIImage(data: data).map { Image(uiImage: $0) }
}
#elseif canImport(AppKit)
private func platformImage(from data: Data) -> Image? {
    NSImage(data: data).map { Image(nsImage: $0) }
}
#endif
