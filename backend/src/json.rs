use std::collections::BTreeMap;

#[derive(Debug, Clone, PartialEq)]
pub enum JsonVal {
    Null,
    Bool(bool),
    Num(f64),
    Str(String),
    Arr(Vec<JsonVal>),
    Obj(BTreeMap<String, JsonVal>),
}

impl JsonVal {
    pub fn as_str(&self) -> Option<&str> {
        match self {
            JsonVal::Str(s) => Some(s.as_str()),
            _ => None,
        }
    }

    pub fn as_bool(&self) -> Option<bool> {
        match self {
            JsonVal::Bool(b) => Some(*b),
            _ => None,
        }
    }

    pub fn as_i64(&self) -> Option<i64> {
        match self {
            JsonVal::Num(n) => Some(*n as i64),
            _ => None,
        }
    }

    pub fn as_f64(&self) -> Option<f64> {
        match self {
            JsonVal::Num(n) => Some(*n),
            _ => None,
        }
    }

    pub fn as_arr(&self) -> Option<&Vec<JsonVal>> {
        match self {
            JsonVal::Arr(a) => Some(a),
            _ => None,
        }
    }

    pub fn as_obj(&self) -> Option<&BTreeMap<String, JsonVal>> {
        match self {
            JsonVal::Obj(o) => Some(o),
            _ => None,
        }
    }

    pub fn get(&self, key: &str) -> Option<&JsonVal> {
        self.as_obj()?.get(key)
    }
}

pub fn escape_str(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 2);
    out.push('"');
    for ch in s.chars() {
        match ch {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => {
                use std::fmt::Write;
                let _ = write!(out, "\\u{:04x}", c as u32);
            }
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

pub fn parse(input: &str) -> Result<JsonVal, String> {
    let bytes = input.as_bytes();
    let mut pos = 0usize;
    let val = parse_value(bytes, &mut pos)?;
    skip_ws(bytes, &mut pos);
    Ok(val)
}

fn skip_ws(b: &[u8], pos: &mut usize) {
    while *pos < b.len() && matches!(b[*pos], b' ' | b'\n' | b'\r' | b'\t') {
        *pos += 1;
    }
}

fn parse_value(b: &[u8], pos: &mut usize) -> Result<JsonVal, String> {
    skip_ws(b, pos);
    if *pos >= b.len() {
        return Err("unexpected EOF".to_string());
    }
    match b[*pos] {
        b'n' => {
            if b[*pos..].starts_with(b"null") {
                *pos += 4;
                Ok(JsonVal::Null)
            } else {
                Err("invalid null".to_string())
            }
        }
        b't' => {
            if b[*pos..].starts_with(b"true") {
                *pos += 4;
                Ok(JsonVal::Bool(true))
            } else {
                Err("invalid true".to_string())
            }
        }
        b'f' => {
            if b[*pos..].starts_with(b"false") {
                *pos += 5;
                Ok(JsonVal::Bool(false))
            } else {
                Err("invalid false".to_string())
            }
        }
        b'"' => Ok(JsonVal::Str(parse_str(b, pos)?)),
        b'[' => parse_arr(b, pos),
        b'{' => parse_obj(b, pos),
        b'-' | b'0'..=b'9' => parse_num(b, pos),
        c => Err(format!("unexpected byte: {}", c as char)),
    }
}

fn parse_str(b: &[u8], pos: &mut usize) -> Result<String, String> {
    if b[*pos] != b'"' {
        return Err("expected quote".to_string());
    }
    *pos += 1;
    let mut out = String::new();
    while *pos < b.len() {
        let byte = b[*pos];
        if byte == b'"' {
            *pos += 1;
            return Ok(out);
        }
        if byte == b'\\' {
            *pos += 1;
            if *pos >= b.len() {
                return Err("unterminated escape".to_string());
            }
            match b[*pos] {
                b'"' => out.push('"'),
                b'\\' => out.push('\\'),
                b'/' => out.push('/'),
                b'b' => out.push('\x08'),
                b'f' => out.push('\x0c'),
                b'n' => out.push('\n'),
                b'r' => out.push('\r'),
                b't' => out.push('\t'),
                b'u' => {
                    if *pos + 4 >= b.len() {
                        return Err("short unicode escape".to_string());
                    }
                    let hex = std::str::from_utf8(&b[*pos + 1..*pos + 5]).map_err(|e| e.to_string())?;
                    let code = u32::from_str_radix(hex, 16).map_err(|e| e.to_string())?;
                    if let Some(ch) = char::from_u32(code) {
                        out.push(ch);
                    }
                    *pos += 4;
                }
                other => out.push(other as char),
            }
            *pos += 1;
        } else {
            let s = std::str::from_utf8(&b[*pos..]).map_err(|e| e.to_string())?;
            let ch = s.chars().next().ok_or_else(|| "utf8 eof".to_string())?;
            out.push(ch);
            *pos += ch.len_utf8();
        }
    }
    Err("unterminated string".to_string())
}

fn parse_num(b: &[u8], pos: &mut usize) -> Result<JsonVal, String> {
    let start = *pos;
    if b[*pos] == b'-' {
        *pos += 1;
    }
    while *pos < b.len() && matches!(b[*pos], b'0'..=b'9' | b'.' | b'e' | b'E' | b'+' | b'-') {
        *pos += 1;
    }
    let s = std::str::from_utf8(&b[start..*pos]).map_err(|e| e.to_string())?;
    let n: f64 = s.parse().map_err(|e| format!("bad number {s}: {e}"))?;
    Ok(JsonVal::Num(n))
}

fn parse_arr(b: &[u8], pos: &mut usize) -> Result<JsonVal, String> {
    *pos += 1;
    let mut items = Vec::new();
    skip_ws(b, pos);
    if *pos < b.len() && b[*pos] == b']' {
        *pos += 1;
        return Ok(JsonVal::Arr(items));
    }
    loop {
        items.push(parse_value(b, pos)?);
        skip_ws(b, pos);
        if *pos >= b.len() {
            return Err("unterminated array".to_string());
        }
        if b[*pos] == b']' {
            *pos += 1;
            return Ok(JsonVal::Arr(items));
        }
        if b[*pos] != b',' {
            return Err("expected comma in array".to_string());
        }
        *pos += 1;
    }
}

fn parse_obj(b: &[u8], pos: &mut usize) -> Result<JsonVal, String> {
    *pos += 1;
    let mut map = BTreeMap::new();
    skip_ws(b, pos);
    if *pos < b.len() && b[*pos] == b'}' {
        *pos += 1;
        return Ok(JsonVal::Obj(map));
    }
    loop {
        skip_ws(b, pos);
        let key = parse_str(b, pos)?;
        skip_ws(b, pos);
        if *pos >= b.len() || b[*pos] != b':' {
            return Err("expected colon in object".to_string());
        }
        *pos += 1;
        let val = parse_value(b, pos)?;
        map.insert(key, val);
        skip_ws(b, pos);
        if *pos >= b.len() {
            return Err("unterminated object".to_string());
        }
        if b[*pos] == b'}' {
            *pos += 1;
            return Ok(JsonVal::Obj(map));
        }
        if b[*pos] != b',' {
            return Err("expected comma in object".to_string());
        }
        *pos += 1;
    }
}
