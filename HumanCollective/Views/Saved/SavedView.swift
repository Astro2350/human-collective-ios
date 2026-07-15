import SwiftUI

struct ProfileView: View {
    let repository: any CultureRepository
    let communityRepository: any CommunityRepository
    let savedStore: SavedStore
    let profileStore: ProfileStore
    @Binding private var rootTabBarHiddenDepth: Int

    @State private var savedViewModel = SavedViewModel()
    @State private var selectedItem: CultureItem?
    @State private var selectedExhibition: PersonalExhibition?
    @State private var presentedSheet: ProfileSheet?

    init(
        repository: any CultureRepository,
        communityRepository: any CommunityRepository,
        savedStore: SavedStore,
        profileStore: ProfileStore,
        rootTabBarHiddenDepth: Binding<Int>
    ) {
        self.repository = repository
        self.communityRepository = communityRepository
        self.savedStore = savedStore
        self.profileStore = profileStore
        _rootTabBarHiddenDepth = rootTabBarHiddenDepth
    }

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = max(proxy.size.width - (HCTheme.pagePadding * 2), 0)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    ScreenHeader("Profile") {
                        Button {
                            presentedSheet = .editName
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 42, height: 42)
                                .background(HCTheme.surface, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit profile name")
                    }

                    Button {
                        presentedSheet = .editName
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profileStore.displayName.isEmpty ? "Add your name" : profileStore.displayName)
                                .font(.cultureTitle(28))
                                .foregroundStyle(HCTheme.ink)

                            Text("Private to this iPhone")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(HCTheme.mutedInk)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    if !profileStore.submissions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ProfileSectionHeader(title: "Submissions")

                            ForEach(profileStore.submissions) { receipt in
                                SubmissionReceiptRow(receipt: receipt)
                                if receipt.id != profileStore.submissions.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ProfileSectionHeader(
                            title: "Exhibitions",
                            actionTitle: savedItems.count >= 2 ? "Create" : nil
                        ) {
                            presentedSheet = .newExhibition
                        }

                        if profileStore.exhibitions.isEmpty {
                            Text(savedItems.count >= 2
                                 ? "Arrange saved pieces into a collection of your own."
                                 : "Save at least two pieces to create an exhibition.")
                                .font(.callout)
                                .foregroundStyle(HCTheme.mutedInk)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            ForEach(profileStore.exhibitions) { exhibition in
                                Button {
                                    selectedExhibition = exhibition
                                } label: {
                                    ProfileExhibitionRow(exhibition: exhibition)
                                }
                                .buttonStyle(.plain)

                                if exhibition.id != profileStore.exhibitions.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ProfileSectionHeader(title: "Saved")

                        if savedItems.isEmpty {
                            Text("Pieces you save will appear here.")
                                .font(.callout)
                                .foregroundStyle(HCTheme.mutedInk)
                        } else {
                            ForEach(savedItems) { item in
                                Button {
                                    selectedItem = item
                                } label: {
                                    SavedItemCard(item: item)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        unsave(item)
                                    } label: {
                                        Label("Unsave", systemImage: "bookmark.slash")
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(HCTheme.pagePadding)
                .padding(.bottom, HCTheme.rootTabBarContentClearance)
            }
            .refreshable {
                await refreshProfile()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(HCTheme.background)
        .navigationDestination(item: $selectedItem) { item in
            CultureDetailView(item: item, savedStore: savedStore)
                .rootTabBarHidden($rootTabBarHiddenDepth)
        }
        .navigationDestination(item: $selectedExhibition) { exhibition in
            ExhibitionDetailView(
                exhibition: exhibition,
                savedStore: savedStore,
                profileStore: profileStore
            )
            .rootTabBarHidden($rootTabBarHiddenDepth)
        }
        .sheet(item: $presentedSheet) { destination in
            switch destination {
            case .editName:
                ProfileNameEditor(profileStore: profileStore)
            case .newExhibition:
                ExhibitionEditor(items: savedItems, profileStore: profileStore)
            }
        }
        .task(id: savedStore.revision) {
            await savedViewModel.load(from: savedStore, repository: repository)
        }
        .task(id: profileStore.submissions.map(\.id)) {
            await refreshSubmissionStatuses()
        }
    }

    private var savedItems: [CultureItem] {
        switch savedViewModel.state {
        case .loaded(let items): items
        case .empty: []
        case .idle, .loading, .failed: savedStore.savedItems
        }
    }

    private func refreshProfile() async {
        await savedViewModel.load(from: savedStore, repository: repository)
        await refreshSubmissionStatuses()
    }

    private func refreshSubmissionStatuses() async {
        let ids = profileStore.submissions.map(\.id)
        guard !ids.isEmpty,
              let statuses = try? await communityRepository.fetchSubmissionStatuses(ids: ids) else {
            return
        }
        profileStore.mergeSubmissionStatuses(statuses)
    }

    private func unsave(_ item: CultureItem) {
        withAnimation(.easeInOut(duration: 0.18)) {
            savedStore.unsave(item)
            savedViewModel.display(savedStore.savedItems)
        }
    }
}

private enum ProfileSheet: String, Identifiable {
    case editName
    case newExhibition

    var id: String { rawValue }
}

private struct ProfileSectionHeader: View {
    let title: String
    let actionTitle: String?
    private let action: () -> Void

    init(title: String) {
        self.title = title
        self.actionTitle = nil
        self.action = {}
    }

    init(title: String, actionTitle: String?, action: @escaping () -> Void) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.cultureTitle(24))
                .foregroundStyle(HCTheme.ink)

            Spacer()

            if let actionTitle {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HCTheme.blueStone)
            }
        }
    }
}

private struct SubmissionReceiptRow: View {
    let receipt: ProfileSubmissionReceipt

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: receipt.status.systemImage)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 4) {
                Text(receipt.title)
                    .font(.headline)
                    .foregroundStyle(HCTheme.ink)
                    .lineLimit(2)

                Text("\(receipt.status.title) · \(receipt.submittedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(HCTheme.mutedInk)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }

    private var statusColor: Color {
        switch receipt.status {
        case .pending: HCTheme.editorGold
        case .approved: HCTheme.moss
        case .rejected, .removed: HCTheme.mutedInk
        }
    }
}

private struct ProfileExhibitionRow: View {
    let exhibition: PersonalExhibition

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 3) {
                ForEach(Array(exhibition.items.prefix(3))) { item in
                    CultureAsyncImage(
                        imageURL: item.imageURL,
                        aspectRatio: 1,
                        cornerRadius: 3,
                        accessibilityLabel: item.title
                    )
                }
            }
            .frame(width: 104, height: 48)
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(exhibition.title)
                    .font(.headline)
                    .foregroundStyle(HCTheme.ink)
                    .lineLimit(2)

                Text("\(exhibition.items.count) pieces")
                    .font(.caption)
                    .foregroundStyle(HCTheme.mutedInk)
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(HCTheme.mutedInk)
        }
        .padding(.vertical, 3)
    }
}

