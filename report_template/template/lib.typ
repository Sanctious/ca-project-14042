#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.8": *
#import "@preview/cetz:0.4.2"
#import "@preview/cetz-plot:0.1.2"

#import "colors.typ": *
#import "util.typ": *

// Latin comes from one variable font. Its monospace cut is the exception: it lives
// on Recursive's MONO axis, which Typst cannot address, so it is pre-instanced by
// tools/make-fonts.py.
// Persian is Morabba, Regular throughout; Heavy is on hand but never requested.
// Recursive sits ahead of it in every stack so latin comes from Recursive at the
// same requested weight, and Vazirmatn stands behind it as a coverage fallback.
// Swapping the persian face means changing these three lines and nothing else.
// "Estedad[wght].ttf" is also in fonts/: it is variable over the whole 100-900
// range, so with `fa-family: "Estedad"` the weights below can go to 700 and 600.
#let fa-family = "Morabba"

// Morabba is installed as Regular and Heavy only, and Typst resolves 400-600 to
// Regular and 700-900 to Heavy. Headings therefore stay at Regular and lean on size
// and colour instead; emphasis asks for 600, which leaves persian at Regular while
// Recursive still varies to a real semibold for latin.
#let display-weight = 400
#let strong-weight = 600

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
          text(fill: primary, weight: strong-weight, current.body)
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
// A band of hairline diagonals, clipped to its own box. Every fourth stroke is
// tinted with the accent so the field reads as a rhythm rather than a texture.
#let hatch-band(height: 3.4cm, gap: 0.34cm, angle: 62deg, flip: false) = block(
  width: 100%, height: height, clip: true,
  {
    let len = height / calc.sin(angle) + 2cm
    let count = int(21cm / gap) + int(len / gap) + 2
    for i in range(count) {
      let tint = calc.rem(i, 4) == 0
      place(
        // the flipped band rises from the bottom edge instead of falling from the top
        (if flip { bottom } else { top }) + left,
        dx: i * gap - len,
        line(
          angle: if flip { -angle } else { angle },
          length: len,
          stroke: (if tint { 0.7pt } else { 0.5pt })
            + (if tint { accent } else { rule-color }).transparentize(if tint { 55% } else { 25% }),
        ),
      )
    }
  },
)

// ── title page ───────────────────────────────────────────────────────────────
#let title-page(info) = {
  set page(
    header: none,
    footer: none,
    margin: (top: 0cm, bottom: 0cm, inside: 2.2cm, outside: 1.8cm),
    background: block(width: 100%, height: 100%, {
      place(top + left, hatch-band())
      place(bottom + left, hatch-band(flip: true))
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
  line(length: 42%, stroke: 1.5pt + accent)
  v(0.5cm)
  text(font: font.display, weight: display-weight, size: 25pt, fill: primary, info.title)
  if info.subtitle != none {
    v(0.35cm)
    text(size: 13pt, fill: secondary, info.subtitle)
  }
  v(0.5cm)
  line(length: 42%, stroke: 1.5pt + accent)
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
  show table.cell.where(y: 0): set text(weight: strong-weight, fill: primary)
  set line(stroke: 0.5pt + rule-color)

  show link: it => text(fill: secondary, it)
  show ref: it => text(fill: secondary, it)
  show cite: it => text(fill: secondary, it)
  show strong: it => text(fill: primary, weight: strong-weight, it.body)

  show heading: set block(above: 0.95em, below: 0.55em)
  show heading.where(level: 1): chapter-page
  show heading.where(level: 2): set text(font: font.display, weight: display-weight, size: 14.5pt, fill: primary)
  show heading.where(level: 3): set text(size: 12pt, weight: strong-weight, fill: secondary)
  show heading.where(level: 4): set text(size: 11pt, weight: strong-weight, fill: muted)

  show figure.where(kind: table): set figure(supplement: [جدول], numbering: n => chapter-num(n))
  show figure.where(kind: image): set figure(supplement: [شکل], numbering: n => chapter-num(n))
  show figure.where(kind: raw): set figure(supplement: [کد], numbering: n => chapter-num(n))
  show figure.caption: set text(size: 9.5pt, fill: muted)

  show raw: set text(font: font.mono, size: 9pt)
  show raw.where(block: true): set text(dir: ltr, lang: "en")
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
      text(weight: strong-weight, fill: primary, it)
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
