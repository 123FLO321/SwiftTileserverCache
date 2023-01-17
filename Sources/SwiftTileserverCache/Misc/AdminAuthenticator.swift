import Vapor

struct AdminAuthenticator: Middleware {

    let username: String
    let password: String

    init() {
        self.username = Environment.get("ADMIN_USERNAME")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.password = Environment.get("ADMIN_PASSWORD")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        guard username != "", password != "" else {
            return request.eventLoop.makeFailedFuture(Abort(.unauthorized, reason: "Dashboard Disabled!"))
        }
        if request.headers.basicAuthorization == nil,
           let sessionUsername = request.session.data["basicAuthorization.username"],
           let sessionPassword = request.session.data["basicAuthorization.password"]  {
            request.headers.basicAuthorization = BasicAuthorization(username: sessionUsername, password: sessionPassword)
        }
        guard let basicAuthorization = request.headers.basicAuthorization else {
            return request.eventLoop.makeFailedFuture(Abort(.unauthorized, headers: HTTPHeaders([("WWW-Authenticate","Basic")]), reason: "Login Required!"))
        }
        request.session.data["basicAuthorization.username"] = basicAuthorization.username
        request.session.data["basicAuthorization.password"] = basicAuthorization.password
        guard username == basicAuthorization.username && password == basicAuthorization.password else {
            return request.eventLoop.makeFailedFuture(Abort(.unauthorized, headers: HTTPHeaders([("WWW-Authenticate","Basic")]), reason: "Invalid Login!"))
        }
        return next.respond(to: request)
    }
}
