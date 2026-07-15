import PhotosUI
import SwiftUI
import UIKit

struct CommunityView: View {
    let repository: any CommunityRepository
    let savedStore: SavedStore
    let blockedStore: BlockedCommunityStore

    @State private var viewModel: CommunityFeedViewModel
    @State private var presentedSheet: CommunitySheet?
    @State private var expandedArtwork: CommunityArtwork?
    @State private var selectedCategory: CultureCategory?

    init(repository: any CommunityRepository, savedStore: SavedStore, blockedStore: BlockedCommunityStore) {
        self.repository = repository
        self.savedStore = savedStore
        self.blockedStore = blockedStore
        _viewModel = State(initialValue: CommunityFeedViewModel(repository: repository))
    }

    var body: some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .background(HCTheme.background)
            .overlay(alignment: .bottomTrailing) {
                Button {
                    presentedSheet = .contribute
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(HCTheme.blueStone, in: Circle())
                        .shadow(color: .black.opacity(0.16), radius: 10, y: 5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share a creation")
                .padding(.trailing, HCTheme.pagePadding)
                .padding(.bottom, HCTheme.rootTabBarContentClearance - 18)
            }
            .sheet(item: $presentedSheet) { destination in
                switch destination {
                case .contribute:
                    CommunitySubmissionView(
                        repository: repository,
                        initialCategory: selectedCategory ?? .painting
                    ) {
                        Task { await viewModel.refresh(category: selectedCategory) }
                    }
                case .report(let artwork):
                    CommunityReportView(artwork: artwork, repository: repository)
                }
            }
            .fullScreenCover(item: $expandedArtwork) { artwork in
                ZoomableImageViewer(imageURL: artwork.imageURL, title: artwork.title) {
                    expandedArtwork = nil
                }
                .ignoresSafeArea()
                .presentationBackground(.black)
                .statusBarHidden(true)
            }
            .task {
                await viewModel.loadIfNeeded(category: selectedCategory)

                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30))
                    guard !Task.isCancelled else { return }
                    await viewModel.refresh(category: selectedCategory)
                }
            }
            .task(id: selectedCategory) {
                guard viewModel.state != .idle else { return }
                await viewModel.refresh(category: selectedCategory)
            }
            .sensoryFeedback(.selection, trigger: savedStore.revision)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            CultureLoadingView()
        case .failed(let message):
            CultureErrorView(message: message) {
                Task { await viewModel.refresh(category: selectedCategory, showLoading: true) }
            }
        case .loaded:
            feed
        }
    }

    private var feed: some View {
        let visibleArtworks = viewModel.artworks.filter { artwork in
            !blockedStore.contains(artwork.contributorID) &&
                (selectedCategory == nil || artwork.category == selectedCategory)
        }

        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 22) {
                ScreenHeader("Collective")

                CommunityCategoryPicker(selection: $selectedCategory)
            }
            .padding(.horizontal, HCTheme.pagePadding)
            .padding(.top, HCTheme.pagePadding)
            .padding(.bottom, 22)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if visibleArtworks.isEmpty {
                        Text(emptyMessage)
                            .font(.callout)
                            .foregroundStyle(HCTheme.mutedInk)
                            .padding(.top, 14)
                    } else {
                        ForEach(visibleArtworks) { artwork in
                            let savedItem = artwork.savedCultureItem

                            CommunityArtworkCard(
                                artwork: artwork,
                                isSaved: savedStore.isSaved(savedItem),
                                onOpenImage: { expandedArtwork = artwork },
                                onToggleSaved: { savedStore.toggle(savedItem) },
                                onReport: { presentedSheet = .report(artwork) },
                                onHideContributor: { blockedStore.block(artwork.contributorID) }
                            )
                        }
                    }
                }
                .padding(.horizontal, HCTheme.pagePadding)
                .padding(.bottom, HCTheme.rootTabBarContentClearance)
            }
            .refreshable {
                await viewModel.refresh(category: selectedCategory)
            }
        }
        .background(HCTheme.background)
    }

    private var emptyMessage: String {
        guard selectedCategory != nil else {
            return "No creations have been published yet."
        }
        return "No creations here yet."
    }
}

