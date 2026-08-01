#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.8": *
#import "@preview/cetz:0.4.2"
#import "@preview/cetz-plot:0.1.2"

#import "colors.typ": *
#import "util.typ": *

// Latin comes from one variable font. Its monospace cut is the exception: it lives
// on Recursive's MONO axis, which Typst cannot address, so it is pre-instanced by
// tools/make-fonts.py.
// Persian is Morabba Regular, and that is the only cut shipped in fonts/.
// Recursive sits ahead of it in every stack so latin comes from Recursive at the
// same requested weight, and Vazirmatn stands behind it as a coverage fallback.
// Swapping the persian face means changing these three lines and nothing else.
// "Estedad[wght].ttf" is also in fonts/: it is variable over the whole 100-900
// range, so with `fa-family: "Estedad"` the weights below can go to 700 and 600.
#let fa-family = "Morabba"

// Morabba Regular is the only persian cut available, so any weight above 400 would
// fall back to a synthesised face for persian while Recursive (a variable font) really
// did get heavier — bolding the latin runs alone and reading as random emphasis
// mid-sentence. Both weights below are therefore 400, and emphasis is carried by size
// and colour instead.
#let display-weight = 400
#let strong-weight = 400

#let font = (
  fa: ("Recursive Sans Linear", fa-family, "Vazirmatn"),
  en: "Recursive Sans Linear",
  mono: ("Recursive Mono Linear", "Vazirmatn"),
  display: ("Recursive Sans Linear", fa-family, "Vazirmatn"),
)

#let en(body) = text(font: font.en, dir: ltr, lang: "en", body)

#let ltr-block(body) = block(width: 100%, align(left, en(body)))

#let body-started = state("body-started", false)
#let doc-title = state("doc-title", none)


#let chapter-num(n) = fa-num(..split-num(n))

// ── running header ───────────────────────────────────────────────────────────
// Every page carries it except the cover and the contents, which switch it off
// through their own `set page`.
#let running-header = context {
  let pg = here().page()
  let chapters = query(heading.where(level: 1))
  let current = chapters.filter(c => c.location().page() <= pg).at(-1, default: none)

  if current != none {
    set text(size: 9pt, fill: muted)
    block(width: 100%, {
      grid(
        columns: (auto, 1fr),
        align: (right + bottom, left + bottom),
        text(fill: muted, doc-title.at(here())),
        {
          if current.numbering != none {
            text(fill: accent, weight: strong-weight)[بخش #fa(counter(heading).at(current.location()).first())]
            h(0.4em)
            text(fill: rule-color)[|]
            h(0.4em)
          }
          text(fill: primary, current.body)
        },
      )
      v(-0.4em)
      line(length: 100%, stroke: 0.5pt + rule-color)
    })
  }
}

#let running-footer = context {
  if body-started.at(here()) {
    set align(center)
    set text(size: 9pt, fill: muted)
    counter(page).display(n => fa(n))
  }
}

// ── chapter opening page ─────────────────────────────────────────────────────
#let chapter-page(it) = {
  pagebreak(weak: true)
  context {
    let h = counter(heading).get()
    let base = (if h.len() > 0 { h.first() } else { 0 }) * chapter-stride
    counter(math.equation).update(base)
    counter(figure.where(kind: image)).update(base)
    counter(figure.where(kind: table)).update(base)
    counter(figure.where(kind: raw)).update(base)
  }

  block(above: 0em, below: 1.1em, width: 100%, {
    set par(justify: false, leading: 0.5em)
    if it.numbering != none {
      text(size: 11pt, fill: accent, weight: strong-weight)[
        بخش #counter(heading).display()
      ]
      linebreak()
    }
    text(font: font.display, weight: display-weight, size: 22pt, fill: primary, it.body)
    v(0.25em)
    line(length: 30%, stroke: 1.8pt + accent)
  })
}

// ── cover pattern ────────────────────────────────────────────────────────────
// A field of cache lines: a grid of blocks that starts solid against the edge bar
// and dissolves into outlines as it moves inward. The fill of each block is a
// hash of its position, so the field is deterministic but reads as unordered.
#let cover-field(height: 4.4cm, flip: false, cell: 0.46cm, gap: 0.16cm) = block(
  width: 100%, height: height, clip: true,
  {
    let step = cell + gap
    let cols = int(22cm / step) + 1
    let rows = int(height / step) + 1
    for r in range(rows) {
      // depth counts away from the edge the field hangs from, and drives the fade
      let depth = if flip { r } else { r }
      let solid-cut = calc.max(0, 58 - depth * 17)
      let ghost-cut = calc.max(0, 88 - depth * 21)
      for c in range(cols) {
        let k = calc.rem(calc.div-euclid((r + 3) * (c + 11) * 2654435761, 512), 100)
        place(
          (if flip { bottom } else { top }) + left,
          dx: c * step,
          dy: (if flip { -1 } else { 1 }) * r * step,
          rect(
            width: cell, height: cell, radius: 1.5pt,
            fill: if k < solid-cut { accent } else if k < ghost-cut { accent.transparentize(74%) } else { none },
            stroke: if k < ghost-cut { none } else { 0.7pt + rule-color },
          ),
        )
      }
    }
  },
)

