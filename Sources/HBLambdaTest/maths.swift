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
import AWSLambdaRuntime
import Hummingbird
import HummingbirdFoundation
import HummingbirdLambda
import NIO

struct DebugMiddleware: HBMiddleware {
    typealias Context = APIGatewayRequestContext

    func apply(
        to request: HBRequest,
        context: Context,
        next: any HBResponder<Context>
    ) async throws -> HBResponse {
        context.logger.debug("\(request.method) \(request.uri)")
        if let apiGatewayRequest = context.apiGatewayRequest {
            context.logger.debug("\(apiGatewayRequest)")
        } else {
            context.logger.debug("No APIGatewayV2Request")
        }

        return try await next.respond(to: request, context: context)
    }
}

@main
struct MathsHandler: HBLambda {
    typealias Context = APIGatewayRequestContext
    typealias Event = APIGatewayRequest
    typealias Output = APIGatewayResponse

    struct Operands: Decodable {
        let lhs: Double
        let rhs: Double
    }

    struct Result: HBResponseEncodable {
        let result: Double
    }

    let router: HBRouterBuilder<Context>
    var responder: some HBResponder<Context> {
        self.router.buildResponder()
    }

    init() async throws {
        let router = HBRouterBuilder(context: Context.self)
        router.middlewares.add(DebugMiddleware())
        router.post("add") { request, context -> Result in
            let operands = try request.decode(as: Operands.self, using: context)
            return Result(result: operands.lhs + operands.rhs)
        }
        router.post("subtract") { request, context -> Result in
            let operands = try request.decode(as: Operands.self, using: context)
            return Result(result: operands.lhs - operands.rhs)
        }
        router.post("multiply") { request, context -> Result in
            let operands = try request.decode(as: Operands.self, using: context)
            return Result(result: operands.lhs * operands.rhs)
        }
        router.post("divide") { request, context -> Result in
            let operands = try request.decode(as: Operands.self, using: context)
            return Result(result: operands.lhs / operands.rhs)
        }
        self.router = router
    }

    func shutdown() async throws {}
}
