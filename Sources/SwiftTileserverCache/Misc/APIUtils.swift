//
//  APIUtils.swift
//  SwiftTileserverCache
//
//  Created by Florian Kostenzer on 03.03.20.
//

import Foundation
import LoggerAPI
import Kitura

internal class APIUtils {

    private init() {}

    internal static func downloadFile(from: String, to: String) throws {
        guard let fromURL = URL(string: from) else {
            Log.error("\(from) is not a valid url")
            throw RequestError.internalServerError
        }
        let toURL = URL(fileURLWithPath: to)
        let semaphore = DispatchSemaphore(value: 0)
        var errorToThrow: Error?
        let task = URLSession.shared.dataTask(with: fromURL) { (data, response, error) in
            if (response as? HTTPURLResponse)?.statusCode.description.starts(with: "2") ?? false, let data = data {
                do {
                    try data.write(to: toURL)
                } catch {
                    Log.error("Failed to save data to \(to): \(error)")
                    errorToThrow = RequestError.internalServerError
                }
            } else if let response = response as? HTTPURLResponse {
                if response.statusCode == 404 {
                    Log.info("Failed to load file. Got 404")
                    errorToThrow = RequestError.notFound
                } else {
                    Log.error("Failed to load file. Got \(response.statusCode)")
                    errorToThrow = RequestError.internalServerError
                }
            } else {
                Log.error("Failed to load file. No status code")
                errorToThrow = RequestError.internalServerError
            }
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()
        if let error = errorToThrow {
            throw error
        }
    }

    internal static func loadJSON<T: Decodable>(from: String) throws -> T {
        guard let fromURL = URL(string: from) else {
            Log.error("\(from) is not a valid url")
            throw RequestError.internalServerError
        }
        let semaphore = DispatchSemaphore(value: 0)
        var json: T?
        var errorToThrow: Error?
        let task = URLSession.shared.dataTask(with: fromURL) { (data, response, error) in
            if let data = data {
                do {
                    json = try JSONDecoder().decode(T.self, from: data)
                } catch {
                    Log.error("Failed to parse JSON: \(error)")
                    errorToThrow = RequestError.internalServerError
                }
            } else if let response = response as? HTTPURLResponse {
                if response.statusCode == 404 {
                    Log.info("Failed to load JSON. Got 404")
                    errorToThrow = RequestError.notFound
                } else {
                    Log.error("Failed to load JSON. Got \(response.statusCode)")
                    errorToThrow = RequestError.internalServerError
                }
            } else {
                Log.error("Failed to load JSON. No status code")
                errorToThrow = RequestError.internalServerError
            }
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()
        if let error = errorToThrow {
            throw error
        }
        guard json != nil else {
            throw RequestError.internalServerError
        }
        return json!
    }

}