private enum CommunitySheet: Identifiable {
    case contribute
    case report(CommunityArtwork)

    var id: String {
        switch self {
        case .contribute: "contribute"
        case .report(let artwork): "report-\(artwork.id.uuidString)"
        }
    }
}

private struct CommunityCategoryPicker: View {
    private enum Layout {
        static let pillSpacing: CGFloat = 10
        static let pillHorizontalPadding: CGFloat = 18
        static let pillMinimumWidth: CGFloat = 76
        static let pillHeight: CGFloat = 38
    }

    @Binding var selection: CultureCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Layout.pillSpacing) {
                categoryButton(title: "All", symbolName: "square.grid.2x2", category: nil)

                ForEach(CultureCategory.collectiveCases) { category in
                    categoryButton(
                        title: category.title,
                        symbolName: category.symbolName,
                        category: category
                    )
                }
            }
            .padding(.trailing, HCTheme.pagePadding)
        }
        .contentShape(Rectangle())
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .padding(.trailing, -HCTheme.pagePadding)
    }

    private func categoryButton(
        title: String,
        symbolName: String,
        category: CultureCategory?
    ) -> some View {
        let isSelected = selection == category

        return Button {
            selection = category
        } label: {
            HStack(spacing: 7) {
                Image(systemName: symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : accentColor(for: category))

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : HCTheme.secondaryInk)
            }
        }
        .padding(.horizontal, Layout.pillHorizontalPadding)
        .frame(minWidth: Layout.pillMinimumWidth)
        .frame(height: Layout.pillHeight)
        .background(isSelected ? HCTheme.blueStone : HCTheme.surface, in: Capsule())
        .overlay {
            if !isSelected {
                Capsule()
                    .stroke(HCTheme.line.opacity(0.7), lineWidth: HCTheme.hairline)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func accentColor(for category: CultureCategory?) -> Color {
        guard let category else { return HCTheme.blueStone }

        return switch category {
        case .meme, .film, .music, .game, .book, .poster, .writing:
            HCTheme.editorGold
        case .painting, .sculpture, .fashion, .food, .drink, .textile, .pottery, .jewelry, .art:
            HCTheme.clay
        case .architecture, .car, .watch, .furniture, .instrument, .photography, .design:
            HCTheme.blueStone
        case .invention, .machine, .tool, .monument, .publicSpace, .engineeringFeat, .artifact, .map, .craft:
            HCTheme.moss
        case .manuscript, .object, .mask, .other:
            HCTheme.mutedInk
        }
    }
}

private struct CommunityArtworkCard: View {
    let artwork: CommunityArtwork
    let isSaved: Bool
    let onOpenImage: () -> Void
    let onToggleSaved: () -> Void
    let onReport: () -> Void
    let onHideContributor: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onOpenImage) {
                CultureAsyncImage(
                    imageURL: artwork.imageURL,
                    aspectRatio: 1.04,
                    cornerRadius: HCTheme.cardRadius,
                    accessibilityLabel: "\(artwork.title), by \(artwork.creatorName)"
                )
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.black.opacity(0.38), in: Circle())
                        .padding(14)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(artwork.title) image")
            .accessibilityHint("Opens a full screen viewer with zoom controls")

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(artwork.title)
                        .font(.cultureTitle(23))
                        .foregroundStyle(HCTheme.ink)

                    Text(artwork.creatorName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(HCTheme.mutedInk)
                }

                Spacer(minLength: 8)

                HStack(spacing: 2) {
                    Button(action: onToggleSaved) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.headline)
                            .foregroundStyle(isSaved ? HCTheme.blueStone : HCTheme.secondaryInk)
                            .frame(width: 36, height: 36)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isSaved ? "Unsave artwork" : "Save artwork")

                    Menu {
                        Button(action: onReport) {
                            Label("Report artwork", systemImage: "exclamationmark.bubble")
                        }

                        Button(role: .destructive, action: onHideContributor) {
                            Label("Hide this creator", systemImage: "eye.slash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.headline)
                            .foregroundStyle(HCTheme.secondaryInk)
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel("Artwork options")
                }
            }

            Text(artwork.significance)
                .font(.body)
                .foregroundStyle(HCTheme.secondaryInk)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text(artwork.category.title)
                Text("·")
                Text(artwork.publishedAt, style: .relative)
            }
            .font(.caption)
            .foregroundStyle(HCTheme.mutedInk)

            Divider()
        }
    }
}

