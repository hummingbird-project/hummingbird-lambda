//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
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
import HummingbirdLambda
import Logging

typealias AppRequestContext = BasicLambdaRequestContext<APIGatewayRequest>

struct DebugMiddleware: RouterMiddleware {
    typealias Context = AppRequestContext
    func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Output
    ) async throws -> Output {
        context.logger.debug("\(request.method) \(request.uri)")
        context.logger.debug("\(context.event)")

        return try await next(request, context)
    }
}

struct Operands: Decodable {
    let lhs: Double
    let rhs: Double
}

struct Result: ResponseEncodable {
    let result: Double
}

@main
struct MathsLambda {
    static func main() async throws {
        let router = Router(context: AppRequestContext.self)
        router.middlewares.add(DebugMiddleware())
        router.post("add") { request, context -> Result in
            let operands = try await request.decode(as: Operands.self, context: context)
            return Result(result: operands.lhs + operands.rhs)
        }
        router.post("subtract") { request, context -> Result in
            let operands = try await request.decode(as: Operands.self, context: context)
            return Result(result: operands.lhs - operands.rhs)
        }
        router.post("multiply") { request, context -> Result in
            let operands = try await request.decode(as: Operands.self, context: context)
            return Result(result: operands.lhs * operands.rhs)
        }
        router.post("divide") { request, context -> Result in
            let operands = try await request.decode(as: Operands.self, context: context)
            return Result(result: operands.lhs / operands.rhs)
        }
        let lambda = APIGatewayLambdaFunction(
            router: router,
            logger: Logger(label: "lambda")
        )
        try await lambda.runService()
    }
}
/*
@main
struct MathsHandler: APIGatewayLambdaFunction {
    typealias Context = BasicLambdaRequestContext<APIGatewayRequest>

    init(context: LambdaInitializationContext) {}

    func buildResponder() -> some HTTPResponder<Context> {
        let router = Router(context: Context.self)
        router.middlewares.add(DebugMiddleware())
        router.post("add") { request, context -> Result in
            let operands = try await request.decode(as: Operands.self, context: context)
            return Result(result: operands.lhs + operands.rhs)
        }
        router.post("subtract") { request, context -> Result in
            let operands = try await request.decode(as: Operands.self, context: context)
            return Result(result: operands.lhs - operands.rhs)
        }
        router.post("multiply") { request, context -> Result in
            let operands = try await request.decode(as: Operands.self, context: context)
            return Result(result: operands.lhs * operands.rhs)
        }
        router.post("divide") { request, context -> Result in
            let operands = try await request.decode(as: Operands.self, context: context)
            return Result(result: operands.lhs / operands.rhs)
        }
        return router.buildResponder()
    }

    func shutdown() async throws {}
}
*/
