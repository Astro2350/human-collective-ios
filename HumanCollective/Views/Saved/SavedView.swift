import SwiftUI
import UIKit

struct ProfileView: View {
    let repository: any CultureRepository
    let communityRepository: any CommunityRepository
    let savedStore: SavedStore
    let profileStore: ProfileStore
    @Binding private var rootTabBarHiddenDepth: Int

    @State private var savedViewModel = SavedViewModel()
    @State private var selectedItem: CultureItem?
    @State private var presentedSheet: ProfileSheet?

    private var savedItems: [CultureItem] {
        switch savedViewModel.state {
        case .loaded(let items): items
        case .empty: []
        case .idle, .loading, .failed: savedStore.savedItems
        }
    }

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
        List {
            ScreenHeader("Profile")
                .profileListRow(top: HCTheme.pagePadding, bottom: 0)

            SubmissionSection(
                receipts: profileStore.submissions,
                profileStore: profileStore,
                onSelect: { presentedSheet = .preview($0) },
                onContribute: { presentedSheet = .contribute }
            )

            SavedSection(items: savedItems, onSelect: select, onUnsave: unsave)

            Color.clear
                .frame(height: HCTheme.rootTabBarContentClearance)
                .profileListRow(top: 0, bottom: 0, horizontal: 0)
        }
        .listStyle(.plain)
        .listSectionSpacing(16)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 1)
        .refreshable {
            await refreshProfile()
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(HCTheme.background)
        .navigationDestination(item: $selectedItem) { item in
            CultureDetailView(item: item, savedStore: savedStore)
                .rootTabBarHidden($rootTabBarHiddenDepth)
        }
        .sheet(item: $presentedSheet) { destination in
            switch destination {
            case .contribute:
                CommunitySubmissionView(
                    repository: communityRepository,
                    profileStore: profileStore,
                    initialCategory: .painting,
                    onSubmitted: {}
                )
            case .preview(let receipt):
                SubmissionPreviewSheet(
                    receipt: receipt,
                    repository: communityRepository,
                    profileStore: profileStore
                )
            }
        }
        .task(id: savedStore.revision) {
            await savedViewModel.load(from: savedStore, repository: repository)
        }
        .task(id: profileStore.submissions.map(\.id)) {
            await refreshSubmissionStatuses()
        }
    }

    private func select(_ item: CultureItem) {
        selectedItem = item
    }

    private func unsave(_ item: CultureItem) {
        withAnimation(.easeInOut(duration: 0.18)) {
            savedStore.unsave(item)
            savedViewModel.display(savedStore.savedItems)
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
}

private enum ProfileSheet: Identifiable {
    case contribute
    case preview(ProfileSubmissionReceipt)

    var id: String {
        switch self {
        case .contribute: "contribute"
        case .preview(let receipt): "preview-\(receipt.id.uuidString)"
        }
    }
}

private struct SubmissionSection: View {
    private enum Layout {
        static let rowVerticalInset: CGFloat = 6
    }

    let receipts: [ProfileSubmissionReceipt]
    let profileStore: ProfileStore
    let onSelect: (ProfileSubmissionReceipt) -> Void
    let onContribute: () -> Void

    var body: some View {
        Group {
            ProfileSectionHeader("My Submissions") {
                Button(action: onContribute) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(HCTheme.blueStone, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add a submission")
            }
            .profileListRow(top: 14, bottom: 4)

            if receipts.isEmpty {
                Text("Pieces you submit will appear here with their review status.")
                    .font(.callout)
                    .foregroundStyle(HCTheme.mutedInk)
                    .profileListRow()
            } else {
                ForEach(receipts) { receipt in
                    Button {
                        onSelect(receipt)
                    } label: {
                        SubmissionReceiptRow(
                            receipt: receipt,
                            localImage: profileStore.previewImage(for: receipt)
                        )
                    }
                    .buttonStyle(.cultureCard)
                    .contentShape(Rectangle())
                    .profileListRow(
                        top: Layout.rowVerticalInset,
                        bottom: Layout.rowVerticalInset
                    )
                    .accessibilityHint("Shows how this submission will look in the Collective")
                }
            }
        }
    }
}

private struct SubmissionReceiptRow: View {
    private enum Layout {
        static let contentSpacing: CGFloat = 14
        static let detailSpacing: CGFloat = 7
        static let imageSize: CGFloat = 96
        static let cardPadding: CGFloat = 10
        static let statusOverlap: CGFloat = -7
    }

    let receipt: ProfileSubmissionReceipt
    let localImage: UIImage?

    var body: some View {
        HStack(spacing: Layout.contentSpacing) {
            SubmissionArtworkImage(
                localImage: localImage,
                imageURL: receipt.imageURL,
                title: receipt.title,
                aspectRatio: 1,
                cornerRadius: HCTheme.cardRadius
            )
            .frame(width: Layout.imageSize, height: Layout.imageSize)
            .overlay(alignment: .topLeading) {
                SubmissionStatusSymbol(status: receipt.status, compact: true)
                    .offset(x: Layout.statusOverlap, y: Layout.statusOverlap)
            }

            VStack(alignment: .leading, spacing: Layout.detailSpacing) {
                Text(receipt.status.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(receipt.status.profileTextColor)

                Text(receipt.title)
                    .font(.cultureTitle(20))
                    .foregroundStyle(HCTheme.ink)
                    .lineLimit(2)

                Text("\(receipt.creatorName) · \(receipt.category.title)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineLimit(1)

                Text("Submitted \(receipt.submittedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(HCTheme.mutedInk)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(HCTheme.mutedInk)
        }
        .padding(Layout.cardPadding)
        .background(HCTheme.surface, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
                .stroke(HCTheme.line.opacity(0.42), lineWidth: HCTheme.hairline)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(receipt.title), \(receipt.status.title), by \(receipt.creatorName), " +
            "\(receipt.category.title), submitted " +
            receipt.submittedAt.formatted(date: .abbreviated, time: .omitted)
        )
    }
}

private struct SubmissionPreviewSheet: View {
    private enum Layout {
        static let sheetSpacing: CGFloat = 22
        static let collectiveCardSpacing: CGFloat = 14
        static let titleSpacing: CGFloat = 5
        static let titleRowSpacing: CGFloat = 12
        static let metadataSpacing: CGFloat = 6
        static let statusSpacing: CGFloat = 12
        static let statusDetailSpacing: CGFloat = 2
        static let statusPadding: CGFloat = 14
        static let actionSpacing: CGFloat = 8
        static let collectiveImageAspectRatio: CGFloat = 1.04
    }

    private enum CancellationState: Equatable {
        case idle
        case cancelling
        case failed(String)
    }

    @Environment(\.dismiss) private var dismiss

    let receipt: ProfileSubmissionReceipt
    let repository: any CommunityRepository
    let profileStore: ProfileStore

    @State private var cancellationState: CancellationState = .idle
    @State private var showsCancellationConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.sheetSpacing) {
                    statusBanner

                    VStack(alignment: .leading, spacing: Layout.collectiveCardSpacing) {
                        Text("COLLECTIVE PREVIEW")
                            .font(.cultureKicker())
                            .tracking(1.4)
                            .foregroundStyle(HCTheme.clay)

                        collectivePreviewCard
                    }

                    Text("This preview uses the same image crop and information layout as a published post in the Collective.")
                        .font(.footnote)
                        .foregroundStyle(HCTheme.mutedInk)

                    if receipt.status == .pending {
                        cancelButton
                    }
                }
                .padding(HCTheme.pagePadding)
            }
            .background(HCTheme.background)
            .navigationTitle("Your Submission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .disabled(cancellationState == .cancelling)
                }
            }
        }
        .interactiveDismissDisabled(cancellationState == .cancelling)
        .confirmationDialog(
            "Cancel this submission?",
            isPresented: $showsCancellationConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cancel Submission", role: .destructive) {
                Task { await cancelSubmission() }
            }
            Button("Keep Submission", role: .cancel) {}
        } message: {
            Text("It will be permanently withdrawn from review and cannot be restored.")
        }
    }

    private var collectivePreviewCard: some View {
        VStack(alignment: .leading, spacing: Layout.collectiveCardSpacing) {
            SubmissionArtworkImage(
                localImage: profileStore.previewImage(for: receipt),
                imageURL: receipt.imageURL,
                title: receipt.title,
                aspectRatio: Layout.collectiveImageAspectRatio,
                cornerRadius: HCTheme.cardRadius
            )

            HStack(alignment: .top, spacing: Layout.titleRowSpacing) {
                VStack(alignment: .leading, spacing: Layout.titleSpacing) {
                    Text(receipt.title)
                        .font(.cultureTitle(23))
                        .foregroundStyle(HCTheme.ink)

                    Text(receipt.creatorName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(HCTheme.mutedInk)
                }

                Spacer(minLength: 8)
            }

            if let significance = receipt.significance, !significance.isEmpty {
                Text(significance)
                    .font(.body)
                    .foregroundStyle(HCTheme.secondaryInk)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: Layout.metadataSpacing) {
                Text(receipt.category.title)
                Text("·")
                Text("Preview")
            }
            .font(.caption)
            .foregroundStyle(HCTheme.mutedInk)

            Divider()
        }
    }

    private var statusBanner: some View {
        HStack(spacing: Layout.statusSpacing) {
            SubmissionStatusSymbol(status: receipt.status)

            VStack(alignment: .leading, spacing: Layout.statusDetailSpacing) {
                Text(receipt.status.title)
                    .font(.headline)
                    .foregroundStyle(HCTheme.ink)

                Text(receipt.status.profileDescription)
                    .font(.caption)
                    .foregroundStyle(HCTheme.secondaryInk)
            }
        }
        .padding(Layout.statusPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            receipt.status.profileColor.opacity(0.11),
            in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
        )
    }

    private var cancelButton: some View {
        VStack(alignment: .leading, spacing: Layout.actionSpacing) {
            if case .failed(let message) = cancellationState {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button(role: .destructive) {
                showsCancellationConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    if cancellationState == .cancelling { ProgressView() }
                    Text(cancellationState == .cancelling ? "Cancelling…" : "Cancel submission")
                        .font(.headline)
                    Spacer()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(cancellationState == .cancelling)
        }
    }

    @MainActor
    private func cancelSubmission() async {
        cancellationState = .cancelling
        do {
            try await repository.cancelSubmission(id: receipt.id)
            profileStore.removeSubmission(id: receipt.id)
            dismiss()
        } catch {
            cancellationState = .failed(error.localizedDescription)
        }
    }
}

private struct SubmissionArtworkImage: View {
    let localImage: UIImage?
    let imageURL: String?
    let title: String
    let aspectRatio: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if let localImage {
                GeometryReader { proxy in
                    Image(uiImage: localImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
            } else if let imageURL, !imageURL.isEmpty {
                CultureAsyncImage(
                    imageURL: imageURL,
                    aspectRatio: aspectRatio,
                    cornerRadius: cornerRadius,
                    accessibilityLabel: title
                )
            } else {
                ZStack {
                    HCTheme.surfaceDeep
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(HCTheme.mutedInk)
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(HCTheme.line.opacity(0.45), lineWidth: HCTheme.hairline)
        }
        .accessibilityLabel(title)
    }
}

private struct SubmissionStatusSymbol: View {
    let status: CommunitySubmissionReviewStatus
    var compact = false

    var body: some View {
        Image(systemName: status.systemImage)
            .font(.system(size: compact ? 16 : 24, weight: .bold))
            .foregroundStyle(status.profileSymbolColor)
            .frame(width: compact ? 32 : 46, height: compact ? 32 : 46)
            .background(status.profileColor, in: Circle())
            .overlay { Circle().stroke(HCTheme.surface, lineWidth: compact ? 3 : 0) }
            .accessibilityHidden(true)
    }
}

private extension CommunitySubmissionReviewStatus {
    var profileColor: Color {
        switch self {
        case .pending: Color(red: 0.83, green: 0.60, blue: 0.08)
        case .approved: Color(red: 0.19, green: 0.55, blue: 0.28)
        case .rejected, .removed: Color(red: 0.72, green: 0.18, blue: 0.16)
        }
    }

    var profileSymbolColor: Color {
        statusUsesDarkSymbol ? HCTheme.ink : .white
    }

    var profileTextColor: Color {
        statusUsesDarkSymbol ? Color(red: 0.49, green: 0.32, blue: 0.03) : profileColor
    }

    private var statusUsesDarkSymbol: Bool {
        self == .pending
    }

    var profileDescription: String {
        switch self {
        case .pending: "The Collective team is reviewing it."
        case .approved: "It has been approved for the Collective."
        case .rejected: "It was not approved for the Collective."
        case .removed: "It is no longer shown in the Collective."
        }
    }
}

private struct SavedSection: View {
    let items: [CultureItem]
    let onSelect: (CultureItem) -> Void
    let onUnsave: (CultureItem) -> Void

    var body: some View {
        Section {
            if items.isEmpty {
                Text("Pieces you save will appear here.")
                    .font(.callout)
                    .foregroundStyle(HCTheme.mutedInk)
                    .profileListRow()
            } else {
                ForEach(items) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        SavedItemCard(item: item)
                    }
                    .buttonStyle(.plain)
                    .profileListRow(top: 6, bottom: 6)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onUnsave(item)
                        } label: {
                            Label("Unsave", systemImage: "bookmark.slash")
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            onUnsave(item)
                        } label: {
                            Label("Unsave", systemImage: "bookmark.slash")
                        }
                    }
                }
            }
        } header: {
            ProfileSectionHeader("Saved")
        }
    }
}

private struct ProfileSectionHeader<Trailing: View>: View {
    let title: String
    private let trailing: Trailing

    init(_ title: String) where Trailing == EmptyView {
        self.title = title
        self.trailing = EmptyView()
    }

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.cultureTitle(24))
                .foregroundStyle(HCTheme.ink)

            trailing

            Spacer(minLength: 0)
        }
        .textCase(nil)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}

private extension View {
    func profileListRow(
        top: CGFloat = 5,
        bottom: CGFloat = 5,
        horizontal: CGFloat = HCTheme.pagePadding
    ) -> some View {
        listRowInsets(.init(top: top, leading: horizontal, bottom: bottom, trailing: horizontal))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
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
