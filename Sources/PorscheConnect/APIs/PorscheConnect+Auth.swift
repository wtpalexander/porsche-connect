import Foundation
#if canImport(SVGKit)
import SVGKit
#endif
import SwiftSoup

let AUTHORIZATION_SERVER = "identity.porsche.com"
let REDIRECT_URI = "my-porsche-app://auth0/callback"
let AUDIENCE = "https://api.porsche.com"
let CLIENT_ID = "XhygisuebbrqQ80byOuU5VncxLIm8E6H"
let X_CLIENT_ID = "41843fb4-691d-4970-85c7-2673e8ecef40"
let USER_AGENT = "pyporscheconnectapi/0.2.0"
let API_BASE_URL = "https://api.ppa.porsche.com/app"
let AUTHORIZATION_URL = "https://\(AUTHORIZATION_SERVER)/authorize"
let TOKEN_URL = "https://\(AUTHORIZATION_SERVER)/oauth/token"
let TIMEOUT = 90

let SCOPES = [
    "openid",
    "profile",
    "email",
    "offline_access",
    "mbb",
    "ssodb",
    "badge",
    "vin",
    "dealers",
    "cars",
    "charging",
    "manageCharging",
    "plugAndCharge",
    "climatisation",
    "manageClimatisation",
    "pid:user_profile.porscheid:read",
    "pid:user_profile.name:read",
    "pid:user_profile.vehicles:read",
    "pid:user_profile.dealers:read",
    "pid:user_profile.emails:read",
    "pid:user_profile.phones:read",
    "pid:user_profile.addresses:read",
    "pid:user_profile.birthdate:read",
    "pid:user_profile.locale:read",
    "pid:user_profile.legal:read",
]
let SCOPE = SCOPES.joined(separator: " ")

let HEADERS = ["User-Agent": USER_AGENT, "X-Client-ID": X_CLIENT_ID]

extension PorscheConnect {
    
    public func auth(application: OAuthApplication) async throws -> OAuthToken {
        let authorizationCode = try await fetchAuthorizationCode()
        let accessTokenResponse = try await getAccessToken(code: authorizationCode)
        
        let token = OAuthToken(authResponse: accessTokenResponse.authResponse)
        try await authStorage.storeAuthentication(token: token, for: application.clientId)
        
        return token
    }
    
    // MARK: - Private functions
    
    /// Fetch the authorization code from Porsche Connect.
    ///
    /// Requires 1-4 requests (1 if already logged in, 4 if not):
    
    /// 1. Initial request to /authorize to get the code
    /// 2. If no code is returned, login with Identifier First flow:
    /// 2a. POST to /u/login/identifier with email
    /// 2b. POST to /u/login/password with password
    /// 3. Resume the /authorize request with the resume path from the Identifier First flow
    /// - Returns: authroization code
    private func fetchAuthorizationCode() async throws -> String {
        if let captchaSolution {
            let resumePath = try await loginWithIdentifier(state: captchaSolution.state)
            
            // completed the Identifier First flow, now resume the auth code request
            let parametersOnResume = try await getAndExtractLocationParameters(
                url: networkRoutes.resumeAuth0URL(resumePath: resumePath)
            )
            
            guard let authorizationCode = parametersOnResume.first(where: { $0.name == "code" })?.value else {
                throw PorscheConnectError.AuthFailure
            }
            
            AuthLogger.info("Authorization code: \(authorizationCode)")
            
            return authorizationCode
            
        } else {
            AuthLogger.info("Fetching authorization code")
            
            // 1. Initial request to /authorize to get the code
            let parameters = try await getAndExtractLocationParameters(
                url: networkRoutes.loginAuth0URL,
                parameters: [
                    URLQueryItem(name: "response_type", value: "code"),
                    URLQueryItem(name: "client_id", value: CLIENT_ID),
                    URLQueryItem(name: "redirect_uri", value: REDIRECT_URI),
                    URLQueryItem(name: "audience", value: AUDIENCE),
                    URLQueryItem(name: "scope", value: SCOPE),
                    URLQueryItem(name: "state", value: "pyporscheconnectapi"),
                ]
            )
            
            if let authorizationCode = parameters.first(where: { $0.name == "code" })?.value {
                AuthLogger.info("Got authorization code: \(authorizationCode)")
                return authorizationCode
            }
            
            AuthLogger.info("No existing auth0 session, running through identifier first flow.")
            
            guard let state = parameters.first(where: { $0.name == "state" })?.value else {
                throw PorscheConnectError.AuthFailure
            }
            
            let resumePath = try await loginWithIdentifier(state: state)
            
            // completed the Identifier First flow, now resume the auth code request
            let parametersOnResume = try await getAndExtractLocationParameters(
                url: networkRoutes.resumeAuth0URL(resumePath: resumePath)
            )
            
            guard let authorizationCode = parametersOnResume.first(where: { $0.name == "code" })?.value else {
                throw PorscheConnectError.AuthFailure
            }
            
            AuthLogger.info("Authorization code: \(authorizationCode)")
            
            return authorizationCode
        }
    }
    
