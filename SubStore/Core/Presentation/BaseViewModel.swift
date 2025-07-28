import Foundation
import Combine

// MARK: - Base ViewModel Protocol
@MainActor
protocol BaseViewModelProtocol: ObservableObject {
    var isLoading: Bool { get set }
    var errorMessage: String? { get set }
    
    func handleError(_ error: Error)
    func showError(_ message: String)
    func clearError()
}

// MARK: - Base ViewModel Implementation
@MainActor
class BaseViewModel: BaseViewModelProtocol {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    internal var cancellables = Set<AnyCancellable>()
    
    // MARK: - Error Handling
    func handleError(_ error: Error) {
        Logger.shared.error("ViewModel error: \(error.localizedDescription)")
        
        if let appError = error as? AppError {
            errorMessage = appError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func showError(_ message: String) {
        Logger.shared.error("ViewModel error: \(message)")
        errorMessage = message
        isLoading = false
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Loading State Management
    func startLoading() {
        isLoading = true
        clearError()
    }
    
    func stopLoading() {
        isLoading = false
    }
    
    // MARK: - Async Task Wrapper
    func performAsyncTask<T>(_ task: @escaping () async throws -> T) async -> T? {
        startLoading()
        
        do {
            let result = try await task()
            stopLoading()
            return result
        } catch {
            handleError(error)
            return nil
        }
    }
    
    deinit {
        cancellables.removeAll()
    }
}