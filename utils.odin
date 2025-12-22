package xystle

import "core:fmt"
import "core:strings"
import "core:sys/linux"
import "core:text/regex"

winsize :: struct {
	ws_row:    u16,
	ws_col:    u16,
	ws_xpixel: u16,
	ws_ypixel: u16,
}

get_term_size :: proc() -> (w: winsize) {
	linux.ioctl(linux.STDOUT_FILENO, linux.TIOCGWINSZ, uintptr(&w))
	return
}

strip_ansi :: proc(text: string) -> string {
	stripped_str := strings.builder_make()
	iter, err := regex.create_iterator(text, "\x1B\\[[0-9;]*m")

	capts: [dynamic][2]int
	for capture, index in regex.match_iterator(&iter) {
		append(&capts, capture.pos[0])
	}

	parent: for ch, index in text {
		for range in capts {
			if range[0] <= index && index < range[1] {
				continue parent
			}
		}
		strings.write_rune(&stripped_str, ch)
	}

	return strings.to_string(stripped_str)
}

print_center :: proc(
	w: winsize,
	text: string,
	pad: string = " ",
	do_right_pad: bool = false,
	skip_ansi: bool = true,
) {
	text_len := skip_ansi ? len(strip_ansi(text)) : len(text)
	half := int(w.ws_col / 2) - text_len / 2
	for i in 0 ..< half {
		fmt.printf("%s", pad)
	}
	fmt.print(text)
	if do_right_pad do for i in 0 ..< (int(w.ws_col) - half - text_len) {
		fmt.printf("%s", pad)
	}
}
