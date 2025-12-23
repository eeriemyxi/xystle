package xystle

import "base:runtime"
import "core:bytes"
import "core:encoding/json"
import "core:flags"
import "core:fmt"
import "core:os"
import "core:os/os2"
import "core:strings"
import "core:terminal/ansi"
import ohttp "odin-http"
import ohttp_client "odin-http/client"

ZG_FREE_MAX_CHARS :: 15_000

Error :: enum int {
	MALFORMED_RESPONSE,
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

zg_prepare_input :: proc(input: string, allocator := context.allocator) -> string {
	m := make(map[string]string, allocator)
	m["input_text"] = input
	defer delete(m)

	data, err := json.marshal(m)
	if err != nil {
		fmt.eprintfln("Error while marshaling: %s", err)
	}

	return string(data)
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

zg_response_parse :: proc(body: ohttp_client.Body_Type) -> (resp: ZG_Input_Response, err: Error) {
	switch b in body {
	case ohttp_client.Body_Plain:
		jerr := json.unmarshal_string(b, &resp)
		if jerr != nil do return resp, .MALFORMED_RESPONSE
		return
	case ohttp_client.Body_Url_Encoded:
		unreachable()
	case ohttp_client.Body_Error:
		unreachable()
	}
	return resp, .MALFORMED_RESPONSE
}

highlight_text :: proc(text: string, highlights: [dynamic]string) -> string {
	str := strings.builder_make()
	strings.write_string(&str, text)
	
    // odinfmt: disable
	for h in highlights {
		strings.builder_replace_all(
			&str,
			h,
			fmt.tprintf(
				"%s%s%s%s%s",
				ansi.CSI + ansi.BG_YELLOW + ";" + ansi.FG_RED + ansi.SGR +
				"[" +
				ansi.CSI + ansi.RESET + ansi.SGR,
				ansi.CSI + ansi.BG_YELLOW + ansi.SGR,
				h,
				ansi.CSI + ansi.RESET + ansi.SGR,
				ansi.CSI + ansi.BG_YELLOW + ";" + ansi.FG_RED + ansi.SGR +
				"]" +
				ansi.CSI + ansi.RESET + ansi.SGR,
			), 
		)
	}
    // odinfmt: enable

	return strings.to_string(str)
}

render_key_value_info :: proc(key: string, value: string) -> string {
	return fmt.tprintf(
		"%s%s%s: %s",
		ansi.CSI + ansi.FG_BLUE + ";" + ansi.BOLD + ansi.SGR,
		key,
		ansi.CSI + ansi.RESET + ansi.SGR,
		value,
	)
}

Options :: struct {
	i: os.Handle `args:"pos=0,file=r" usage:"Input file. Optional, reads from stdin if omitted"`,
	v: bool `usage:"Show version info"`,
	j: bool `usage:"Output JSON response and exit. Useful for scripting"`,
}

opt: Options

main :: proc() {
	style: flags.Parsing_Style = .Odin
	flags.parse_or_exit(&opt, os.args, style)

	if opt.v {
		fmt.printfln(
			"xystle version %s (%s %s)",
			#config(VERSION, "none"),
			#config(GIT_HASH, "none"),
			#config(COMP_DATE, "none"),
		)
		os2.exit(0)
	}

	text: string

	if opt.i != 0 {
		data := os.read_entire_file(opt.i) or_else panic("Failed to read file")
		text = string(data)
		if len(text) == 0 {
			fmt.eprintln("[ERROR] File has no text on it")
			os2.exit(1)
		}
	} else {
		if !opt.j do fmt.println("[INFO] Reading from stdin...")
		textRaw, err := os2.read_entire_file(os2.stdin, context.allocator)
		if err != nil {
			fmt.eprintln("[ERROR] Something went wrong when reading stdin")
			os2.exit(1)
		}
		if len(textRaw) == 0 {
			fmt.eprintln("[ERROR] Stdin is empty")
			os2.exit(1)
		}
		text = string(textRaw)
	}

	assert(text != "")

	if len(text) > ZG_FREE_MAX_CHARS {
		fmt.eprintfln(
			"[WARN] Input's length is %d, which exceeds 15,000 characters (free limit)",
			len(text),
		)
	}

	if !opt.j do fmt.println("[INFO] Processing input...")

	inp_buf := bytes.Buffer{}
	bytes.buffer_init_string(&inp_buf, zg_prepare_input(text))
	defer bytes.buffer_destroy(&inp_buf)

	request := ohttp_client.Request {
		method  = .Post,
		headers = zg_default_headers(),
		body    = inp_buf,
	}

	res, err := ohttp_client.request(&request, "https://api.zerogpt.com/api/detect/detectText")
	if err != nil {
		fmt.eprintfln("[ERROR] Request failed: %s", err)
		os2.exit(1)
	}
	defer ohttp_client.response_destroy(&res)

	body, alloc, berr := ohttp_client.response_body(&res)
	if berr != nil {
		fmt.eprintfln("[ERROR] Retreiving body failed: %s", berr)
		os2.exit(1)
	}
	defer ohttp_client.body_destroy(body, alloc)

	resp, zg_resp_err := zg_response_parse(body)
	if zg_resp_err != nil {
		fmt.eprintfln("[ERROR] parsing response body failed: %s", zg_resp_err)
		os2.exit(1)
	}

	if resp.code != 200 {
		fmt.eprintln("[ERROR] ZeroGPT isn't accepting your input.")
		os2.exit(1)
	}

	if opt.j {
		fmt.println(body)
		os2.exit(0)
	}

	w := get_term_size()

	print_center(w, "VERDICT", " ")
	fmt.print("\n\n")
	print_center(
		w,
		fmt.tprintf(
			"Your text is: %s %0.2f%% %s AI\n",
			ansi.CSI + ansi.FG_WHITE + ";" + ansi.BOLD + ";" + ansi.BG_MAGENTA + ansi.SGR,
			resp.data.fakePercentage,
			ansi.CSI + ansi.RESET + ansi.SGR,
		),
	)
	fmt.print("\n")

	print_center(w, "INPUT TEXT", " ")
	fmt.print("\n")
	fmt.println(highlight_text(text, resp.data.h))

	print_center(w, "ADDITIONAL INFORMATION")
	fmt.print("\n")
	fmt.println(render_key_value_info("Total Words", fmt.tprintf("%d", resp.data.textWords)))
	fmt.println(render_key_value_info("AI Words", fmt.tprintf("%d", resp.data.aiWords)))
	fmt.println(render_key_value_info("Feedback", resp.data.feedback))
	fmt.println(render_key_value_info("Detected Language", resp.data.detected_language))
}
