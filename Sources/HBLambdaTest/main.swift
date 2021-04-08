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
import HummingbirdFoundation
import HummingbirdLambda
import NIO

struct DebugMiddleware: HBMiddleware {
    func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        request.logger.debug("\(request.method) \(request.uri)")
        request.logger.debug("\(request.apiGatewayV2Request)")
        return next.respond(to: request)
    }
}

Lambda.run { context in
    return HBLambdaHandler<MathsHandler>(context: context)
}

struct MathsHandler: HBLambda {
    typealias In = APIGateway.V2.Request
    typealias Out = APIGateway.V2.Response

    struct Operands: Decodable {
        let lhs: Double
        let rhs: Double
    }

    struct Result: HBResponseEncodable {
        let result: Double
    }

    init(_ app: HBApplication) {
        app.encoder = JSONEncoder()
        app.decoder = JSONDecoder()
        app.middleware.add(DebugMiddleware())
        app.router.post("add") { request -> Result in
            let operands = try request.decode(as: Operands.self)
            return Result(result: operands.lhs + operands.rhs)
        }
        app.router.post("subtract") { request -> Result in
            let operands = try request.decode(as: Operands.self)
            return Result(result: operands.lhs - operands.rhs)
        }
        app.router.post("multiply") { request -> Result in
            let operands = try request.decode(as: Operands.self)
            return Result(result: operands.lhs * operands.rhs)
        }
        app.router.post("divide") { request -> Result in
            let operands = try request.decode(as: Operands.self)
            return Result(result: operands.lhs / operands.rhs)
        }
    }
}
