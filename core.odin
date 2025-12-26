package xystle

import "base:runtime"
import "core:bytes"
import "core:encoding/json"
import "core:fmt"
import "core:log"
import ohttp "odin-http"
import ohttp_client "odin-http/client"

ZG_FREE_MAX_CHARS :: 15_000

Error_Type :: enum int {
	INVALID_INPUT,
	MALFORMED_RESPONSE,
}

Error :: struct {
	type:    Error_Type,
	message: string,
}

ZG_Input_Response :: struct {
	code:    i16,
	message: string,
	data:    struct {
		isHuman:           f64,
		fakePercentage:    f64,
		h:                 [dynamic]string,
		textWords:         i64,
		aiWords:           i64,
		feedback:          string,
		detected_language: string,
	},
}

zg_prepare_input :: proc(input: string, allocator := context.allocator) -> (string, Error, bool) {
	m := make(map[string]string, allocator)
	m["input_text"] = input
	defer delete(m)

	data, err := json.marshal(m)
	if err != nil do return "", {.INVALID_INPUT, fmt.tprintf("Error while marshalling: %s", err)}, false

	return string(data), {}, true
}

zg_default_headers :: proc() -> (headers: ohttp.Headers) {
	ohttp.headers_init(&headers)
	ohttp.headers_set(&headers, "Accept", "application/json, text/plain, */*")
	ohttp.headers_set(&headers, "Accept-Language", "en-US,en;q=0.9")
	ohttp.headers_set(&headers, "Connection", "keep-alive")
	ohttp.headers_set(&headers, "Content-Type", "application/json")
	ohttp.headers_set(&headers, "Origin", "https://www.zerogpt.com")
	ohttp.headers_set(&headers, "Referer", "https://www.zerogpt.com/")
	ohttp.headers_set(&headers, "Sec-Fetch-Dest", "empty")
	ohttp.headers_set(&headers, "Sec-Fetch-Mode", "cors")
	ohttp.headers_set(&headers, "Sec-Fetch-Site", "same-site")
	ohttp.headers_set(
		&headers,
		"User-Agent",
		"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36",
	)
	ohttp.headers_set(
		&headers,
		"sec-ch-ua",
		"\"Chromium\";v=\"142\", \"Google Chrome\";v=\"142\", \"Not_A Brand\";v=\"99\"",
	)
	ohttp.headers_set(&headers, "sec-ch-ua-mobile", "?0")
	ohttp.headers_set(&headers, "sec-ch-ua-platform", "\"Linux\"")
	return
}

zg_response_parse :: proc(
	body: ohttp_client.Body_Type,
) -> (
	resp: ZG_Input_Response,
	err: Error,
	ok: bool,
) {
	switch b in body {
	case ohttp_client.Body_Plain:
		jerr := json.unmarshal_string(b, &resp)
		if jerr != nil do return resp, Error{type = .MALFORMED_RESPONSE, message = fmt.tprintf("Couldn't parse response: %#v", jerr)}, false
		return resp, err, true
	case ohttp_client.Body_Url_Encoded:
		unreachable()
	case ohttp_client.Body_Error:
		unreachable()
	}
	unreachable()
}

get_zg_response_for_input :: proc(
	inp_buf: bytes.Buffer,
) -> (
	ZG_Input_Response,
	ohttp_client.Body_Type,
	Error,
	bool,
) {
	request := ohttp_client.Request {
		method  = .Post,
		headers = zg_default_headers(),
		body    = inp_buf,
	}
	log.debugf("request=%v", request)

	res, rerr := ohttp_client.request(&request, "https://api.zerogpt.com/api/detect/detectText")
	if rerr != nil {
		return {},
			{},
			Error{type = .MALFORMED_RESPONSE, message = fmt.tprintf("request failed: %#v", rerr)},
			false
	}
	defer ohttp_client.response_destroy(&res)

	body, alloc, berr := ohttp_client.response_body(&res)
	if berr != nil {
		return {},
			body,
			Error {
				type = .MALFORMED_RESPONSE,
				message = fmt.tprintf("retreiving body failed: %#v", berr),
			},
			false
	}
	log.debugf("body=%v alloc=%v", body, alloc)
	defer ohttp_client.body_destroy(body, alloc)

	resp, reserr, ok := zg_response_parse(body)
	if !ok {
		return resp,
			body,
			Error {
				type = .MALFORMED_RESPONSE,
				message = fmt.tprintf("parsing response body failed: %#v", reserr),
			},
			false
	}
	log.debugf("resp=%v", resp)

	if resp.code != 200 {
		return resp,
			body,
			Error {
				type = .MALFORMED_RESPONSE,
				message = fmt.tprintf("ZeroGPT isn't accepting your input."),
			},
			false
	}

	return resp, body, {}, true
}
