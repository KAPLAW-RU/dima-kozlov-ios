//
//  ContentView.swift
//  dima-kozlov-ios
//
//  Вдохновлено веб-дизайном dima-kozlov-site2
//

import SwiftUI

struct ContentView: View {
    @StateObject private var aiService = AIService()
    @State private var viewMode: ViewMode = .texts
    @State private var search = ""
    @State private var selectedStory: Story?
    @State private var visibleCount: Int = 18
    @State private var showMenu: Bool = false
    @State private var stories: [Story] = []
    @State private var storiesLoaded: Bool = false
    @State private var showSettings: Bool = false
    @State private var showGenerateStory: Bool = false

    private var filteredStories: [Story] {
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !term.isEmpty else { return stories }
        return stories.filter { story in
            story.title.lowercased().contains(term)
            || story.excerpt.lowercased().contains(term)
            || story.tags.contains(where: { $0.lowercased().contains(term) })
        }
    }
    
    // Загружаем рассказы из JSON файла в Bundle
    private func loadStories() {
        guard let url = Bundle.main.url(forResource: "stories", withExtension: "json") else {
            print("Файл stories.json не найден в Bundle")
            storiesLoaded = true
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            var loadedStories = try JSONDecoder().decode([Story].self, from: data)
            
            // Загружаем сгенерированные рассказы из UserDefaults
            if let generatedData = UserDefaults.standard.data(forKey: "generated_stories"),
               let generatedStories = try? JSONDecoder().decode([Story].self, from: generatedData) {
                loadedStories.append(contentsOf: generatedStories)
            }
            
            self.stories = loadedStories
            self.storiesLoaded = true
        } catch {
            print("Ошибка загрузки рассказов: \(error)")
            storiesLoaded = true
        }
    }
    
    // Сохраняем сгенерированный рассказ
    func saveGeneratedStory(_ story: Story) {
        // Загружаем существующие сгенерированные рассказы
        var generatedStories: [Story] = []
        if let data = UserDefaults.standard.data(forKey: "generated_stories"),
           let decoded = try? JSONDecoder().decode([Story].self, from: data) {
            generatedStories = decoded
        }
        
        // Добавляем новый рассказ (если его еще нет)
        if !generatedStories.contains(where: { $0.id == story.id }) {
            generatedStories.append(story)
            
            // Сохраняем обратно
            if let encoded = try? JSONEncoder().encode(generatedStories) {
                UserDefaults.standard.set(encoded, forKey: "generated_stories")
            }
            
            // Обновляем список рассказов
            if !stories.contains(where: { $0.id == story.id }) {
                stories.append(story)
            }
        }
    }

    private var visibleStories: [Story] {
        Array(filteredStories.prefix(visibleCount))
    }

    private func photoForStory(_ story: Story) -> Photo {
        if let direct = Photo.sample.first(where: { $0.id == story.associatedImageId }) {
            return direct
        }
        let hash = story.id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        var rng = PseudoRandom(hash: hash)
        let idx = Int(rng.next() % UInt64(Photo.sample.count))
        return Photo.sample[idx]
    }

