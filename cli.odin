package xystle

import "core:bytes"
import "core:flags"
import "core:fmt"
import "core:log"
import "core:os"
import "core:os/os2"
import "core:strings"
import "core:terminal/ansi"

highlight_text :: proc(text: string, highlights: [dynamic]string) -> string {
	str := strings.builder_make()
	strings.write_string(&str, text)

	for h in highlights {
		strings.builder_replace_all(
			&str,
			h,
			fmt.tprintf(
				"%s%s%s%s%s",
				ansi.CSI +
				ansi.BG_YELLOW +
				";" +
				ansi.FG_RED +
				ansi.SGR +
				"[" +
				ansi.CSI +
				ansi.RESET +
				ansi.SGR,
				ansi.CSI + ansi.BG_YELLOW + ansi.SGR,
				h,
				ansi.CSI + ansi.RESET + ansi.SGR,
				ansi.CSI +
				ansi.BG_YELLOW +
				";" +
				ansi.FG_RED +
				ansi.SGR +
				"]" +
				ansi.CSI +
				ansi.RESET +
				ansi.SGR,
			),
		)
	}

	return strings.to_string(str)
}

display_zg_response :: proc(resp: ZG_Input_Response, input_text: string) {
	w := get_term_size()
	log.debugf("w=%v", w)

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
	fmt.println(highlight_text(input_text, resp.data.h))

	print_center(w, "ADDITIONAL INFORMATION")
	fmt.print("\n")
	fmt.println(render_key_value_info("Total Words", fmt.tprintf("%d", resp.data.textWords)))
	fmt.println(render_key_value_info("AI Words", fmt.tprintf("%d", resp.data.aiWords)))
	fmt.println(render_key_value_info("Feedback", resp.data.feedback))
	fmt.println(render_key_value_info("Detected Language", resp.data.detected_language))
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

display_version :: proc() {
	fmt.printfln(
		"xystle version %v (%v %v)",
		#config(VERSION, "none"),
		#config(GIT_HASH, "none")[1:], // Sometimes, it gets interpreted as integer otherwise
		#config(COMP_DATE, "none"),
	)
}

Options :: struct {
	i: os.Handle `args:"pos=0,file=r" usage:"Input file. Reads from stdin if not provided"`,
	v: bool `usage:"Show version info"`,
	j: bool `usage:"Output JSON response and exit. Useful for scripting"`,
	l: log.Level `usage:"Set log level. Info by default. Options: Debug, Info, Warning, Error, Fatal"`,
}

opt: Options

main :: proc() {
	opt.l = .Info

	style: flags.Parsing_Style = .Odin
	flags.parse_or_exit(&opt, os.args, style)

	context.logger = log.create_console_logger(opt.l)

	if opt.v {
		display_version()
		os2.exit(0)
	}

	text: string

	if opt.i != 0 {
		data := os.read_entire_file(opt.i) or_else panic("Failed to read file")
		text = string(data)
		if len(text) == 0 {
			log.errorf("File has no text on it")
			os2.exit(1)
		}
	} else {
		log.infof("Reading from stdin...")
		textRaw, err := os2.read_entire_file(os2.stdin, context.allocator)
		if err != nil {
			log.errorf("Something went wrong when reading stdin: %#v", err)
			os2.exit(1)
		}
		if len(textRaw) == 0 {
			log.errorf("Stdin is empty")
			os2.exit(1)
		}
		text = string(textRaw)
	}

	assert(text != "")

	if len(text) > ZG_FREE_MAX_CHARS {
		log.warnf("Input's length is %d, which exceeds 15,000 characters (free limit)", len(text))
	}

	log.infof("Processing input...")

	inp_buf := bytes.Buffer{}
	input, ierror, iok := zg_prepare_input(text)
	if !iok {
		log.errorf(
			"Something went wrong when we tried to process your input: %s %#v",
			ierror.message,
			ierror,
		)
		os2.exit(1)
	}
	bytes.buffer_init_string(&inp_buf, input)
	defer bytes.buffer_destroy(&inp_buf)

	resp, body, rerror, rok := get_zg_response_for_input(inp_buf)

	if !rok {
		log.errorf(
			"Something went wrong when we tried to fetch your result: %s %#v",
			rerror.message,
			rerror,
		)
		os2.exit(1)
	}

	if opt.j {
		fmt.println(body)
		os2.exit(1)
	}

	display_zg_response(resp, text)
}
