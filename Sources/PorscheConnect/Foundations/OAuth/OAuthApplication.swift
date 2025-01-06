import Foundation
import JWTDecode

/// The Porsche Connect service is composed of various independent OAuth applications, each providing
/// access to specific services and endpoints once authenticated.
///
/// Once authenticated, an instance of this type will typically be associated with an OAuthToken instance that
/// represents the user's authentication.
public struct OAuthApplication: Hashable {
  let clientId: String
  let redirectURL: URL
}

/// An OAuthToken is created as a result of a successful user authentication for a specific OAuthApplication.
public struct OAuthToken: Codable {

  // MARK: Properties

  public let accessToken: String
  public let idToken: String
  public let tokenType: String
  public let expiresAt: Date
  public let scope: String

  public var apiKey: String? {
      guard let jwt = try? decode(jwt: idToken) else { return nil }
      return jwt["aud"].string
  }

  public var expired: Bool {
    return Date() > expiresAt
  }

  // MARK: Lifecycle

  init(authResponse: AuthResponse) {
    self.accessToken = authResponse.accessToken
    self.idToken = authResponse.idToken
    self.tokenType = authResponse.tokenType
    self.scope = authResponse.scope
    self.expiresAt = Date().addingTimeInterval(authResponse.expiresIn)
  }
}