    var body: some View {
        ZStack {
            PaperBackground()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        HeroHeader()
                            .padding(.horizontal, 20)
                            .padding(.top, 28)

                        SearchSection(search: $search, resultsCount: filteredStories.count)
                            .padding(.horizontal, 20)
                    .onChange(of: search) { _ in
                        visibleCount = 18
                    }
                        
                        // Кнопка генерации рассказа (если API ключ установлен)
                        if !aiService.aiToken.isEmpty && viewMode == .texts {
                            Button(action: {
                                showGenerateStory = true
                            }) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("Сгенерировать рассказ")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(Color.paper)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [Color.ink, Color.absurdRed.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: Color.absurdRed.opacity(0.3), radius: 8, y: 4)
                            }
                            .padding(.horizontal, 20)
                        }

                        switch viewMode {
                        case .texts:
                            if !storiesLoaded {
                                VStack {
                                    Spacer()
                                    Text("Загрузка...")
                                        .font(.system(size: 18, weight: .regular, design: .serif))
                                        .foregroundStyle(Color.ink.opacity(0.6))
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.bottom, 40)
                            } else {
                                StoriesGrid(stories: visibleStories) { story in
                                    selectedStory = story
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)

                                if visibleStories.count < filteredStories.count {
                                    ShowMoreButton(
                                        remaining: filteredStories.count - visibleStories.count,
                                        action: { visibleCount = min(visibleCount + 18, filteredStories.count) }
                                    )
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 28)
                                } else {
                                    Spacer(minLength: 12)
                                        .frame(height: 12)
                                }
                            }
                        case .photos:
                            PhotoGrid(photos: Photo.sample)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 40)
                        }
                    }
                }
            }
        }
        .modifier(StoryPresentationModifier(selectedStory: $selectedStory, photoForStory: photoForStory))
        .overlay(alignment: .topTrailing) {
            MenuButton(
                showMenu: $showMenu,
                currentMode: $viewMode,
                onGenerateStory: { showGenerateStory = true },
                onSettings: { showSettings = true }
            )
            .padding(.trailing, 16)
            .padding(.top, 20)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(aiService: aiService)
        }
        .sheet(isPresented: $showGenerateStory) {
            GenerateStoryView(aiService: aiService, onStoryGenerated: { story in
                saveGeneratedStory(story)
            })
        }
        .onAppear {
            if !storiesLoaded {
                loadStories()
            }
        }
    }
}

// MARK: - Subviews

private struct MenuButton: View {
    @Binding var showMenu: Bool
    @Binding var currentMode: ViewMode
    var onGenerateStory: () -> Void
    var onSettings: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showMenu.toggle()
                }
            } label: {
                VStack(spacing: 5) {
                    Rectangle().fill(Color.ink).frame(width: 26, height: 3).cornerRadius(2)
                    Rectangle().fill(Color.ink).frame(width: 26, height: 3).cornerRadius(2)
                    Rectangle().fill(Color.ink).frame(width: 26, height: 3).cornerRadius(2)
                }
                .padding(12)
                .background(Color.paper.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.ink.opacity(0.12), lineWidth: 1)
                )
            }

            if showMenu {
                VStack(alignment: .leading, spacing: 10) {
                    MenuItem(label: "Тексты", isActive: currentMode == .texts) {
                        currentMode = .texts
                        showMenu = false
                    }
                    MenuItem(label: "Фотография", isActive: currentMode == .photos) {
                        currentMode = .photos
                        showMenu = false
                    }
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    MenuItem(label: "Сгенерировать рассказ", isActive: false, icon: "sparkles") {
                        onGenerateStory()
                        showMenu = false
                    }
                    MenuItem(label: "Настройки", isActive: false, icon: "gearshape") {
                        onSettings()
                        showMenu = false
                    }
                }
                .padding(14)
                .background(Color.paper)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.ink.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 12, y: 6)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

private struct MenuItem: View {
    let label: String
    let isActive: Bool
    let action: () -> Void
    var icon: String? = nil

    var body: some View {
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.ink.opacity(0.7))
                        .frame(width: 20)
                }
                Text(label)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                if isActive {
                    Circle()
                        .fill(Color.absurdRed)
                        .frame(width: 8, height: 8)
                }
            }
            .foregroundStyle(Color.ink)
            .padding(.vertical, 4)
        }
    }
}

private struct HeroHeader: View {
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        let isCompact = hSize == .compact
        let topSize: CGFloat = isCompact ? 64 : 80
        let bottomSize: CGFloat = isCompact ? 74 : 90

