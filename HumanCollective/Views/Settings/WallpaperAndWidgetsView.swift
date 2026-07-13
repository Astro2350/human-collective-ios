import SwiftUI

struct WidgetSetupView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VisualSetupStepCard(
                    number: 1,
                    text: "Press and hold your Home or Lock Screen.",
                    illustration: .pressAndHold
                )
                VisualSetupStepCard(
                    number: 2,
                    text: "Home Screen: tap Edit, then Add Widget.",
                    illustration: .addWidget
                )
                VisualSetupStepCard(
                    number: 3,
                    text: "Lock Screen: tap Customize, then the widget area.",
                    illustration: .lockScreen
                )
                VisualSetupStepCard(
                    number: 4,
                    text: "Search Human Collective and choose a size.",
                    illustration: .chooseWidget
                )
            }
            .padding(.horizontal, HCTheme.pagePadding)
            .padding(.vertical, 18)
        }
        .background(HCTheme.background)
        .navigationTitle("How to add a widget")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WallpaperSetupView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("In the Shortcuts app")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(HCTheme.secondaryInk)
                    .padding(.bottom, 2)

                VisualSetupStepCard(
                    number: 1,
                    text: "Tap +. Add Get Daily Artifact Wallpaper, then Set Wallpaper Photo.",
                    illustration: .shortcutActions
                )
                VisualSetupStepCard(
                    number: 2,
                    text: "Name it Daily Artifact. Choose screens, then tap Play and allow access.",
                    illustration: .runShortcut
                )
                VisualSetupStepCard(
                    number: 3,
                    text: "Tap Automation, then +. Choose Time of Day and Daily.",
                    illustration: .automation
                )
                VisualSetupStepCard(
                    number: 4,
                    text: "Choose Run Immediately, select Daily Artifact, and tap Done.",
                    illustration: .shortcutTile
                )

                Link(destination: URL(string: "shortcuts://")!) {
                    Label("Open Shortcuts", systemImage: "arrow.up.forward.app")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(HCTheme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(HCTheme.ink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, HCTheme.pagePadding)
            .padding(.vertical, 18)
        }
        .background(HCTheme.background)
        .navigationTitle("How to set a wallpaper")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum SetupIllustration {
    case pressAndHold
    case addWidget
    case lockScreen
    case chooseWidget
    case shortcutActions
    case runShortcut
    case automation
    case shortcutTile
}

private struct VisualSetupStepCard: View {
    let number: Int
    let text: String
    let illustration: SetupIllustration

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text("Step \(number)")
                    .font(.title.weight(.bold))
                    .foregroundStyle(HCTheme.ink)

                Spacer(minLength: 18)

                SetupIllustrationView(kind: illustration)
            }

            Rectangle()
                .fill(HCTheme.line.opacity(0.7))
                .frame(height: HCTheme.hairline)

            Text(text)
                .font(.title3.weight(.medium))
                .foregroundStyle(HCTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HCTheme.surface, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
                .stroke(HCTheme.line.opacity(0.55), lineWidth: HCTheme.hairline)
        }
    }
}

private struct SetupIllustrationView: View {
    let kind: SetupIllustration

