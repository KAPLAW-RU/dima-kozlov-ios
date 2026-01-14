//
//  AIService.swift
//  dima-kozlov-ios
//
//  Сервис для работы с DeepSeek API для генерации рассказов
//

import Foundation
import Combine

enum AIServiceError: LocalizedError {
    case noResponse
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError
    case noAPIKey
    
    var errorDescription: String? {
        switch self {
        case .noResponse:
            return "Нет ответа от сервера"
        case .invalidURL:
            return "Неверный URL"
        case .invalidResponse:
            return "Неверный ответ от сервера"
        case .httpError(let code):
            if code == 401 {
                return "Ошибка авторизации (401): Неверный API ключ. Проверьте ключ в настройках."
            } else if code == -1001 {
                return "Запрос превысил время ожидания. Проверьте интернет-соединение и попробуйте снова."
            } else {
                return "Ошибка HTTP: \(code)"
            }
        case .decodingError:
            return "Ошибка декодирования ответа"
        case .noAPIKey:
            return "API ключ не установлен"
        }
    }
}

struct DeepSeekRequest: Codable {
    let model: String
    let messages: [DeepSeekMessage]
    let max_tokens: Int
    let temperature: Double
    
    struct DeepSeekMessage: Codable {
        let role: String
        let content: String
    }
}

struct DeepSeekResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let content: String
        }
    }
}

@MainActor
class AIService: ObservableObject {
    @Published var aiToken: String = ""
    @Published var isGenerating: Bool = false
    
    private var aiAvailable: Bool {
        !aiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    init() {
        // Загружаем сохраненный API ключ
        if let savedToken = UserDefaults.standard.string(forKey: "deepseek_api_key") {
            self.aiToken = savedToken
        }
    }
    
    func saveAPIKey(_ key: String) {
        // Очищаем ключ от лишних пробелов
        let cleanedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        self.aiToken = cleanedKey
        UserDefaults.standard.set(cleanedKey, forKey: "deepseek_api_key")
        print("💾 API ключ сохранен (длина: \(cleanedKey.count) символов)")
    }
    
    /// Основной метод для отправки запросов к DeepSeek API
    func deepSeekRequestContent(systemText: String, userText: String, temperature: Double = 0.7, maxTokens: Int = 2000) async throws -> String {
        guard aiAvailable else {
            throw AIServiceError.noAPIKey
        }
        
        guard let url = URL(string: "https://api.deepseek.com/v1/chat/completions") else {
            throw AIServiceError.invalidURL
        }
        
        // Создаем конфигурацию с увеличенным таймаутом
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0 // 60 секунд
        config.timeoutIntervalForResource = 120.0 // 120 секунд для всего ресурса
        let session = URLSession(configuration: config)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Очищаем API ключ от лишних пробелов
        let cleanedToken = aiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        request.setValue("Bearer \(cleanedToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = DeepSeekRequest(
            model: "deepseek-chat",
            messages: [
                DeepSeekRequest.DeepSeekMessage(role: "system", content: systemText),
                DeepSeekRequest.DeepSeekMessage(role: "user", content: userText)
            ],
            max_tokens: maxTokens,
            temperature: temperature
        )
        
        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
            
            print("🔵 Отправка запроса к DeepSeek API...")
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }
            
            print("🔵 HTTP статус: \(httpResponse.statusCode)")
            
            // Специальная обработка для HTTP 401
            if httpResponse.statusCode == 401 {
                print("❌ HTTP 401: Неверный API ключ или ключ не авторизован")
                throw AIServiceError.httpError(401)
            }
            
            guard httpResponse.statusCode == 200 else {
                // Пытаемся прочитать тело ответа для более детальной ошибки
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ DeepSeek API ошибка \(httpResponse.statusCode): \(errorData)")
                } else {
                    print("❌ DeepSeek API HTTP error: \(httpResponse.statusCode)")
                }
                throw AIServiceError.httpError(httpResponse.statusCode)
            }
            
            let decodedResponse = try JSONDecoder().decode(DeepSeekResponse.self, from: data)
            
            guard let choice = decodedResponse.choices.first else {
                throw AIServiceError.noResponse
            }
            
