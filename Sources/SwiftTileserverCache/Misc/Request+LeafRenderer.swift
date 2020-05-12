// Temp untill https://github.com/vapor/leaf/pull/163 is merged

import Vapor
import Leaf

extension Request {
    public var leaf: LeafRenderer {
        var userInfo = self.application.leaf.userInfo
        userInfo["request"] = self
        userInfo["application"] = self.application

        return .init(
            configuration: self.application.leaf.configuration,
            tags: self.application.leaf.tags,
            cache: self.application.leaf.cache,
            files: self.application.leaf.files,
            eventLoop: self.eventLoop,
            userInfo: userInfo
        )
    }
}
