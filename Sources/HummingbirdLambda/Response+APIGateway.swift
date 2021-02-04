import AWSLambdaEvents
import AWSLambdaRuntime
import Hummingbird
import NIOHTTP1

protocol APIResponse {
    init(
        statusCode: AWSLambdaEvents.HTTPResponseStatus,
        headers: AWSLambdaEvents.HTTPHeaders?,
        multiValueHeaders: HTTPMultiValueHeaders?,
        body: String?
    )
}

extension HBResponse {
    func apiResponse<Response: APIResponse>() -> Response {
        let groupedHeaders: [String: [String]] = self.headers.reduce([:]) { result, item in
            var result = result
            if result[item.name] == nil {
                result[item.name] = [item.value]
            } else {
                result[item.name]?.append(item.value)
            }
            return result
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
        var body: String? = nil
        if case .byteBuffer(let buffer) = self.body {
            body = String(buffer: buffer)
        }
        return .init(
            statusCode: .init(code: self.status.code),
            headers: singleHeaders,
            multiValueHeaders: multiHeaders,
            body: body
        )
    }
}
