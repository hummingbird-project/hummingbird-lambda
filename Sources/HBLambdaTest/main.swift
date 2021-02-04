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
        app.router.post("multiple") { request -> Result in
            let operands = try request.decode(as: Operands.self)
            return Result(result: operands.lhs * operands.rhs)
        }
        app.router.post("divide") { request -> Result in
            let operands = try request.decode(as: Operands.self)
            return Result(result: operands.lhs / operands.rhs)
        }
    }
}
