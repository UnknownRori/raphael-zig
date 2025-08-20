pub const HTTPMethod = enum {
    GET,
    POST,
    DELETE,
    PATCH,

    pub fn toString(self: HTTPMethod) []const u8 {
        return switch (self) {
            HTTPMethod.GET => "GET",
            HTTPMethod.POST => "POST",
            HTTPMethod.DELETE => "DELETE",
            HTTPMethod.PATCH => "PATCH",
        };
    }
};

pub const HTTPStatus = enum(u16) {
    // 200
    Ok = 200,
    Created = 201,
    Accepted = 202,
    NoContent = 204,
    PartialContent = 206,
    // 300
    NotModified = 304,
    // 400
    BadRequest = 400,
    UnAuthorized = 401,
    Forbidden = 403,
    NotFound = 404,
    // 500
    InternalServerError = 500,
    ServiceUnAvailable = 503,

    pub fn toString(self: HTTPStatus) []const u8 {
        return switch (self) {
            HTTPStatus.Ok => "Ok",
            HTTPStatus.Created => "Created",
            HTTPStatus.Accepted => "Accepted",
            HTTPStatus.NoContent => "No Content",
            HTTPStatus.PartialContent => "Partial Content",

            HTTPStatus.NotModified => "Not Modified",

            HTTPStatus.BadRequest => "Bad Request",
            HTTPStatus.UnAuthorized => "Unauthorized",
            HTTPStatus.Forbidden => "Forbidden",
            HTTPStatus.NotFound => "Not Found",

            HTTPStatus.InternalServerError => "Internal Server Error",
            HTTPStatus.ServiceUnAvailable => "Service Unavailable",
        };
    }
};
