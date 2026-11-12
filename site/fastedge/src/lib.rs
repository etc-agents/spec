//! etc-agents.org on Gcore FastEdge.
//!
//! The site is static. All files are compiled into the Wasm binary, so a
//! deploy is: build, upload, update the app.
use fastedge::{
    body::Body,
    http::{header, Error, Method, Request, Response, StatusCode},
};

const INDEX: &str = include_str!("../../index.html");
const SPEC: &str = include_str!("../../../SPEC.md");
const LOADER: &str = include_str!("../../../agents-cat");
const ROBOTS: &str = "User-agent: *\nAllow: /\n";

const HTML: &str = "text/html; charset=utf-8";
const TEXT: &str = "text/plain; charset=utf-8";
const MARKDOWN: &str = "text/markdown; charset=utf-8";

fn page(content_type: &str, body: &'static str, head: bool) -> Result<Response<Body>, Error> {
    Response::builder()
        .status(StatusCode::OK)
        .header(header::CONTENT_TYPE, content_type)
        .header(header::CACHE_CONTROL, "public, max-age=300")
        .header("x-content-type-options", "nosniff")
        .header("referrer-policy", "strict-origin-when-cross-origin")
        .body(if head { Body::empty() } else { Body::from(body) })
}

fn plain(status: StatusCode, body: &'static str) -> Result<Response<Body>, Error> {
    Response::builder()
        .status(status)
        .header(header::CONTENT_TYPE, TEXT)
        .body(Body::from(body))
}

#[fastedge::http]
fn main(req: Request<Body>) -> Result<Response<Body>, Error> {
    let head = req.method() == Method::HEAD;
    if req.method() != Method::GET && !head {
        return Response::builder()
            .status(StatusCode::METHOD_NOT_ALLOWED)
            .header(header::ALLOW, "GET, HEAD")
            .header(header::CONTENT_TYPE, TEXT)
            .body(Body::from("method not allowed\n"));
    }

    // www.etc-agents.org -> etc-agents.org
    let host = req
        .headers()
        .get(header::HOST)
        .and_then(|v| v.to_str().ok())
        .unwrap_or("");
    if let Some(apex) = host.strip_prefix("www.") {
        let path = req.uri().path_and_query().map(|p| p.as_str()).unwrap_or("/");
        return Response::builder()
            .status(StatusCode::MOVED_PERMANENTLY)
            .header(header::LOCATION, format!("https://{apex}{path}"))
            .body(Body::empty());
    }

    match req.uri().path() {
        "/" | "/index.html" => page(HTML, INDEX, head),
        "/spec" | "/spec.md" | "/SPEC.md" => page(MARKDOWN, SPEC, head),
        "/agents-cat" => page(TEXT, LOADER, head),
        "/robots.txt" => page(TEXT, ROBOTS, head),
        _ => plain(StatusCode::NOT_FOUND, "not found\n"),
    }
}