        VStack(alignment: .leading, spacing: 18) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: -10) {
                    Text("ДИМА")
                        .font(.system(size: topSize, weight: .black, design: .serif))
                        .kerning(-3)
                        .foregroundStyle(Color.ink)
                        .shadow(color: Color.ink.opacity(0.08), radius: 14, x: 0, y: 8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    LinearGradient(colors: [Color.ink, Color.absurdRed], startPoint: .leading, endPoint: .trailing)
                        .mask(
                            Text("КОЗЛОВ")
                                .font(.system(size: bottomSize, weight: .black, design: .serif))
                                .kerning(-2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .offset(x: 10)
                }

                Circle()
                    .stroke(Color.absurdRed.opacity(0.2), lineWidth: 5)
                    .frame(width: 80, height: 80)
                    .offset(x: 10, y: -20)
                    .overlay(
                        Circle()
                            .fill(Color.ink.opacity(0.08))
                            .frame(width: 24, height: 24)
                            .offset(x: -8, y: 40)
                    )
            }

            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Осторожная, злая собака.")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.ink)

                    Text("Абсурд. Депрессия. Юмор.")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.absurdRed)
                }

                Spacer()

                Text("Выставка текстов и образов.\nПожалуйста, не кормите смыслы, они и так толстые.")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Color.ink.opacity(0.6))
            }
            .padding(.top, 6)
            .overlay(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.ink)
                    .frame(height: 3)
                    .offset(y: -10)
            }
        }
    }
}

private struct SearchSection: View {
    @Binding var search: String
    var resultsCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                TextField("ПОИСК...", text: $search)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .tint(Color.absurdRed)
                    .foregroundStyle(Color.ink)

                Spacer()

                Text("\(resultsCount) объектов"
                    .uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.ink)
                    .foregroundStyle(Color.paper)
            }

            Rectangle()
                .fill(Color.ink.opacity(0.12))
                .frame(height: 1.5)
        }
        .padding(.vertical, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.ink.opacity(0.05), radius: 10, y: 6)
    }
}

private struct StoriesGrid: View {
    let stories: [Story]
    var onSelect: (Story) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(stories) { story in
                StoryCard(story: story)
                    .onTapGesture { onSelect(story) }
            }
        }
        .padding(.top, 4)
    }
}

private struct ShowMoreButton: View {
    let remaining: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Показать ещё (\(remaining))")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .textCase(.uppercase)
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.ink, lineWidth: 1.4)
                )
                .foregroundStyle(Color.ink)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct PhotoGrid: View {
    let photos: [Photo]
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(photos) { photo in
                    ZStack(alignment: .bottomLeading) {
                        Group {
                            if let bundleURL = photo.bundleURL {
                                AsyncImage(url: bundleURL) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 180)
                                            .clipped()
                                            .grayscale(0.3)
                                            .overlay(Color.black.opacity(0.08))
                                    case .failure(_):
                                        Color.gray.opacity(0.2)
                                            .overlay(Image(systemName: "photo").font(.largeTitle).opacity(0.4))
                                    case .empty:
                                        Color.paper.opacity(0.4)
                                            .overlay(ProgressView())
                                    @unknown default:
                                        Color.gray.opacity(0.2)
                                    }
                                }
                                .frame(height: 180)
                            } else {
                                Color.gray.opacity(0.2)
                                    .frame(height: 180)
                                    .overlay(Image(systemName: "photo").font(.largeTitle).opacity(0.4))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.ink.opacity(0.15), lineWidth: 1)
                        )

                        Text(photo.caption)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(8)
                            .background(Color.ink.opacity(0.8))
                            .foregroundStyle(Color.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .padding(10)
                    }
                }
            }
        }
    }
}

struct StoryCard: View {
    let story: Story

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(story.date.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.ink.opacity(0.5))

                Text(story.title)
                    .font(.system(size: 24, weight: .heavy, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(Color.ink)
            }

            Text(story.excerpt)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(Color.ink.opacity(0.75))
                .lineLimit(3)
                .minimumScaleFactor(0.9)

            HStack {
                Spacer()
                Text("Читать →")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.paper)
        .overlay(alignment: .leading) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                Path { path in
                    // Левая вертикаль
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: 0, y: h))
                    // Нижняя линия
                    path.move(to: CGPoint(x: -8, y: h))
                    path.addLine(to: CGPoint(x: w + 8, y: h))
                }
                .stroke(Color.ink.opacity(0.5), lineWidth: 1.6)
            }
        }
    }
}