    /// GET the URL and extract the params from the Location header.
    /// - Parameters:
    ///   - url: URL to get
    ///   - parameters: dictionary of query parameters
    /// - Returns: dict of query parameters from the Location header
    private func getAndExtractLocationParameters(url: URL, parameters: [URLQueryItem] = []) async throws -> [URLQueryItem] {
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.addQueryItems(parameters)
        guard let url = urlComponents?.url else {
            throw PorscheConnectError.AuthFailure
        }
        let result = try await networkClient.get(
            String.self,
            url: url,
            parseResponseBody: false,
            shouldFollowRedirects: false
        )
        guard let locationHeaderValue = result.response.value(forHTTPHeaderField: "Location") else {
            throw PorscheConnectError.AuthFailure
        }
        
        guard
            let urlComponents = URLComponents(string: locationHeaderValue),
            let queryParameters = urlComponents.queryItems
        else {
            throw PorscheConnectError.AuthFailure
        }
        return queryParameters
    }
    
    /// Log into the Identifier First flow.
    ///
    /// Takes 2 steps:
    ///
    /// 1. POST to /u/login/identifier with email
    /// 2. POST to /u/login/password with password
    /// - Parameter state: state parameter from the initial authorize request
    /// - Returns: path to resume the auth code request
    private func loginWithIdentifier(state: String) async throws -> String {
        // 1. /u/login/identifier w/ email (and captcha code)
        var identifierData = buildLoginIdentifierBody(state: state, username: username)
        
        if let captchaSolution {
            identifierData["captcha"] = captchaSolution.solution
            AuthLogger.info("Submitting e-mail address and captcha code \(captchaSolution.solution) to auth endpoint.")
        } else {
            AuthLogger.info("Submitting e-mail address to auth endpoint.")
        }
        
        let identifierResult = try await networkClient.post(
            String.self,
            url: networkRoutes.usernameLoginAuth0URL(state: state),
            body: buildPostFormBodyFrom(dictionary: identifierData),
            headers: HEADERS,
            contentType: .form,
            failOnErrorStatusCode: false
        )
        
        switch identifierResult.response.statusCode {
        case HttpStatusCode.BadRequest.rawValue:
            AuthLogger.info("Captcha required.")
            guard let data = identifierResult.data else {
                throw PorscheConnectError.AuthFailure
            }
            let document = try SwiftSoup.parseBodyFragment(data)
            let images = try document.getElementsByAttributeValue("alt", "captcha")
            guard
                let image = images.first(),
                let encodedCaptchaData = try image.attr("src").split(separator: ",")[1].data(using: .utf8)
            else {
                throw PorscheConnectError.AuthFailure
            }
            let captchaData = Data(base64Encoded: encodedCaptchaData)
            
#if canImport(SVGKit)
            guard let captchaImage = SVGKImage(data: captchaData)?.uiImage else {
                throw PorscheConnectError.AuthFailure
            }
            throw PorscheConnectError.CaptchaRequired(image: captchaImage, state: state)
#else
            // TODO: Support captcha images macOS
            throw PorscheConnectError.AuthFailure
#endif
            
        case HttpStatusCode.Unauthorized.rawValue:
            throw PorscheConnectError.WrongCredentials
            
        default:
            break
        }
        
        // 2. /u/login/password w/ password
        AuthLogger.info("Submitting password to auth endpoint.")
        
        let passwordData = buildLoginPasswordBody(state: state, username: username, password: password)
        
        let passwordResult = try await networkClient.post(
            String.self,
            url: networkRoutes.passwordLoginAuth0URL(state: state),
            body: buildPostFormBodyFrom(dictionary: passwordData),
            headers: HEADERS,
            contentType: .form,
            shouldFollowRedirects: false
        )
        
        if let statusCode = HttpStatusCode(rawValue: passwordResult.response.statusCode), statusCode == .OK {
            AuthLogger.info("Authentication password details sent successfully.")
        }
        
        switch passwordResult.response.statusCode {
        case HttpStatusCode.Unauthorized.rawValue:
            throw PorscheConnectError.WrongCredentials
            
        default:
            break
        }
        
        guard let resumeAtLocation = passwordResult.response.value(forHTTPHeaderField: "Location") else {
            throw PorscheConnectError.AuthFailure
        }
        AuthLogger.info("Resume at \(resumeAtLocation)")
        
        AuthLogger.info("About to sleep for \(kSleepDurationInSecs) seconds to give Porsche Auth0 service chance to process previous request.")
        try await Task.sleep(nanoseconds: UInt64(kSleepDurationInSecs * Double(NSEC_PER_SEC)))
        AuthLogger.info("Finished sleeping.")
        
        return resumeAtLocation
    }
    
