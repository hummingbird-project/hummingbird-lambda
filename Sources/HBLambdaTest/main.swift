import AWSLambdaEvents
import AWSLambdaRuntime
import HummingbirdLambda
import HummingbirdFoundation
import NIO


Lambda.run { context in
    return HBLambdaHandler<MathsHandler>(context: context)
}

struct MathsHandler: HBLambda {
    typealias In = APIGateway.Request
    typealias Out = APIGateway.Response
    
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
        app.router.post("request") { request -> String in
            var result = ""
            result = "URI: \(request.uri)\n"
            result += "Headers: \(request.headers)"
            request.response.setCookie(.init(name: "Token1", value: "Value1"))
            request.response.setCookie(.init(name: "Token2", value: "Value2"))
            return result
        }
    }
}
