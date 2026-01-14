//
//  GenerateStoryView.swift
//  dima-kozlov-ios
//
//  Экран для генерации рассказов с помощью AI
//

import SwiftUI

struct GenerateStoryView: View {
    @ObservedObject var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    @State private var prompt: String = ""
    @State private var generatedStory: Story?
    @State private var errorMessage: String?
    @State private var showError: Bool = false
    @State private var showStoryReader: Bool = false
    var onStoryGenerated: ((Story) -> Void)? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                PaperBackground()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Заголовок
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ГЕНЕРАЦИЯ РАССКАЗА")
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.ink)
                            
                            Rectangle()
                                .fill(Color.ink.opacity(0.12))
                                .frame(height: 1.5)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Поле для промпта
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Тема рассказа (необязательно)")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.ink)
                            
                            TextField("Например: про время, про ожидание, про абсурд...", text: $prompt, axis: .vertical)
                                .textInputAutocapitalization(.sentences)
                                .font(.system(size: 15, design: .rounded))
                                .padding(12)
                                .background(Color.paper)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.ink.opacity(0.2), lineWidth: 1)
                                )
                                .lineLimit(3...6)
                            
                            Text("Оставьте пустым для свободной темы")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Color.ink.opacity(0.6))
                        }
                        .padding(16)
                        .background(Color.paper.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.ink.opacity(0.15), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        
                        // Кнопка генерации
                        Button(action: {
                            Task {
                                await generateStory()
                            }
                        }) {
                            HStack {
                                if aiService.isGenerating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color.paper))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(aiService.isGenerating ? "Генерация..." : "Сгенерировать рассказ")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(Color.paper)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                aiService.isGenerating || aiService.aiToken.isEmpty
                                ? Color.ink.opacity(0.5)
                                : Color.ink
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .disabled(aiService.isGenerating || aiService.aiToken.isEmpty)
                        .padding(.horizontal, 20)
                        
                        if aiService.aiToken.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.absurdRed)
                                Text("Для генерации необходимо установить API ключ в настройках")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.ink.opacity(0.7))
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Результат генерации
                        if let story = generatedStory {
                            VStack(alignment: .leading, spacing: 16) {
                                Divider()
                                    .padding(.horizontal, 20)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Сгенерированный рассказ")
                                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Color.ink.opacity(0.7))
                                    
                                    StoryCard(story: story)
                                        .onTapGesture {
                                            showStoryReader = true
                                        }
                                }
                                .padding(16)
                                .background(Color.paper.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.ink.opacity(0.15), lineWidth: 1)
                                )
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink)
                }
            }
            .alert("Ошибка", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Неизвестная ошибка")
            }
            .fullScreenCover(isPresented: $showStoryReader) {
                if let story = generatedStory {
                    StoryReaderView(story: story)
                }
            }
        }
    }
    
    private func generateStory() async {
        errorMessage = nil
        generatedStory = nil
        
        do {
            let story = try await aiService.generateStory(prompt: prompt)
            generatedStory = story
            onStoryGenerated?(story)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// Простой просмотрщик рассказа для сгенерированных рассказов
struct StoryReaderView: View {
    let story: Story
    @Environment(\.dismiss) private var dismiss
    
    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: isPad ? 32 : 20) {
                    Text(story.title)
                        .font(.system(size: isPad ? 48 : 30, weight: .black, design: .serif))
                        .foregroundStyle(Color.ink)
                    
                    Text(story.date.uppercased())
                        .font(.system(size: isPad ? 14 : 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.ink.opacity(0.55))
                    
                    Text(story.content)
                        .font(.system(size: isPad ? 24 : 17, weight: .regular, design: .serif))
                        .foregroundStyle(Color.ink.opacity(0.85))
                        .lineSpacing(isPad ? 10 : 6)
                }
                .padding(.horizontal, isPad ? 80 : 24)
                .padding(.vertical, isPad ? 48 : 24)
                .frame(maxWidth: isPad ? 900 : .infinity)
            }
            .background(Color.paper)
            
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
