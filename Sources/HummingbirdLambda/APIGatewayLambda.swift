//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import AWSLambdaEvents
import AWSLambdaRuntimeCore
import Hummingbird
import NIO
import NIOHTTP1

extension HBLambda where In == APIGateway.Request {
    /// Specialization of HBLambda.request where `In` is `APIGateway.Request`
    public func request(context: Lambda.Context, application: HBApplication, from: In) throws -> HBRequest {
        var request = try HBRequest(context: context, application: application, from: from)
        // store api gateway request so it is available in routes
        request.extensions.set(\.apiGatewayRequest, value: from)
        return request
    }
}

extension HBLambda where Out == APIGateway.Response {
    /// Specialization of HBLambda.request where `Out` is `APIGateway.Response`
    public func output(from response: HBResponse) -> Out {
        return response.apiResponse()
    }
}

// conform `APIGateway.Request` to `APIRequest` so we can use HBRequest.init(context:application:from)
extension APIGateway.Request: APIRequest {}

// conform `APIGateway.Response` to `APIResponse` so we can use HBResponse.apiReponse()
extension APIGateway.Response: APIResponse {}

extension HBRequest {
    /// `APIGateway.Request` that generated this `HBRequest`
    public var apiGatewayRequest: APIGateway.Request {
        self.extensions.get(\.apiGatewayRequest)
    }
}