private struct StoryReader: View {
    let story: Story
    let photo: Photo
    @Environment(\.dismiss) private var dismiss
    
    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    private var titleFontSize: CGFloat {
        isPad ? 48 : 30
    }
    
    private var contentFontSize: CGFloat {
        isPad ? 24 : 17
    }
    
    private var dateFontSize: CGFloat {
        isPad ? 14 : 12
    }
    
    private var captionFontSize: CGFloat {
        isPad ? 14 : 12
    }
    
    private var horizontalPadding: CGFloat {
        isPad ? 80 : 24
    }
    
    private var verticalPadding: CGFloat {
        isPad ? 48 : 24
    }
    
    private var spacing: CGFloat {
        isPad ? 32 : 20
    }
    
    private var lineSpacing: CGFloat {
        isPad ? 10 : 6
    }
    
    private var imageMaxHeight: CGFloat {
        isPad ? 500 : 320
    }
    
    private var imageHeight: CGFloat {
        isPad ? 300 : 220
    }
    
    private var contentMaxWidth: CGFloat {
        isPad ? 900 : .infinity
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: spacing) {
                    Text(story.title)
                        .font(.system(size: titleFontSize, weight: .black, design: .serif))
                        .foregroundStyle(Color.ink)

                    Text(story.date.uppercased())
                        .font(.system(size: dateFontSize, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.ink.opacity(0.55))

                    Text(story.content)
                        .font(.system(size: contentFontSize, weight: .regular, design: .serif))
                        .foregroundStyle(Color.ink.opacity(0.85))
                        .lineSpacing(lineSpacing)

                    Divider()

                    if let bundleURL = photo.bundleURL {
                        AsyncImage(url: bundleURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxHeight: imageMaxHeight)
                                    .clipped()
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.ink.opacity(0.15), lineWidth: 1)
                                    )
                            case .failure(_):
                                Color.gray.opacity(0.2)
                                    .frame(height: imageHeight)
                                    .overlay(Image(systemName: "photo").font(.largeTitle).opacity(0.4))
                                    .cornerRadius(16)
                            case .empty:
                                Color.paper.opacity(0.4)
                                    .frame(height: imageHeight)
                                    .overlay(ProgressView())
                                    .cornerRadius(16)
                            @unknown default:
                                Color.gray.opacity(0.2)
                                    .frame(height: imageHeight)
                                    .cornerRadius(16)
                            }
                        }
                    } else {
                        Color.gray.opacity(0.2)
                            .frame(height: imageHeight)
                            .overlay(Image(systemName: "photo").font(.largeTitle).opacity(0.4))
                            .cornerRadius(16)
                    }

                    Text(photo.caption)
                        .font(.system(size: captionFontSize, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.ink.opacity(0.7))
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(maxWidth: contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(Color.paper)
            
            // Кнопка закрытия для iPad
            if isPad {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.ink.opacity(0.6))
                        .background(Color.paper.opacity(0.9))
                        .clipShape(Circle())
                }
                .padding(20)
            }
        }
    }
}

private struct PlaceholderCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 22, weight: .heavy, design: .serif))
                .foregroundStyle(Color.ink)
            Text(subtitle)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(Color.ink.opacity(0.7))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1.3, dash: [5, 5], dashPhase: 2))
                .foregroundStyle(Color.ink.opacity(0.25))
        )
    }
}

// MARK: - Models & Helpers

private enum ViewMode: CaseIterable {
    case texts, photos

    var title: String {
        switch self {
        case .texts: "Тексты"
        case .photos: "Фотография"
        }
    }
}