private struct CommunitySubmissionView: View {
    private enum SubmissionState: Equatable {
        case idle
        case submitting
        case submitted
        case failed(String)
    }

    @Environment(\.dismiss) private var dismiss

    let repository: any CommunityRepository
    let onSubmitted: () -> Void

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var preparedJPEG: Data?
    @State private var artworkTitle = ""
    @State private var creatorName = ""
    @State private var significance = ""
    @State private var category: CultureCategory
    @State private var rightsConfirmed = false
    @State private var isPreparingImage = false
    @State private var imageError: String?
    @State private var submissionState: SubmissionState = .idle
    @State private var hasAttemptedSubmission = false

    init(
        repository: any CommunityRepository,
        initialCategory: CultureCategory,
        onSubmitted: @escaping () -> Void
    ) {
        self.repository = repository
        self.onSubmitted = onSubmitted
        _category = State(initialValue: initialCategory)
    }

    var body: some View {
        NavigationStack {
            Group {
                if submissionState == .submitted {
                    submittedContent
                } else {
                    submissionForm
                }
            }
            .navigationTitle("Share a Creation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(submissionState == .submitting)
                }
            }
        }
        .interactiveDismissDisabled(submissionState == .submitting)
        .onChange(of: selectedPhoto) { _, item in
            Task { await prepare(item) }
        }
    }

    private var submissionForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    ZStack {
                        HCTheme.surface

                        if let previewImage {
                            Image(uiImage: previewImage)
                                .resizable()
                                .scaledToFit()
                                .padding(8)
                                .accessibilityLabel("Selected creation")
                        } else {
                            Label("Choose a photo", systemImage: "photo.badge.plus")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
                }
                .disabled(isPreparingImage || submissionState == .submitting)

                if isPreparingImage {
                    HStack {
                        ProgressView()
                        Text("Preparing your photo…")
                    }
                }

                if let imageError {
                    Text(imageError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                HStack {
                    Text("Category")
                        .font(.headline)

                    Spacer()

                    Picker("Category", selection: $category) {
                        ForEach(CultureCategory.collectiveCases) { category in
                            Text(category.title).tag(category)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .disabled(submissionState == .submitting)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.headline)

                    TextField("Artwork title", text: $artworkTitle)
                        .disabled(submissionState == .submitting)
                    Divider()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Creator")
                        .font(.headline)

                    TextField("Your name", text: $creatorName)
                        .textContentType(.name)
                        .disabled(submissionState == .submitting)
                    Divider()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Significance")
                        .font(.headline)

                    TextEditor(text: $significance)
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(HCTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(alignment: .topLeading) {
                            if significance.isEmpty {
                                Text("Why it matters to you")
                                    .foregroundStyle(HCTheme.mutedInk)
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 18)
                                    .allowsHitTesting(false)
                            }
                        }
                        .disabled(submissionState == .submitting)

                    Text("\(significance.count)/600")
                        .font(.caption)
                        .foregroundStyle(significance.count > 600 ? .red : HCTheme.mutedInk)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Toggle(isOn: $rightsConfirmed) {
                    Text("I created this work and give Human Collective permission to display it.")
                }
                .disabled(submissionState == .submitting)

                if case .failed(let message) = submissionState {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if hasAttemptedSubmission, let validationMessage {
                    Text(validationMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        Spacer()
                        if submissionState == .submitting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(submissionState == .submitting ? "Submitting…" : "Submit for review")
                            .font(.headline)
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(HCTheme.blueStone)
                .disabled(submissionState == .submitting || isPreparingImage)
            }
            .padding(HCTheme.pagePadding)
        }
        .background(HCTheme.background)
        .scrollDismissesKeyboard(.interactively)
    }

    private var submittedContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(HCTheme.moss)

            Text("Submitted for review")
                .font(.cultureTitle(30))
                .foregroundStyle(HCTheme.ink)
                .multilineTextAlignment(.center)

            Text("If selected, it will appear in Collective.")
                .font(.body)
                .foregroundStyle(HCTheme.secondaryInk)
                .lineSpacing(4)
                .multilineTextAlignment(.center)

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(HCTheme.blueStone)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HCTheme.background)
    }

    private var validationMessage: String? {
        CommunitySubmissionValidator.message(
            jpegData: preparedJPEG,
            title: artworkTitle,
            creatorName: creatorName,
            significance: significance,
            rightsConfirmed: rightsConfirmed
        )
    }

    @MainActor
    private func prepare(_ item: PhotosPickerItem?) async {
        previewImage = nil
        preparedJPEG = nil
        imageError = nil
        guard let item else { return }

        isPreparingImage = true
        defer { isPreparingImage = false }

        do {
            guard let sourceData = try await item.loadTransferable(type: Data.self) else {
                throw CommunityImageProcessingError.unreadable
            }

            let jpeg = try await Task.detached(priority: .userInitiated) {
                try CommunityImageProcessor.prepareJPEG(from: sourceData)
            }.value

            guard selectedPhoto == item, let image = UIImage(data: jpeg) else { return }
            preparedJPEG = jpeg
            previewImage = image
        } catch is CancellationError {
            return
        } catch {
            imageError = error.localizedDescription
        }
    }

    @MainActor
    private func submit() async {
        hasAttemptedSubmission = true
        guard validationMessage == nil, let preparedJPEG else { return }
        submissionState = .submitting

        do {
            _ = try await repository.submit(
                CommunitySubmissionDraft(
                    title: artworkTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    creatorName: creatorName.trimmingCharacters(in: .whitespacesAndNewlines),
                    significance: significance.trimmingCharacters(in: .whitespacesAndNewlines),
                    category: category,
                    jpegData: preparedJPEG,
                    rightsConfirmed: rightsConfirmed
                )
            )
            submissionState = .submitted
            onSubmitted()
        } catch {
            submissionState = .failed(error.localizedDescription)
        }
    }
}

private struct CommunityReportView: View {
    private enum ReportState: Equatable {
        case idle
        case sending
        case sent
        case failed(String)
    }

    @Environment(\.dismiss) private var dismiss

    let artwork: CommunityArtwork
    let repository: any CommunityRepository

    @State private var reason: CommunityReportReason = .inappropriate
    @State private var details = ""
    @State private var state: ReportState = .idle

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Reason", selection: $reason) {
                        ForEach(CommunityReportReason.allCases) { reason in
                            Text(reason.title).tag(reason)
                        }
                    }
                }

                Section("Additional details (optional)") {
                    TextEditor(text: $details)
                        .frame(minHeight: 120)

                    Text("\(details.count)/500")
                        .font(.caption)
                        .foregroundStyle(details.count > 500 ? .red : HCTheme.mutedInk)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                if case .failed(let message) = state {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await sendReport() }
                    } label: {
                        HStack {
                            Spacer()
                            if state == .sending { ProgressView() }
                            Text(state == .sending ? "Sending…" : "Send report")
                            Spacer()
                        }
                    }
                    .disabled(details.count > 500 || state == .sending)
                }
            }
            .navigationTitle(state == .sent ? "Report Received" : "Report Artwork")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(HCTheme.background)
            .overlay {
                if state == .sent {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(HCTheme.moss)
                        Text("Thank you. We’ll review this artwork.")
                            .font(.cultureTitle(24))
                            .multilineTextAlignment(.center)
                        Button("Done") { dismiss() }
                            .buttonStyle(.borderedProminent)
                            .tint(HCTheme.blueStone)
                    }
                    .padding(28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(HCTheme.background)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(state == .sending)
                }
            }
        }
        .interactiveDismissDisabled(state == .sending)
    }

    @MainActor
    private func sendReport() async {
        guard details.count <= 500 else { return }
        state = .sending

        do {
            try await repository.report(artworkID: artwork.id, reason: reason, details: details)
            state = .sent
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
