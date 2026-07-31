#let fa-digits = ("۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹")

#let fa(n) = {
  let s = if type(n) == str { n } else { str(n) }
  s.clusters().map(c => if c.match(regex("^[0-9]$")) != none { fa-digits.at(int(c)) } else { c }).join()
}

// the separator between persian digits is bidi-neutral, so an unisolated "۱-۲"
// reorders to "۲-۱" inside the rtl paragraph; the isolate pins it to ltr
#let ltr-isolate(body) = "\u{2066}" + body + "\u{2069}"

#let fa-num(..nums) = ltr-isolate(nums.pos().map(n => fa(n)).join("-"))

// per-chapter numbering is encoded as chapter*100 + index so that the numbering
// function stays context-free and therefore also resolves inside outlines
#let chapter-stride = 100

#let split-num(n) = (calc.div-euclid(n, chapter-stride), calc.rem-euclid(n, chapter-stride))

