//
//  ClaudeAPIServiceTests.swift
//  XtremeMappingTests
//
//  Pure-logic tests for the Claude API service: Anthropic error-body
//  parsing and request construction (timeout, model, headers).
//

import XCTest
@testable import XtremeMapping

final class ClaudeAPIServiceTests: XCTestCase {

    // MARK: - Error-body parsing

    func testAPIErrorParsesAnthropicErrorBodyMessage() {
        let body = """
        {"type":"error","error":{"type":"rate_limit_error","message":"Your account has hit a rate limit."}}
        """.data(using: .utf8)!

        let error = ClaudeAPIService.apiError(statusCode: 429, data: body)
        let description = error.localizedDescription

        XCTAssertTrue(description.contains("Your account has hit a rate limit."),
                      "Error must surface the API's own message, got: \(description)")
        XCTAssertTrue(description.contains("429"),
                      "Error must carry the HTTP status, got: \(description)")
    }

    func test429ErrorUsesRateLimitWording() {
        let body = """
        {"type":"error","error":{"type":"rate_limit_error","message":"Slow down."}}
        """.data(using: .utf8)!

        let description = ClaudeAPIService.apiError(statusCode: 429, data: body).localizedDescription

        XCTAssertTrue(description.localizedCaseInsensitiveContains("rate limit"),
                      "429 must be described as a rate limit, got: \(description)")
    }

    func testNon429ErrorCarriesStatusAndMessage() {
        let body = """
        {"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}
        """.data(using: .utf8)!

        let description = ClaudeAPIService.apiError(statusCode: 529, data: body).localizedDescription

        XCTAssertTrue(description.contains("529"), "Got: \(description)")
        XCTAssertTrue(description.contains("Overloaded"), "Got: \(description)")
        XCTAssertFalse(description.localizedCaseInsensitiveContains("rate limit"),
                       "Non-429 must not claim a rate limit, got: \(description)")
    }

    func testMalformedErrorBodyFallsBackToStatusOnly() {
        let garbage = Data([0xDE, 0xAD, 0xBE, 0xEF])

        let description = ClaudeAPIService.apiError(statusCode: 500, data: garbage).localizedDescription

        XCTAssertTrue(description.contains("500"),
                      "Fallback must still report the status, got: \(description)")
    }

    func testEmptyErrorBodyFallsBackToStatusOnly() {
        let description = ClaudeAPIService.apiError(statusCode: 401, data: Data()).localizedDescription
        XCTAssertTrue(description.contains("401"), "Got: \(description)")
    }

    // MARK: - Request construction

    func testBuildRequestSetsTimeoutModelAndHeaders() throws {
        let service = ClaudeAPIService(apiKey: "sk-ant-test")
        let url = URL(string: "https://api.anthropic.com/v1/messages")!

        let request = try service.buildRequest(url: url, apiKey: "sk-ant-test", prompt: "hello")

        XCTAssertEqual(request.timeoutInterval, 30,
                       "Requests must time out within 30s")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "sk-ant-test")
        XCTAssertNotNil(request.value(forHTTPHeaderField: "anthropic-version"))

        let bodyData = try XCTUnwrap(request.httpBody)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        XCTAssertEqual(body["model"] as? String, "claude-haiku-4-5",
                       "Model must be the current (non-retired) Haiku alias")
    }
}
