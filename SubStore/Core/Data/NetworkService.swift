import Foundation
import Combine
import Alamofire

// MARK: - Network Error
enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(AFError)
    case serverError(Int, String)
    case unauthorized
    case timeout
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .noData:
            return "未收到数据"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        case .networkError(let afError):
            return "网络错误: \(afError.localizedDescription)"
        case .serverError(let code, let message):
            return "服务器错误 (\(code)): \(message)"
        case .unauthorized:
            return "未授权访问"
        case .timeout:
            return "请求超时"
        case .unknown(let error):
            return "未知错误: \(error.localizedDescription)"
        }
    }
}

// MARK: - API Request
struct APIRequest {
    let method: HTTPMethod
    let path: String
    let parameters: [String: Any]?
    let headers: HTTPHeaders?
    let encoding: ParameterEncoding
    
    init(
        method: HTTPMethod,
        path: String,
        parameters: [String: Any]? = nil,
        headers: HTTPHeaders? = nil,
        encoding: ParameterEncoding = URLEncoding.default
    ) {
        self.method = method
        self.path = path
        self.parameters = parameters
        self.headers = headers
        self.encoding = encoding
    }
}

// MARK: - API Response
struct APIResponse<T: Codable> {
    let data: T?
    let message: String?
    let code: Int
    let success: Bool
    
    init(data: T? = nil, message: String? = nil, code: Int = 200, success: Bool = true) {
        self.data = data
        self.message = message
        self.code = code
        self.success = success
    }
}

// MARK: - Network Service Protocol
protocol NetworkServiceProtocol {
    func request<T: Codable>(_ request: APIRequest, responseType: T.Type) -> AnyPublisher<T, NetworkError>
    func download(from url: String) -> AnyPublisher<Data, NetworkError>
    func upload(data: Data, to url: String) -> AnyPublisher<Bool, NetworkError>
}

// MARK: - Network Service Implementation
class NetworkService: NetworkServiceProtocol {
    static let shared = NetworkService()
    
    private let session: Session
    private let baseURL: String
    private let timeout: TimeInterval
    
    init(
        baseURL: String = AppConstants.API.defaultBaseURL,
        timeout: TimeInterval = AppConstants.API.defaultTimeout
    ) {
        self.baseURL = baseURL
        self.timeout = timeout
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout * 2
        
        // 配置网络监控
        let monitor = ClosureEventMonitor()
        monitor.requestDidCreateTask = { request, task in
            Logger.shared.debug("Network request created: \(request.url?.absoluteString ?? "unknown")")
        }
        monitor.requestDidComplete = { request, response, _, error in
            if let error = error {
                Logger.shared.error("Network request failed: \(error.localizedDescription)")
            } else {
                Logger.shared.debug("Network request completed: \(response?.statusCode ?? 0)")
            }
        }
        
        self.session = Session(configuration: configuration, eventMonitors: [monitor])
    }
    