struct Story: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let date: String
    let excerpt: String
    let content: String
    let tags: [String]
    let associatedImageId: String?

    static let sample: [Story] = [
        .init(
            id: "a1",
            title: "У всего есть объяснение",
            date: "Сторона A",
            excerpt: "У всего есть объяснение, у каждого мелкого события есть простая ясная причина...",
            content: """
У всего есть объяснение, у каждого мелкого события есть простая ясная причина. Вот ты сел за компьютер, а он не работает, а ты просто провод не включил.

В этом смысле в мире нет мистики. Мистика возникает, когда мы пытаемся упростить мир до модели, которая помещается в голову. Всё, что не учтено моделью, кажется непостижимым, но на самом деле просто мелкие причины.
""",
            tags: ["логика", "мистика", "быт"],
            associatedImageId: nil
        ),
        .init(
            id: "a2",
            title: "Информация",
            date: "Сторона A",
            excerpt: "Информация, странное слово, дающее только вопросы, и не дающее ответов...",
            content: """
Информация — слово, которое втягивает в себя всё, как чёрная дыра. Сколько информации в мире? Где она хранится?

Информация рождается во взаимодействии. Цветку наплевать, хранит ли он что-то — он просто растёт. Сложность исчезает, если вспомнить, что всё есть одно, и мы уже знаем друг о друге больше, чем кажется.
""",
            tags: ["черная дыра", "цветок", "вселенная"],
            associatedImageId: nil
        ),
        .init(
            id: "a3",
            title: "Весело",
            date: "Сторона A",
            excerpt: "Весело, когда замечаешь, особенно когда замечаешь неожиданно...",
            content: """
Тот, кто ничего не ждёт, весел всегда. Ожидание превращает время в поезд «Раньше–Позже», который идёт по кольцу. Мы в нём, пока делим жизнь на «до» и «после».

Как выйти? Просто не садиться в поезд. Когда исчезают «раньше» и «позже», поезд растворяется, и остаётся ясное небо над головой.
""",
            tags: ["поезд", "ожидание", "оптимизм"],
            associatedImageId: nil
        ),
        .init(
            id: "b1",
            title: "25 минут",
            date: "Сторона B",
            excerpt: "25 минут, не очень много и не очень мало...",
            content: """
25 минут — странная величина: прохладно, но не холодно; достаточно, чтобы почувствовать перемену, но не чтобы застыть.

Мир одновременно неподвижен и непрерывно движется. Обе правды верны, и с этим ничего не сделать — кроме как принять свежий воздух после дождя.
""",
            tags: ["время", "прохлада", "движение"],
            associatedImageId: nil
        ),
        .init(
            id: "c1",
            title: "Квази",
            date: "Bonus Track",
            excerpt: "Квазипроизводительный бензонасос позволяет нам быть самым быстрым табором...",
            content: """
Мы улетели к звёздам ещё в прошлый вторник и думаем пробыть там до четверга, тоже прошлого. Скорости высоки, время странно.

Кажется остановка. Или бензин кончился. Нужно овса для лошадей искать.
""",
            tags: ["феррари", "космос", "овёс"],
            associatedImageId: nil
        )
    ]
}

private struct Photo: Identifiable, Equatable {
    let id: String
    let url: String
    let caption: String
    
    // Получаем URL для загрузки фото из Bundle
    var bundleURL: URL? {
        // Фото находятся в корне Bundle
        let fileName = (url as NSString).lastPathComponent
        let fileNameWithoutExt = (fileName as NSString).deletingPathExtension
        let fileExtension = (fileName as NSString).pathExtension
        
        // Пробуем найти файл в Bundle
        if let url = Bundle.main.url(forResource: fileNameWithoutExt, withExtension: fileExtension) {
            return url
        }
        
        // Если не нашли, пробуем с другим регистром расширения (для .JPG vs .jpg)
        if fileExtension.lowercased() != fileExtension {
            if let url = Bundle.main.url(forResource: fileNameWithoutExt, withExtension: fileExtension.lowercased()) {
                return url
            }
        } else {
            if let url = Bundle.main.url(forResource: fileNameWithoutExt, withExtension: fileExtension.uppercased()) {
                return url
            }
        }
        
        print("⚠️ Не найдено фото в Bundle: \(fileName)")
        return nil
    }

