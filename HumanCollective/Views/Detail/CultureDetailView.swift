import SwiftUI

struct CultureDetailView: View {
    @State private var viewModel: CultureDetailViewModel

    init(item: CultureItem, savedStore: SavedStore) {
        _viewModel = State(initialValue: CultureDetailViewModel(item: item, savedStore: savedStore))
    }

    var body: some View {
        let item = viewModel.item

        GeometryReader { proxy in
            ScrollView {
                CultureItemArticleView(
                    item: item,
                    isSaved: viewModel.isSaved,
                    showsSaveAction: false,
                    onToggleSaved: viewModel.toggleSaved
                )
                .frame(width: proxy.size.width, alignment: .leading)
            }
        }
        .background(HCTheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(HCTheme.background, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        viewModel.toggleSaved()
                    }
                } label: {
                    Image(systemName: viewModel.isSaved ? "bookmark.fill" : "bookmark")
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(viewModel.isSaved ? "Unsave" : "Save")
            }
        }
        .sensoryFeedback(.selection, trigger: viewModel.isSaved)
    }
}
