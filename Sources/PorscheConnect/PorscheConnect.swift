import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

public typealias CaptchaSolution = (state: String, solution: String)

// MARK: - Enums

public enum PorscheConnectError: Error {
  case AuthFailure
    case WrongCredentials
    #if os(macOS)
    case CaptchaRequired(image: NSImage, state: String)
    #else
    case CaptchaRequired(image: UIImage, state: String)
    #endif
  case NoResult
  case UnlockChallengeFailure
  case lockedFor60Minutes
  case IncorrectPin
}

// MARK: - Porsche-specific OAuth applications

extension OAuthApplication {
  public static let api = OAuthApplication(
    clientId: "XhygisuebbrqQ80byOuU5VncxLIm8E6H",
    redirectURL: URL(string: "my-porsche-app://auth0/callback")!
  )
}

final class SimpleAuthStorage: AuthStoring {
  public var auths: [String: OAuthToken] = [:]

  func storeAuthentication(token: OAuthToken?, for key: String) {
    auths[key] = token
  }

  func authentication(for key: String) -> OAuthToken? {
    return auths[key]
  }
}

// MARK: - Porsche Connect

public class PorscheConnect {

  let environment: Environment
  let username: String
  var authStorage: AuthStoring
    public var captchaSolution: CaptchaSolution?

  let networkClient = NetworkClient()
  let networkRoutes: NetworkRoutes
  let password: String

  // MARK: - Init & configuration

  public init(
    username: String,
    password: String,
    environment: Environment = .germany,
    authStorage: AuthStoring
  ) {
    self.username = username
    self.password = password
    self.environment = environment
    self.networkRoutes = NetworkRoutes(environment: environment)
    self.authStorage = authStorage
  }

  convenience public init(
    username: String,
    password: String,
    environment: Environment = .germany
  ) {
    self.init(
      username: username,
      password: password,
      environment: environment,
      authStorage: SimpleAuthStorage()
    )
  }

  // MARK: - Common functions

  func authorized(application: OAuthApplication) async -> Bool {
    guard let auth = await authStorage.authentication(for: application.clientId) else {
      return false
    }

    return !auth.expired
  }

// MARK: – Internal functions
    
    internal func performAuthFor(application: OAuthApplication) async throws -> [String: String] {
        _ = try await authIfRequired(application: application)
        
        guard let auth = await authStorage.authentication(for: application.clientId), let apiKey = auth.apiKey else {
            throw PorscheConnectError.AuthFailure
        }
        
        let headers = [
            "Authorization": "Bearer \(auth.accessToken)",
        ]
        
        return HEADERS.merging(headers) { $1 }
    }
    
  // MARK: - Private functions

  private func authIfRequired(application: OAuthApplication) async throws {
    if await !authorized(application: application) {
        _ = try await auth(application: application)
    }
  }
}
