//
//  Request.swift
//  SuperHeroDirectory
//
//  Created by Matthew Korporaal on 8/8/20.
//  Copyright © 2020 Matthew Korporaal. All rights reserved.
//

import Foundation

public typealias Parameters = [String: Any]
public typealias HTTPHeaders = [String: String]
public typealias ResultVoidClosure<T> = (Result<T, Error>) -> Void

// Encoding

public enum Encoding {
    case json
    case url
}

// HTTPMethod

public enum HTTPMethod {
    case get
    case post(Encoding)

    var value: String {
        switch self {
        case .get:
            return "GET"
        case .post:
            return "POST"
        }
    }
}

// RequestType - declaration

protocol RequestType {

    var url: URL { get }
    var method: HTTPMethod { get }
    var parameters: Parameters? { get }
    var headers: HTTPHeaders? { get }

    func responseObject<T: Decodable>(_ completion: @escaping ResultVoidClosure<T>)
}

// Request - Public properties
// RequestType - implementation

public struct Request: RequestType {
    let url: URL
    let method: HTTPMethod
    let parameters: Parameters?
    let headers: HTTPHeaders?
}

// Request - public method

public extension Request {

    func responseObject<T: Decodable>(_ completion: @escaping ResultVoidClosure<T>) {
        response { result in
            switch result {
            case .success(let data):
                do {
                    let model = try JSONDecoder().decode(T.self, from: data)
                    completion(.success(model))
                } catch (let error) {
                    completion(.failure(HTTPError.decodingError(underlying: error)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

// Request - private

extension Request {

    private func response(_ completion: @escaping (Result<Data, Error>) -> Void) {
        URLSession.shared.dataTask(with: self.asURLRequest()) { (data, response, error) in
            if let error = error {
                completion(.failure(self.converted(error)))
            } else {
                let httpResponse = response as! HTTPURLResponse
                if (200 ... 299) ~= httpResponse.statusCode {
                    if let data = data {
                        completion(.success(data))
                    } else {
                        completion(.failure(HTTPError.noData))
                    }
                } else {
                    completion(.failure(HTTPError.serverError(response: response)))
                }
            }
        }.resume()
    }

    private func asURLRequest() -> URLRequest {
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = headers
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        if case let .post(encoding) = method {
            switch encoding {
            case .json:
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            case .url:
                request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            }
        }
        if let params = parameters {
            switch method {
            case .post(let encoding):
                switch encoding {
                case .json:
                    request.httpBody = try? JSONSerialization.data(withJSONObject: params)
                case .url:
                    request.httpBody = params.map { (tuple) -> String in
                        return "\(tuple.key)=\(self.percentEscapeString(string: "\(tuple.value)"))"
                        }.joined(separator: "&").data(using: .utf8, allowLossyConversion: true)
                }
            case .get:
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
                components.queryItems = params.map {
                    URLQueryItem(name: $0.key, value: "\($0.value)")
                }
                components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
                let urlWithQueries = components.url!
                request.url = urlWithQueries
            }
        }
        request.httpMethod = method.value

        return request
    }

    private func converted(_ error: Error) -> Error {
        if let error = error as? URLError {
            switch error.code {
            case .timedOut,
                 .cannotFindHost,
                 .networkConnectionLost,
                 .dnsLookupFailed,
                 .notConnectedToInternet,
                 .cannotConnectToHost:
                return HTTPError.unreachable
            default:
                break
            }
        }

        return HTTPError.clientError(underlying: error)
    }

    private func percentEscapeString(string: String) -> String {
        var characterSet = CharacterSet.alphanumerics
        characterSet.insert(charactersIn: "-._* ")
        return string
            .addingPercentEncoding(withAllowedCharacters: characterSet)!
            .replacingOccurrences(of: " ", with: "+", options: [], range: nil)
    }
}
