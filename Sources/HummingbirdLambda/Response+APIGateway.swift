//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2023-2024 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AWSLambdaEvents
import AWSLambdaRuntime
import ExtrasBase64
import Hummingbird
import NIOHTTP1

package protocol APIResponse {
    init(
        statusCode: HTTPResponse.Status,
        headers: AWSLambdaEvents.HTTPHeaders?,
        multiValueHeaders: HTTPMultiValueHeaders?,
        body: String?,
        isBase64Encoded: Bool?
    )
}

extension Response {
    package func apiResponse<Response: APIResponse>() async throws -> Response {
        var body: String?
        var isBase64Encoded: Bool?
        let collateWriter = CollateResponseBodyWriter()
        _ = try await self.body.write(collateWriter)

        var headers = self.headers
        if let trailingHeaders = collateWriter.trailingHeaders {
            headers.append(contentsOf: trailingHeaders)
        }
        let groupedHeaders: [String: [String]] = self.headers.reduce(into: [:]) { result, item in
            if result[item.name.rawName] == nil {
                result[item.name.rawName] = [item.value]
            } else {
                result[item.name.rawName]?.append(item.value)
            }
        }
        let singleHeaders = groupedHeaders.compactMapValues { item -> String? in
            if item.count == 1 {
                return item.first!
            } else {
                return nil
            }
        }
        let multiHeaders = groupedHeaders.compactMapValues { item -> [String]? in
            if item.count > 1 {
                return item
            } else {
                return nil
            }
        }

        let buffer = collateWriter.buffer
        if let contentType = self.headers[.contentType] {
            let mediaType = MediaType(from: contentType)
            switch mediaType {
            case .some(.text), .some(.applicationJson), .some(.applicationUrlEncoded):
                body = String(buffer: buffer)
            default:
                break
            }
        }

        if body == nil {
            body = String(base64Encoding: buffer.readableBytesView)
            isBase64Encoded = true
        }

        return .init(
            statusCode: self.status,
            headers: singleHeaders,
            multiValueHeaders: multiHeaders,
            body: body,
            isBase64Encoded: isBase64Encoded
        )
    }
}