// the bar the field hangs from: one heavy accent edge at the top and the bottom
#let cover-bar = rect(width: 100%, height: 0.42cm, fill: accent)

// ── title page ───────────────────────────────────────────────────────────────
#let title-page(info) = {
  set page(
    header: none,
    footer: none,
    margin: (top: 0cm, bottom: 0cm, inside: 2.2cm, outside: 1.8cm),
    background: block(width: 100%, height: 100%, {
      place(top + left, cover-bar)
      place(top + left, dy: 0.42cm, cover-field())
      place(bottom + left, cover-bar)
      place(bottom + left, dy: -0.42cm, cover-field(height: 3.2cm, flip: true))
    }),
  )
  set align(center)
  set par(leading: 0.6em)

  v(1fr)

  if info.logo != none { image(info.logo, width: 2.2cm); v(0.4cm) }
  text(size: 12pt, fill: muted, info.university)
  if info.faculty != none {
    linebreak()
    text(size: 10.5pt, fill: muted, info.faculty)
  }
  v(1.2cm)
  line(length: 42%, stroke: 2.2pt + accent)
  v(0.5cm)
  text(font: font.display, weight: display-weight, size: 25pt, fill: primary, info.title)
  if info.subtitle != none {
    v(0.35cm)
    text(size: 13pt, fill: secondary, info.subtitle)
  }
  v(0.5cm)
  line(length: 42%, stroke: 2.2pt + accent)
  v(1.1cm)

  // the authors sit together in one card so the four of them read as a group
  if info.authors.len() > 0 {
    block(
      width: 82%,
      inset: (x: 1.1em, y: 1em),
      radius: 5pt,
      fill: surface,
      stroke: 0.6pt + rule-color,
      {
        if info.group != none {
          text(size: 10.5pt, weight: strong-weight, fill: accent, info.group)
          v(0.5em, weak: true)
          line(length: 100%, stroke: 0.5pt + rule-color)
          v(0.6em, weak: true)
        }
        set align(center)
        grid(
          columns: (1fr, 1fr),
          column-gutter: 1.4em,
          row-gutter: 0.75em,
          ..info.authors.map(((name, id)) => box({
            text(weight: strong-weight, name)
            h(0.5em)
            text(size: 9.5pt, fill: muted, id)
          }))
        )
      },
    )
    v(0.9cm)
  }

  if info.meta.len() > 0 {
    grid(
      columns: (auto, auto),
      column-gutter: 1em,
      row-gutter: 0.7em,
      align: (right, right),
      ..info.meta.map(((k, v)) => (text(fill: muted)[#k:], text(weight: strong-weight, v))).flatten()
    )
    v(1.1cm)
  }

  text(fill: muted, info.date)

  v(1fr)
  pagebreak()
}

// ── main template ────────────────────────────────────────────────────────────
#let report(
  title: [عنوان گزارش],
  subtitle: none,
  university: [نام دانشگاه],
  faculty: none,
  logo: none,
  date: [تابستان ۱۴۰۴],
  group: none,
  authors: (),
  meta: (),
  refs: none,
  abstract: none,
  keywords: (),
  body,
) = {
  set document(title: title)
  set page(
    paper: "a4",
    margin: (top: 2.2cm, bottom: 1.9cm, inside: 2.2cm, outside: 1.8cm),
    header: running-header,
    header-ascent: 40%,
    footer-descent: 30%,
    footer: running-footer,
    numbering: none,
  )

  set text(font: font.fa, size: 11pt, lang: "fa", dir: rtl, fill: ink)
  set par(justify: true, leading: 0.62em, first-line-indent: 1.2em, spacing: 0.85em)
  set heading(numbering: (..n) => fa-num(..n.pos()), supplement: [بخش])
  set math.equation(
    numbering: n => text(font: font.fa, size: 10pt, chapter-num(n)),
    supplement: [رابطهٔ],
  )
  set enum(numbering: (..n) => fa(n.pos().last()) + ".")
  set list(marker: text(fill: accent)[•])
  set table(stroke: 0.5pt + rule-color, fill: (_, y) => if y == 0 { surface })
  show table.cell.where(y: 0): set text(fill: primary)
  // narrow cells stretch persian words apart when justified, so cells stay ragged
  show table.cell: set par(justify: false)
  set line(stroke: 0.5pt + rule-color)

  show link: it => text(fill: secondary, it)
  show ref: it => text(fill: secondary, it)
  show cite: it => text(fill: secondary, it)
  // persian resolves any weight below 700 to Regular, so a bold span would only
  // thicken its latin runs and read as random emphasis; strong is colour alone
  show strong: it => text(fill: primary, it.body)

  show heading: set block(above: 0.95em, below: 0.55em)
  show heading.where(level: 1): chapter-page
  show heading.where(level: 2): set text(font: font.display, weight: display-weight, size: 14.5pt, fill: primary)
  show heading.where(level: 3): set text(size: 12pt, fill: secondary)
  show heading.where(level: 4): set text(size: 11pt, fill: muted)

  show figure.where(kind: table): set figure(supplement: [جدول], numbering: n => chapter-num(n))
  show figure.where(kind: image): set figure(supplement: [شکل], numbering: n => chapter-num(n))
  show figure.where(kind: raw): set figure(supplement: [کد], numbering: n => chapter-num(n))
  show figure.caption: set text(size: 9.5pt, fill: muted)

  show raw: set text(font: font.mono, size: 9pt)
  show raw.where(block: true): set text(dir: ltr, lang: "en")
  // Inline code is latin even mid-sentence, so it takes Recursive Mono like block raw.
  // But it also inherits the paragraph's rtl base, which reorders the neutrals inside
  // identifiers (`cpu0->LLC TOTAL`, `[0, ways-1]`, `maxRRPV - 1`). Boxing each span as
  // its own ltr run isolates it from the surrounding bidi without touching the text.
  show raw.where(block: false): it => box(text(dir: ltr, lang: "en", it))
  show: codly-init
  codly(
    languages: codly-languages,
    zebra-fill: none,
    fill: palette.code-bg,
    stroke: 0.5pt + rule-color,
    number-format: n => text(fill: muted, size: 8pt, str(n)),
    radius: 4pt,
    inset: 4pt,
  )

  title-page((
    title: title,
    subtitle: subtitle,
    university: university,
    faculty: faculty,
    logo: logo,
    date: date,
    group: group,
    authors: authors,
    meta: meta,
  ))

  // the cover overrode the page margins and background; restore them
  set page(
    margin: (top: 2.2cm, bottom: 1.9cm, inside: 2.2cm, outside: 1.8cm),
    background: none,
  )

  // ── front matter ───────────────────────────────────────────────────────────
  set page(numbering: none)
  counter(page).update(1)
  doc-title.update(title)

  {
    set page(header: none)
    // entries stay clickable but keep the surrounding text colour
    show link: it => it.body
    // an entry whose title ends in a latin run drags the neutral dot leader and
    // the page number into that run and flips the whole line; wrapping the title
    // in a bidi isolate keeps it a single rtl-neutral unit
    show outline.entry: it => {
      let dest = it.element.location()
      it.indented(
        it.prefix(),
        {
          link(dest, [#"\u{2068}"#it.body()#"\u{2069}"])
          box(width: 1fr, inset: (x: 0.3em), it.fill)
          link(dest, it.page())
        },
      )
    }
    show outline.entry.where(level: 1): it => {
      v(0.7em, weak: true)
      // persian has no semibold cut, so a weight bump would only bolden the latin
      // runs of an entry; the level reads from the colour and the leading instead
      text(weight: display-weight, fill: primary, it)
    }
    outline(title: [فهرست مطالب], depth: 3, indent: 1.2em)
  }

  if abstract != none {
    heading([چکیده], level: 1, numbering: none, outlined: false)
    set par(first-line-indent: 0em)
    abstract
    if keywords.len() > 0 {
      v(1em)
      text(weight: strong-weight)[واژگان کلیدی: ]
      keywords.join("، ")
    }
  }

  // ── body ───────────────────────────────────────────────────────────────────
  pagebreak(weak: true)
  body-started.update(true)
  counter(page).update(1)
  set page(numbering: n => fa(n))
  counter(heading).update(0)

  body

  if refs != none {
    pagebreak(weak: true)
    heading([مراجع], level: 1, numbering: none, outlined: true)
    set text(font: font.en, dir: ltr, lang: "en", size: 10pt)
    set par(justify: false, first-line-indent: 0em)
    refs
  }
}

// ── authoring helpers ────────────────────────────────────────────────────────
#let note(title: [یادداشت], body) = block(
  width: 100%,
  inset: (x: 1em, y: 0.9em),
  radius: 4pt,
  fill: palette.surface,
  stroke: (right: 3pt + palette.note),
  {
    text(weight: strong-weight, fill: palette.note, title)
    linebreak()
    body
  },
)

#let warn(title: [هشدار], body) = block(
  width: 100%,
  inset: (x: 1em, y: 0.9em),
  radius: 4pt,
  fill: palette.surface,
  stroke: (right: 3pt + palette.warn),
  {
    text(weight: strong-weight, fill: palette.warn, title)
    linebreak()
    body
  },
)

#let diagram(caption: none, label-name: none, size: 8pt, ..args) = {
  let canvas = text(font: font.en, lang: "en", dir: ltr, size: size, cetz.canvas(..args))
  let f = figure(canvas, caption: caption, kind: image, supplement: [شکل])
  if label-name != none { [#f#label(label-name)] } else { f }
}