    private func getAccessToken(code: String) async throws -> (authResponse: AuthResponse, response:  HTTPURLResponse?) {
        let result = try await networkClient.post(
            AuthResponse.self,
            url: networkRoutes.accessTokenAuth0URL,
            body: buildPostFormBodyFrom(dictionary: buildAccessTokenBody(code: code)),
            contentType: .form
        )
        
        if let statusCode = HttpStatusCode(rawValue: result.response.statusCode), statusCode == .OK {
            AuthLogger.info("Retrieving access token successful.")
        }
        
        guard let authResponse = result.data else {
            AuthLogger.error("Could not map response to AuthResponse.")
            throw PorscheConnectError.AuthFailure
        }
        
        return (authResponse, result.response)
    }
    
    private func buildLoginIdentifierBody(state: String, username: String) -> [String : String] {
        [
            "state": state,
            "username": username,
            "js-available": "True",
            "webauthn-available": "False",
            "is-brave": "False",
            "webauthn-platform-available": "False",
            "action": "default"
        ]
    }
    
    private func buildLoginPasswordBody(state: String, username: String, password: String) -> [String : String] {
        [
            "state": state,
            "username": username,
            "password": password,
            "action": "default"
        ]
    }
    
    private func buildAccessTokenBody(code: String) -> [String : String] {
        return [
            "client_id": OAuthApplication.api.clientId,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": OAuthApplication.api.redirectURL.description
        ]
    }
}

// MARK: - Response types

/// A response from one of the Porsche Connect authorization endpoints.
///
/// This type is not meant to be stored to disk as it includes a relative time value that is only meaningful when
/// first decoded from the server. If you need to store an AuthResponse longer-term, use OAuthToken instead.
struct AuthResponse: Decodable {
    let accessToken: String
    let idToken: String
    let tokenType: String
    let scope: String
    let expiresIn: Double
}

extension URLComponents {
    mutating func addQueryItems(_ queryItems: [URLQueryItem]) {
        if self.queryItems == nil {
            self.queryItems = []
        }
        self.queryItems?.append(contentsOf: queryItems)
    }
}