    // Фото загружаются из Bundle (локальные ресурсы приложения)
    static let sample: [Photo] = [
        .init(id: "pict000", url: "pict000.JPG", caption: "pict000"),
        .init(id: "pict001", url: "pict001.jpg", caption: "pict001"),
        .init(id: "pict002", url: "pict002.jpg", caption: "pict002"),
        .init(id: "pict003", url: "pict003.jpg", caption: "pict003"),
        .init(id: "pict004", url: "pict004.jpg", caption: "pict004"),
        .init(id: "pict005", url: "pict005.jpg", caption: "pict005"),
        .init(id: "pict006", url: "pict006.jpg", caption: "pict006"),
        .init(id: "pict007", url: "pict007.jpg", caption: "pict007"),
        .init(id: "pict008", url: "pict008.jpg", caption: "pict008"),
        .init(id: "pict009", url: "pict009.JPG", caption: "pict009"),
        .init(id: "pict010", url: "pict010.jpg", caption: "pict010"),
        .init(id: "pict011", url: "pict011.jpg", caption: "pict011"),
        .init(id: "pict012", url: "pict012.jpg", caption: "pict012"),
        .init(id: "pict013", url: "pict013.jpg", caption: "pict013"),
        .init(id: "pict014", url: "pict014.jpg", caption: "pict014"),
        .init(id: "pict015", url: "pict015.jpg", caption: "pict015"),
        .init(id: "pict016", url: "pict016.jpg", caption: "pict016"),
        .init(id: "pict017", url: "pict017.jpg", caption: "pict017"),
        .init(id: "pict018", url: "pict018.jpg", caption: "pict018"),
        .init(id: "pict019", url: "pict019.jpg", caption: "pict019"),
        .init(id: "pict020", url: "pict020.jpg", caption: "pict020"),
        .init(id: "pict021", url: "pict021.jpg", caption: "pict021"),
        .init(id: "pict022", url: "pict022.jpg", caption: "pict022"),
        .init(id: "pict023", url: "pict023.jpg", caption: "pict023"),
        .init(id: "pict024", url: "pict024.jpg", caption: "pict024"),
        .init(id: "pict025", url: "pict025.jpg", caption: "pict025"),
        .init(id: "pict026", url: "pict026.jpg", caption: "pict026"),
        .init(id: "pict027", url: "pict027.jpg", caption: "pict027"),
        .init(id: "pict028", url: "pict028.jpg", caption: "pict028"),
        .init(id: "pict029", url: "pict029.jpg", caption: "pict029"),
        .init(id: "pict030", url: "pict030.jpg", caption: "pict030"),
        .init(id: "pict031", url: "pict031.jpg", caption: "pict031"),
        .init(id: "pict032", url: "pict032.jpg", caption: "pict032"),
        .init(id: "pict033", url: "pict033.jpg", caption: "pict033"),
        .init(id: "pict034", url: "pict034.jpg", caption: "pict034"),
        .init(id: "pict035", url: "pict035.jpg", caption: "pict035"),
        .init(id: "pict036", url: "pict036.jpg", caption: "pict036"),
        .init(id: "pict037", url: "pict037.jpg", caption: "pict037"),
        .init(id: "pict038", url: "pict038.jpg", caption: "pict038"),
        .init(id: "pict039", url: "pict039.jpg", caption: "pict039"),
        .init(id: "pict040", url: "pict040.jpg", caption: "pict040"),
        .init(id: "pict041", url: "pict041.jpg", caption: "pict041"),
        .init(id: "pict042", url: "pict042.jpg", caption: "pict042"),
        .init(id: "pict043", url: "pict043.jpg", caption: "pict043"),
        .init(id: "pict044", url: "pict044.jpg", caption: "pict044"),
        .init(id: "pict045", url: "pict045.jpg", caption: "pict045"),
        .init(id: "pict046", url: "pict046.jpg", caption: "pict046"),
        .init(id: "pict047", url: "pict047.jpg", caption: "pict047"),
        .init(id: "pict048", url: "pict048.jpg", caption: "pict048"),
        .init(id: "pict049", url: "pict049.jpg", caption: "pict049"),
        .init(id: "pict050", url: "pict050.jpg", caption: "pict050"),
        .init(id: "pict051", url: "pict051.jpg", caption: "pict051"),
        .init(id: "pict052", url: "pict052.jpg", caption: "pict052"),
        .init(id: "pict053", url: "pict053.jpg", caption: "pict053"),
        .init(id: "pict054", url: "pict054.jpg", caption: "pict054"),
        .init(id: "pict055", url: "pict055.jpg", caption: "pict055"),
        .init(id: "pict056", url: "pict056.jpg", caption: "pict056"),
        .init(id: "pict057", url: "pict057.jpg", caption: "pict057"),
        .init(id: "pict058", url: "pict058.jpg", caption: "pict058"),
        .init(id: "pict059", url: "pict059.jpg", caption: "pict059"),
        .init(id: "pict060", url: "pict060.jpg", caption: "pict060"),
        .init(id: "pict061", url: "pict061.jpg", caption: "pict061"),
        .init(id: "pict062", url: "pict062.jpg", caption: "pict062"),
        .init(id: "pict063", url: "pict063.jpg", caption: "pict063"),
        .init(id: "pict064", url: "pict064.jpg", caption: "pict064"),
        .init(id: "pict065", url: "pict065.jpg", caption: "pict065"),
        .init(id: "pict066", url: "pict066.jpg", caption: "pict066"),
        .init(id: "pict067", url: "pict067.jpg", caption: "pict067"),
        .init(id: "pict068", url: "pict068.jpg", caption: "pict068"),
        .init(id: "pict069", url: "pict069.jpg", caption: "pict069"),
        .init(id: "pict070", url: "pict070.jpg", caption: "pict070"),
        .init(id: "pict071", url: "pict071.jpg", caption: "pict071"),
        .init(id: "pict072", url: "pict072.jpg", caption: "pict072"),
        .init(id: "pict073", url: "pict073.jpg", caption: "pict073"),
        .init(id: "pict074", url: "pict074.jpg", caption: "pict074"),
        .init(id: "pict075", url: "pict075.jpg", caption: "pict075"),
        .init(id: "pict076", url: "pict076.jpg", caption: "pict076"),
        .init(id: "pict077", url: "pict077.jpg", caption: "pict077"),
        .init(id: "pict078", url: "pict078.jpg", caption: "pict078"),
        .init(id: "pict079", url: "pict079.jpg", caption: "pict079"),
        .init(id: "pict080", url: "pict080.jpg", caption: "pict080"),
        .init(id: "pict081", url: "pict081.jpg", caption: "pict081"),
        .init(id: "pict082", url: "pict082.jpg", caption: "pict082"),
        .init(id: "pict083", url: "pict083.jpg", caption: "pict083"),
        .init(id: "pict084", url: "pict084.jpg", caption: "pict084"),
        .init(id: "pict085", url: "pict085.jpg", caption: "pict085"),
        .init(id: "pict086", url: "pict086.jpg", caption: "pict086"),
        .init(id: "pict087", url: "pict087.jpg", caption: "pict087"),
        .init(id: "pict088", url: "pict088.jpg", caption: "pict088"),
        .init(id: "pict089", url: "pict089.jpg", caption: "pict089"),
        .init(id: "pict090", url: "pict090.jpg", caption: "pict090"),
        .init(id: "pict091", url: "pict091.jpg", caption: "pict091"),
        .init(id: "pict092", url: "pict092.jpg", caption: "pict092"),
        .init(id: "pict093", url: "pict093.jpg", caption: "pict093"),
        .init(id: "pict094", url: "pict094.jpg", caption: "pict094"),
        .init(id: "pict095", url: "pict095.jpg", caption: "pict095"),
        .init(id: "pict096", url: "pict096.jpg", caption: "pict096"),
        .init(id: "pict097", url: "pict097.jpg", caption: "pict097"),
        .init(id: "pict098", url: "pict098.jpg", caption: "pict098"),
        .init(id: "pict099", url: "pict099.jpg", caption: "pict099"),
        .init(id: "pict100", url: "pict100.jpg", caption: "pict100"),
        .init(id: "pict101", url: "pict101.jpg", caption: "pict101"),
        .init(id: "pict102", url: "pict102.jpg", caption: "pict102"),
        .init(id: "pict103", url: "pict103.jpg", caption: "pict103"),
        .init(id: "pict104", url: "pict104.jpg", caption: "pict104"),
        .init(id: "pict105", url: "pict105.jpg", caption: "pict105"),
        .init(id: "pict106", url: "pict106.jpg", caption: "pict106"),
        .init(id: "pict107", url: "pict107.jpg", caption: "pict107"),
        .init(id: "pict108", url: "pict108.jpg", caption: "pict108"),
        .init(id: "pict109", url: "pict109.jpg", caption: "pict109"),
        .init(id: "pict110", url: "pict110.jpg", caption: "pict110"),
        .init(id: "pict111", url: "pict111.jpg", caption: "pict111"),
        .init(id: "pict112", url: "pict112.jpg", caption: "pict112"),
        .init(id: "pict113", url: "pict113.jpg", caption: "pict113"),
        .init(id: "pict114", url: "pict114.jpg", caption: "pict114"),
        .init(id: "pict115", url: "pict115.jpg", caption: "pict115"),
        .init(id: "pict116", url: "pict116.jpg", caption: "pict116"),
        .init(id: "pict117", url: "pict117.JPG", caption: "pict117"),
        .init(id: "pict118", url: "pict118.jpg", caption: "pict118"),
        .init(id: "pict119", url: "pict119.JPG", caption: "pict119"),
        .init(id: "pict120", url: "pict120.jpg", caption: "pict120"),
        .init(id: "pict121", url: "pict121.JPG", caption: "pict121"),
        .init(id: "pict122", url: "pict122.JPG", caption: "pict122"),
        .init(id: "pict123", url: "pict123.JPG", caption: "pict123"),
        .init(id: "pict124", url: "pict124.JPG", caption: "pict124"),
        .init(id: "pict125", url: "pict125.JPG", caption: "pict125"),
        .init(id: "pict126", url: "pict126.jpg", caption: "pict126")
    ]
}