private struct ProfileNameEditor: View {
    @Environment(\.dismiss) private var dismiss
    let profileStore: ProfileStore

    @State private var name: String

    init(profileStore: ProfileStore) {
        self.profileStore = profileStore
        _name = State(initialValue: profileStore.displayName)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Name")
                    .font(.headline)
                TextField("Your name", text: $name)
                    .textContentType(.name)
                    .textFieldStyle(.roundedBorder)
                Spacer()
            }
            .padding(HCTheme.pagePadding)
            .background(HCTheme.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        profileStore.updateDisplayName(name)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(230)])
    }
}

private struct ExhibitionEditor: View {
    @Environment(\.dismiss) private var dismiss
    let items: [CultureItem]
    let profileStore: ProfileStore

    @State private var title = ""
    @State private var selectedIDs = Set<String>()

    var body: some View {
        NavigationStack {
            List {
                TextField("Exhibition title", text: $title)

                ForEach(items) { item in
                    Button {
                        toggle(item)
                    } label: {
                        HStack(spacing: 12) {
                            CultureAsyncImage(
                                imageURL: item.imageURL,
                                aspectRatio: 1,
                                cornerRadius: 5,
                                accessibilityLabel: item.title
                            )
                            .frame(width: 52)

                            Text(item.displayTitle)
                                .font(.body.weight(.medium))
                                .foregroundStyle(HCTheme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: selectedIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedIDs.contains(item.id) ? HCTheme.blueStone : HCTheme.mutedInk)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollContentBackground(.hidden)
            .background(HCTheme.background)
            .navigationTitle("New Exhibition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        profileStore.createExhibition(
                            title: title,
                            items: items.filter { selectedIDs.contains($0.id) }
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || selectedIDs.count < 2)
                }
            }
        }
    }

    private func toggle(_ item: CultureItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else if selectedIDs.count < 12 {
            selectedIDs.insert(item.id)
        }
    }
}

private struct ExhibitionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let exhibition: PersonalExhibition
    let savedStore: SavedStore
    let profileStore: ProfileStore

    @State private var selectedItem: CultureItem?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text(exhibition.title)
                    .font(.cultureTitle(38))
                    .foregroundStyle(HCTheme.ink)
                    .padding(.top, HCTheme.screenTopPadding)

                ExhibitionShareButton(exhibition: exhibition)

                ForEach(exhibition.items) { item in
                    Button {
                        selectedItem = item
                    } label: {
                        SavedItemCard(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(HCTheme.pagePadding)
            .padding(.bottom, HCTheme.screenBottomPadding)
        }
        .background(HCTheme.background)
        .navigationTitle("Exhibition")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedItem) { item in
            CultureDetailView(item: item, savedStore: savedStore)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    profileStore.deleteExhibition(exhibition)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete exhibition")
            }
        }
    }
}

struct SavedItemCard: View {
    let item: CultureItem

    var body: some View {
        HStack(spacing: 12) {
            CultureAsyncImage(
                imageURL: item.imageURL,
                aspectRatio: 1,
                cornerRadius: 6,
                accessibilityLabel: item.title
            )
            .frame(width: 88)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.displayTitle)
                    .font(.cultureTitle(20))
                    .foregroundStyle(HCTheme.ink)
                    .lineLimit(2)

                Text(item.creatorDisplay)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HCTheme.mutedInk)
                    .lineLimit(2)

                Text(item.placeDisplay.isEmpty ? item.category.title : item.placeDisplay)
                    .font(.caption)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
