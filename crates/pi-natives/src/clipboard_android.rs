//! Text clipboard integration through the optional Termux:API companion.
//! Android image clipboard reads are unavailable through this interface.

use std::{
	io::Write,
	process::{Command, Stdio},
};

use napi::{JsString, bindgen_prelude::*};
use napi_derive::napi;

use crate::{js, task};

static CLIPBOARD_ACCESS: parking_lot::Mutex<()> = parking_lot::Mutex::new(());

#[napi(object)]
pub struct ClipboardImage {
	pub data:      Uint8Array,
	pub mime_type: String,
}

fn clipboard_error(error: impl std::fmt::Display) -> Error {
	Error::from_reason(format!(
		"Termux clipboard: {error}. Install termux-api and the matching Termux:API Android app."
	))
}

#[napi]
pub fn copy_to_clipboard(text: JsString) -> Result<()> {
	let text = js::utf8(text)?;
	let _access = CLIPBOARD_ACCESS.lock();
	let mut child = Command::new("termux-clipboard-set")
		.stdin(Stdio::piped())
		.stdout(Stdio::null())
		.stderr(Stdio::piped())
		.spawn()
		.map_err(clipboard_error)?;
	let write_result = child
		.stdin
		.take()
		.expect("piped stdin")
		.write_all(text.as_bytes());
	let output = child.wait_with_output().map_err(clipboard_error)?;
	write_result.map_err(clipboard_error)?;
	if !output.status.success() {
		return Err(clipboard_error(String::from_utf8_lossy(&output.stderr)));
	}
	Ok(())
}

#[napi]
pub fn read_text_from_clipboard() -> task::Promise<Option<String>> {
	task::blocking("clipboard.read_text", (), move |_| -> Result<Option<String>> {
		let _access = CLIPBOARD_ACCESS.lock();
		let output = Command::new("termux-clipboard-get")
			.stdin(Stdio::null())
			.output()
			.map_err(clipboard_error)?;
		if !output.status.success() {
			return Err(clipboard_error(String::from_utf8_lossy(&output.stderr)));
		}
		String::from_utf8(output.stdout)
			.map(Some)
			.map_err(clipboard_error)
	})
}

#[napi]
pub fn read_image_from_clipboard() -> task::Promise<Option<ClipboardImage>> {
	task::blocking("clipboard.read_image", (), move |_| -> Result<Option<ClipboardImage>> {
		Ok(None)
	})
}