// Псевдослучайный генератор с фиксированным seed (по id истории)
private struct PseudoRandom: RandomNumberGenerator {
    private var state: UInt64

    init(hash: Int) {
        let seed = UInt64(bitPattern: Int64(hash))
        self.state = seed == 0 ? 0x9e3779b97f4a7c15 : seed
    }

    mutating func next() -> UInt64 {
        // Xorshift64*
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545F4914F6CDD1D
    }
}

struct PaperBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color.paper, Color.paper.opacity(0.9)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(
            ZStack {
                Circle()
                    .fill(Color.absurdRed.opacity(0.04))
                    .frame(width: 220, height: 220)
                    .offset(x: -120, y: -260)
                Circle()
                    .stroke(Color.ink.opacity(0.05), lineWidth: 18)
                    .frame(width: 260, height: 260)
                    .offset(x: 160, y: 320)
            }
        )
    }
}

// MARK: - View Modifiers

private struct StoryPresentationModifier: ViewModifier {
    @Binding var selectedStory: Story?
    let photoForStory: (Story) -> Photo
    
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            content
                .fullScreenCover(item: $selectedStory) { story in
                    StoryReader(story: story, photo: photoForStory(story))
                }
        } else {
            content
                .sheet(item: $selectedStory) { story in
                    StoryReader(story: story, photo: photoForStory(story))
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
        }
    }
}

// MARK: - Colors

extension Color {
    static let ink = Color(hex: "#0c0c0c")
    static let absurdRed = Color(hex: "#e63946")
    static let paper = Color(hex: "#f8f4ec")

    init(hex: String) {
        let hex = hex.replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

#Preview {
    ContentView()
}