            let content = choice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            print("✅ Успешно получен ответ от DeepSeek API")
            return cleanAIResponse(content)
            
        } catch let error as AIServiceError {
            throw error
        } catch let urlError as URLError {
            // Обработка ошибок сети
            print("❌ Ошибка сети: \(urlError.localizedDescription)")
            if urlError.code == .timedOut {
                throw AIServiceError.httpError(-1001) // Используем код таймаута
            } else {
                throw AIServiceError.httpError(urlError.code.rawValue)
            }
        } catch {
            print("❌ Ошибка в deepSeekRequestContent: \(error)")
            throw AIServiceError.decodingError
        }
    }
    
    /// Загрузка рассказов из JSON файла
    private func loadStories() -> [Story] {
        guard let url = Bundle.main.url(forResource: "stories", withExtension: "json") else {
            print("⚠️ Файл stories.json не найден в Bundle")
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let stories = try JSONDecoder().decode([Story].self, from: data)
            // Исключаем AI-сгенерированные рассказы
            return stories.filter { !$0.id.hasPrefix("ai_") }
        } catch {
            print("⚠️ Ошибка загрузки рассказов: \(error)")
            return []
        }
    }
    
    /// Выбор случайных рассказов для примера
    private func selectRandomStories(_ stories: [Story], count: Int = 3) -> [Story] {
        guard !stories.isEmpty else { return [] }
        let shuffled = stories.shuffled()
        return Array(shuffled.prefix(min(count, stories.count)))
    }
    
    /// Форматирование рассказа для промпта
    private func formatStoryForPrompt(_ story: Story) -> String {
        // Ограничиваем длину контента, чтобы промпт не был слишком длинным
        let maxContentLength = 800
        let content = story.content.count > maxContentLength 
            ? String(story.content.prefix(maxContentLength)) + "..." 
            : story.content
        
        return """
        ---
        Название: \(story.title)
        Дата: \(story.date)
        
        \(content)
        ---
        """
    }
    
    /// Генерация рассказа в стиле Димы Козлова
    func generateStory(prompt: String = "") async throws -> Story {
        isGenerating = true
        defer { isGenerating = false }
        
        // Загружаем рассказы и выбираем случайные для примера
        let allStories = loadStories()
        let exampleStories = selectRandomStories(allStories, count: 3)
        
        print("📚 Загружено рассказов: \(allStories.count)")
        print("🎲 Выбрано примеров для промпта: \(exampleStories.count)")
        if !exampleStories.isEmpty {
            print("📖 Примеры: \(exampleStories.map { $0.title }.joined(separator: ", "))")
        }
        
        // Формируем примеры рассказов для промпта
        var examplesSection = ""
        if !exampleStories.isEmpty {
            examplesSection = "\n\nПримеры твоих рассказов:\n\n"
            for (index, story) in exampleStories.enumerated() {
                examplesSection += formatStoryForPrompt(story)
                if index < exampleStories.count - 1 {
                    examplesSection += "\n\n"
                }
            }
        } else {
            // Fallback на короткие примеры, если не удалось загрузить рассказы
            examplesSection = """
            
            Примеры твоего стиля:
            "У всего есть объяснение, у каждого мелкого события есть простая ясная причина."
            "Весело, когда замечаешь, особенно когда замечаешь неожиданно."
            "Информация рождается во взаимодействии. Цветку наплевать, хранит ли он что-то — он просто растёт."
            """
        }
        
        let systemPrompt = """
        Ты — писатель Дima Козлов. Твои рассказы отличаются:
        - Философской глубиной и абсурдностью
        - Минималистичным стилем
        - Ироничным взглядом на жизнь
        - Короткими, но емкими фразами
        - Размышлениями о смысле, времени, существовании
        - Использованием метафор и образов
        - Специфическим юмором и депрессивными нотками
        \(examplesSection)
        
        Напиши короткий рассказ (100-600 слов) в этом стиле. Рассказ должен быть законченным, с глубоким смыслом, но без явной морали.
        """
        
        let userPrompt = prompt.isEmpty ? "Напиши рассказ на свободную тему в моем стиле." : "Напиши рассказ на тему: \(prompt)"
        
        let generatedText = try await deepSeekRequestContent(
            systemText: systemPrompt,
            userText: userPrompt,
            temperature: 0.8,
            maxTokens: 1500
        )
        
        // Парсим сгенерированный текст
        let lines = generatedText.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let title = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Сгенерированный рассказ"
        let content = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Создаем excerpt (первые 100 символов)
        let excerpt = String(content.prefix(100)) + (content.count > 100 ? "..." : "")
        
        // Генерируем ID и дату
        let id = "ai_\(UUID().uuidString.prefix(8))"
        let date = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        
        return Story(
            id: id,
            title: title,
            date: date,
            excerpt: excerpt,
            content: content,
            tags: ["AI", "сгенерировано"],
            associatedImageId: nil
        )
    }
    
    /// Очистка ответа от лишних символов и форматирования
    private func cleanAIResponse(_ text: String) -> String {
        var cleaned = text
        // Убираем markdown форматирование, если есть
        cleaned = cleaned.replacingOccurrences(of: "**", with: "")
        cleaned = cleaned.replacingOccurrences(of: "*", with: "")
        cleaned = cleaned.replacingOccurrences(of: "#", with: "")
        // Убираем лишние пробелы
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
