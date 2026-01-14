//
//  SettingsView.swift
//  dima-kozlov-ios
//
//  Настройки приложения, включая ввод API ключа
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    @State private var apiKeyInput: String = ""
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                PaperBackground()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Заголовок
                        VStack(alignment: .leading, spacing: 8) {
                            Text("НАСТРОЙКИ")
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.ink)
                            
                            Rectangle()
                                .fill(Color.ink.opacity(0.12))
                                .frame(height: 1.5)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Секция AI
                        VStack(alignment: .leading, spacing: 16) {
                            Text("ГЕНЕРАЦИЯ РАССКАЗОВ")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.ink.opacity(0.7))
                                .padding(.horizontal, 20)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("DeepSeek API ключ")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.ink)
                                
                                SecureField("Введите ваш API ключ", text: $apiKeyInput)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                    .font(.system(size: 15, design: .monospaced))
                                    .padding(12)
                                    .background(Color.paper)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(Color.ink.opacity(0.2), lineWidth: 1)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Для генерации рассказов необходим API ключ от DeepSeek.")
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundStyle(Color.ink.opacity(0.6))
                                    
                                    Text("Получить ключ можно на сайте deepseek.com")
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundStyle(Color.ink.opacity(0.6))
                                    
                                    Text("⚠️ При ошибке 401 проверьте правильность ключа")
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundStyle(Color.absurdRed.opacity(0.8))
                                        .padding(.top, 4)
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
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    aiService.saveAPIKey(apiKeyInput)
                                    alertMessage = "API ключ сохранен"
                                    showAlert = true
                                }) {
                                    Text("Сохранить")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.paper)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 24)
                                        .background(Color.ink)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                
                                if !aiService.aiToken.isEmpty {
                                    Button(action: {
                                        aiService.saveAPIKey("")
                                        apiKeyInput = ""
                                        alertMessage = "API ключ удален"
                                        showAlert = true
                                    }) {
                                        Text("Удалить")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color.ink)
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 24)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .stroke(Color.ink, lineWidth: 1.5)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            if !aiService.aiToken.isEmpty {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.absurdRed)
                                    Text("API ключ установлен")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.ink.opacity(0.7))
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 8)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink)
                }
            }
            .onAppear {
                apiKeyInput = aiService.aiToken
            }
            .alert("Уведомление", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
}