    var body: some View {
        Group {
            switch kind {
            case .pressAndHold:
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .frame(width: 82, height: 50)
            case .addWidget:
                Label("Add", systemImage: "plus")
                    .font(.headline.weight(.semibold))
                    .padding(.horizontal, 17)
                    .frame(height: 42)
            case .lockScreen:
                Label("Customize", systemImage: "lock.fill")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .frame(height: 42)
            case .chooseWidget:
                HStack(spacing: 8) {
                    Image(systemName: "photo.fill")
                    Text("Human\nCollective")
                        .font(.caption2.weight(.bold))
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 12)
                .frame(height: 52)
            case .shortcutActions:
                VStack(spacing: 5) {
                    Label("Get Artifact", systemImage: "sparkles")
                    Label("Set Wallpaper", systemImage: "photo")
                }
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 10)
                .frame(height: 54)
            case .runShortcut:
                Image(systemName: "play.fill")
                    .font(.system(size: 22, weight: .bold))
                    .frame(width: 82, height: 48)
            case .automation:
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.stack")
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(HCTheme.blueStone)
                    Image(systemName: "square.grid.2x2")
                }
                .font(.system(size: 19, weight: .semibold))
                .padding(.horizontal, 13)
                .frame(height: 48)
            case .shortcutTile:
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Daily Artifact")
                        .font(.caption.weight(.bold))
                }
                .padding(.horizontal, 12)
                .frame(height: 48)
            }
        }
        .foregroundStyle(HCTheme.ink)
        .background(HCTheme.clay.opacity(0.13), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct SupportHumanCollectiveView: View {
    let supportStore: SupportStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                SetupIntro(
                    title: "Support The Human Collective",
                    subtitle: "Never expected. Always appreciated."
                )

                supportCard
            }
            .padding(.horizontal, HCTheme.pagePadding)
            .padding(.vertical, 24)
        }
        .background(HCTheme.background)
        .navigationTitle("Support The Human Collective")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if supportStore.supportOptions.isEmpty, !supportStore.isBusy {
                await supportStore.loadProducts()
            }
        }
    }

    private var supportCard: some View {
        SetupCard(
            icon: "heart",
            title: "Choose a tip"
        ) {
            if supportStore.isBusy, supportStore.supportOptions.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)

                    Text("Loading support options…")
                        .font(.subheadline)
                        .foregroundStyle(HCTheme.secondaryInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else if supportStore.supportOptions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Support options are temporarily unavailable.")
                        .font(.headline)
                        .foregroundStyle(HCTheme.ink)

                    Text("Everything in Human Collective remains available for free.")
                        .font(.subheadline)
                        .foregroundStyle(HCTheme.secondaryInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            } else {
                ForEach(supportStore.supportOptions) { option in
                    SupportOptionButton(
                        option: option,
                        isBusy: supportStore.isBusy,
                        isPurchasing: supportStore.activePurchaseProductID == option.id
                    ) {
                        Task { await supportStore.purchase(productID: option.id) }
                    }
                }
            }

            if let message = supportStore.statusMessage {
                Label(message, systemImage: supportStore.purchaseState == .succeeded ? "heart.fill" : "info.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(supportStore.purchaseState == .succeeded ? HCTheme.clay : HCTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 3)
            }
        }
    }
}

private struct SupportOptionButton: View {
    let option: SupportStore.SupportOption
    let isBusy: Bool
    let isPurchasing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Text(option.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(HCTheme.ink)

                Spacer(minLength: 8)

                HStack(spacing: 7) {
                    if isPurchasing {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Text(option.displayPrice)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(HCTheme.blueStone)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HCTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(HCTheme.line.opacity(0.5), lineWidth: HCTheme.hairline)
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityLabel("\(option.title), \(option.displayPrice). \(option.subtitle)")
    }
}

private struct SetupIntro: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title.weight(.bold))
                .foregroundStyle(HCTheme.ink)

            if let subtitle {
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(HCTheme.secondaryInk)
            }
        }
    }
}

private struct SetupCard<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: Content

    init(
        icon: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(HCTheme.clay)
                    .frame(width: 42, height: 42)
                    .background(HCTheme.clay.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(HCTheme.ink)
            }

            VStack(alignment: .leading, spacing: 20) {
                content
            }
        }
        .padding(22)
        .background(HCTheme.surface, in: RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HCTheme.cardRadius, style: .continuous)
                .stroke(HCTheme.line.opacity(0.55), lineWidth: HCTheme.hairline)
        }
    }
}

private struct SetupBullet: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("•")
                .font(.title3.weight(.bold))
                .foregroundStyle(HCTheme.clay)

            Text(text)
                .font(.body.weight(.medium))
                .foregroundStyle(HCTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
    }
}