    // MARK: - Request Method
    func request<T: Codable>(_ request: APIRequest, responseType: T.Type) -> AnyPublisher<T, NetworkError> {
        guard let url = URL(string: baseURL + request.path) else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var finalHeaders = HTTPHeaders()
        finalHeaders["Content-Type"] = "application/json"
        finalHeaders["Accept"] = "application/json"
        
        // 添加自定义头部
        if let headers = request.headers {
            for header in headers {
                finalHeaders[header.name] = header.value
            }
        }
        
        // 添加用户认证信息（如果需要）
        if let token = getAuthToken() {
            finalHeaders["Authorization"] = "Bearer \(token)"
        }
        
        return session.request(
            url,
            method: request.method,
            parameters: request.parameters,
            encoding: request.encoding,
            headers: finalHeaders
        )
        .validate()
        .publishData(queue: .global(qos: .background))
        .tryMap { response in
            guard let data = response.data else {
                throw NetworkError.noData
            }
            
            // 处理服务器错误响应
            if let httpResponse = response.response {
                if httpResponse.statusCode >= 400 {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
                    throw NetworkError.serverError(httpResponse.statusCode, errorMessage)
                }
            }
            
            return data
        }
        .decode(type: T.self, decoder: JSONDecoder())
        .mapError { error in
            if let networkError = error as? NetworkError {
                return networkError
            } else if let afError = error as? AFError {
                return NetworkError.networkError(afError)
            } else if error is DecodingError {
                return NetworkError.decodingError(error)
            } else {
                return NetworkError.unknown(error)
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    // MARK: - Download Method
    func download(from url: String) -> AnyPublisher<Data, NetworkError> {
        guard let downloadURL = URL(string: url) else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        return session.request(downloadURL, method: .get)
            .validate()
            .publishData(queue: .global(qos: .background))
            .tryMap { response in
                guard let data = response.data else {
                    throw NetworkError.noData
                }
                return data
            }
            .mapError { error in
                if let afError = error as? AFError {
                    return NetworkError.networkError(afError)
                } else {
                    return NetworkError.unknown(error)
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Upload Method
    func upload(data: Data, to url: String) -> AnyPublisher<Bool, NetworkError> {
        guard let uploadURL = URL(string: url) else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        return session.upload(data, to: uploadURL, method: .post)
            .validate()
            .publishData(queue: .global(qos: .background))
            .tryMap { response in
                return response.response?.statusCode == 200
            }
            .mapError { error in
                if let afError = error as? AFError {
                    return NetworkError.networkError(afError)
                } else {
                    return NetworkError.unknown(error)
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    private func getAuthToken() -> String? {
        // 从 Keychain 或 UserDefaults 获取认证令牌
        return StorageManager.shared.get(String.self, forKey: "AuthToken")
    }
}

// MARK: - API Endpoints
enum APIEndpoints {
    // Subscription endpoints
    case getSubs
    case getCollections
    case createSub
    case updateSub(String)
    case deleteSub(String)
    case getSubFlow(String)
    
    // Artifact endpoints
    case getArtifacts
    case createArtifact
    case updateArtifact(String)
    case deleteArtifact(String)
    case syncArtifact(String)
    case syncAllArtifacts
    
    // File endpoints
    case getFiles
    case createFile
    case updateFile(String)
    case deleteFile(String)
    case getFileContent(String)
    
    // Share endpoints
    case getShares
    case createShare
    case deleteShare(String)
    case getSharedContent(String)
    
    // Settings endpoints
    case getSettings
    case updateSettings
    case syncSettings
    case downloadSettings
    
    var path: String {
        switch self {
        // Subscription paths
        case .getSubs:
            return "/api/subs"
        case .getCollections:
            return "/api/collections"
        case .createSub:
            return "/api/subs"
        case .updateSub(let id):
            return "/api/subs/\(id)"
        case .deleteSub(let id):
            return "/api/subs/\(id)"
        case .getSubFlow(let id):
            return "/api/subs/\(id)/flow"
            
        // Artifact paths
        case .getArtifacts:
            return "/api/artifacts"
        case .createArtifact:
            return "/api/artifacts"
        case .updateArtifact(let id):
            return "/api/artifacts/\(id)"
        case .deleteArtifact(let id):
            return "/api/artifacts/\(id)"
        case .syncArtifact(let id):
            return "/api/artifacts/\(id)/sync"
        case .syncAllArtifacts:
            return "/api/artifacts/sync"
            
        // File paths
        case .getFiles:
            return "/api/files"
        case .createFile:
            return "/api/files"
        case .updateFile(let id):
            return "/api/files/\(id)"
        case .deleteFile(let id):
            return "/api/files/\(id)"
        case .getFileContent(let id):
            return "/api/files/\(id)/content"
            
        // Share paths
        case .getShares:
            return "/api/share"
        case .createShare:
            return "/api/share"
        case .deleteShare(let id):
            return "/api/share/\(id)"
        case .getSharedContent(let token):
            return "/api/share/\(token)"
            
        // Settings paths
        case .getSettings:
            return "/api/settings"
        case .updateSettings:
            return "/api/settings"
        case .syncSettings:
            return "/api/settings/sync"
        case .downloadSettings:
            return "/api/settings/download"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getSubs, .getCollections, .getSubFlow, .getArtifacts, .getFiles, .getFileContent, .getShares, .getSharedContent, .getSettings, .downloadSettings:
            return .get
        case .createSub, .createArtifact, .createFile, .createShare, .syncArtifact, .syncAllArtifacts, .syncSettings:
            return .post
        case .updateSub, .updateArtifact, .updateFile, .updateSettings:
            return .put
        case .deleteSub, .deleteArtifact, .deleteFile, .deleteShare:
            return .delete
        }
    }
}