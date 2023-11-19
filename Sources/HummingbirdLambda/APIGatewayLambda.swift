//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2023 the Hummingbird authors
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
import NIOCore
import NIOHTTP1

extension HBLambda where Event == APIGatewayRequest {
    /// Specialization of HBLambda.request where `In` is `APIGateway.Request`
    public func request(context: LambdaContext, from: Event) throws -> HBRequest {
        return try HBRequest(context: context, from: from)
    }
}

extension HBLambda where Output == APIGatewayResponse {
    /// Specialization of HBLambda.request where `Out` is `APIGateway.Response`
    public func output(from response: HBResponse) async throws -> Output {
        return try await response.apiResponse()
    }
}

// conform `APIGatewayRequest` to `APIRequest` so we can use HBRequest.init(context:application:from)
extension APIGatewayRequest: APIRequest {}

// conform `APIGatewayResponse` to `APIResponse` so we can use HBResponse.apiReponse()
extension APIGatewayResponse: APIResponse {}