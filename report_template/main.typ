#import "template/lib.typ": *

#show: report.with(
  title: [پیاده‌سازی و تحلیل سیاست‌های جایگزینی حافظهٔ نهان در #en[ChampSim]],
  subtitle: [تحلیل و بررسی سیاست های جایگزینی پایه و پیشرفته و مقایسه آنها با یکدیگر],
  university: [دانشگاه صنعتی شریف],
  faculty: [دانشکدهٔ مهندسی کامپیوتر],
  logo: none,
  date: [تابستان ۱۴۰۴],
  group: [گروه ۱۳],
  authors: (
    ([امیر محمد محقق], [۴۰۳۱۰۶۶۴۶]),
    ([امیررضا دولتی], [۴۰۳۱۰۵۲۲۲]),
    ([سپهر کلانکی], [۴۰۳۱۰۶۵۴۹]),
    ([سینا فعالیت], [۴۰۳۱۰۶۴۲۱]),
  ),
  meta: (
    ([استاد درس], [استاد اسدی]),
    ([درس], [معماری کامپیوتر]),
  ),
  refs: bibliography("refs.bib", title: none, style: "ieee"),
)

= مقدمه

مسله ی اصلی که در این پروژه باید بررسی می شد، مطالعه و مقایسه ی #en[Replacement Policy] های مختلف #en[Cache] در لایه ی آخر (#en[LLC]) است. سیاست های بررسی شده در این گزارش به شرح زیرند:

#figure(
  table(
    columns: (auto, 1fr, auto),
    align: (center + horizon, center + horizon, center + horizon),
    [مخفف], [نام کامل], [مرجع],
    en[LRU], en[Least Recently Used], [ویکی پدیا @wiki_replacement],
    en[MRU], en[Most Recently Used], [ویکی پدیا @wiki_replacement],
    en[FIFO], en[First In First Out], [ویکی پدیا @wiki_replacement],
    en[Random], en[Random Replacement], [ویکی پدیا @wiki_replacement],
    en[SRRIP], en[Static Re-Reference Interval Prediction], [مقاله ی #en[RRIP] @jaleel2010rrip],
    en[DRRIP], en[Dynamic Re-Reference Interval Prediction], [مقاله ی #en[RRIP] @jaleel2010rrip],
    en[BIP], en[Bimodal Insertion Policy], [مقاله ی #en[DIP] @qureshi2007dip],
    en[SHiP], en[Signature-based Hit Predictor], [مقاله ی #en[SHiP] @wu2011ship],
  ),
  caption: [سیاست های جایگزینی بررسی شده در این پروژه],
)

شبیه سازی ها همگی با شبیه ساز #en[ChampSim] @gober2022champsim انجام شده اند و ردپا های استفاده شده را از مخزن ردپا های آماده ی #en[ChampSim] دانلود کرده ایم @champsim_traces.

#note[
  برای بخش امتیازی ما تغییر تعداد #en[set] ها را انتخاب کردیم و بین مقادیر ۱۰۲۴ و ۲۰۴۸ و ۴۰۹۶ تغییرشان دادیم. تحلیل های خارج از حالت امتیازی روی ۲۰۴۸ انجام شده اند.
]

#note[
  تعداد دستورات برای بخش #en[warmup] برابر ۱۲٫۵ میلیون و برای بخش شبیه سازی برابر ۵۰ میلیون است.
]

= توضیح #en[Replacement Policy] ها

برای تمام #en[Replacement Policy] ها یک دور روش آنها را به طور کامل توضیح می دهیم که گزارش کامل باشد.
نکات ناقص رو نیز باید اضافه بکنیم.

== یک نکته ی مشترک بین چند #en[policy]: نوع دسترسی #en[access_type::WRITE]

در چند تا از سیاست های، یک شرط روی `access_type` می بینیم که دسترسی های نوع #en[WRITE] را جدا می کند. این نوع دسترسی ها مربوط به #en[writeback] می شود. نکته این است که این نوشتن نشانه ی استفاده ی پردازنده از داده در همان لحظه نیست، بلکه صرفا نتیجه ی #en[replacement] در سطح بالاتر است. اگر #en[writeback] ها را مثل دسترسی عادی حساب کنیم و سیاست ها را روی آنها نیز اجرا کنیم، دو مشکل پیش می آید: اول اینکه بلوک هایی که فقط نوشته شده اند بی دلیل تازه به حساب می آیند و در کش ماندگار می شوند و دوم اینکه در سیاست های پویا مثل #en[DRRIP] آمار تصمیم گیری منحرف می شود چون این دسترسی ها رفتار واقعی برنامه را نشان نمی دهند. به همین دلیل در سیاست های ما یا اثر #en[writeback] نادیده گرفته می شود یا بلوک با یک مقدار امن و غیر مخرب پر می شود.

== توابع مهم برای هر سیاست

- تابع `find_victim`: وقتی #en[miss] رخ داد، شماره ی #en[way] قربانی را برمی گرداند.
- تابع `replacement_cache_fill`: بعد از اینکه بلوک جدید داخل #en[way] قرار گرفت صدا زده می شود (منطق #en[fill]).
- تابع `update_replacement_state`: در هر دسترسی صدا زده می شود و پارامتر `hit` مشخص می کند دسترسی #en[hit] بوده یا نه.

نکته ی نهایی این نیز که بیشتر تنظیمات کلی و #en[global] به ازای هر #en[CPU Core] است، مثلا برای شمارنده ها و ...

== #en[LRU]

*منطق انتخاب بلوک قربانی:*

بین تمام بلوک های موجود در یک #en[set]، بلوکی حذف می شود که بیشترین زمان بدون استفاده مانده است، به همین دلیل بلوک های که دسترسی بیشتری در طول زمان دارند کمتر حذف می شوند.

*نحوه بروزرسانی اطلاعات کمکی:*

هر بلوک یک مقدار زمان دسترسی نگه می دارد که نشان می دهد نسبت به بقیه بلوک ها داخل همان #en[set] کی مورد دسترسی واقع شده است. مقدار ۰ یعنی اینکه نسبت به بقیه قدیمی تر استفاده شده است، و هرچه مقدار آن بزرگتر باشد یعنی اینکه نسبت به بقیه جدید تر مورد دسترسی واقع شده است، و جدیدترین دسترسی این #en[set] است. هر دسترسی با توجه به #en[Miss] یا #en[Hit] شدن مقادیر را تغییر می دهیم که ترتیب دسترسی حفظ شود.

*نحوه ی بروزرسانی اطلاعات پس از برخورد (#en[hit]):*

در هنگام #en[hit] برچسب زمان همان بلوک برابر مقدار فعلی شمارنده ی `cycle` می شود و بعد `cycle` یکی زیاد می شود. یعنی آن بلوک تبدیل به جدیدترین بلوک (#en[MRU]) در #en[set] خودش می شود و برچسب بقیه ی بلوک ها دست نخورده باقی می ماند، پس به صورت نسبی همه ی آنها یک واحد زمانی قدیمی تر می شوند. تنها استثنا دسترسی های نوع #en[WRITE] است که مطابق توضیح ابتدای بخش نادیده گرفته می شوند و برچسب زمان را عوض نمی کنند.

*نحوه ی بروزرسانی اطلاعات پس از جایگزینی (#en[fill]):*

بعد از اینکه بلوک قربانی خارج شد و بلوک جدید در همان #en[way] نشست، تابع `replacement_cache_fill` برچسب زمان آن #en[way] را برابر `cycle` قرار می دهد و شمارنده را زیاد می کند. پس بلوک تازه درج شده در موقعیت #en[MRU] قرار می گیرد و امن ترین بلوک #en[set] است، یعنی تا وقتی که تمام بلوک های دیگر یک بار خارج نشوند نوبت به آن نمی رسد. هیچ اطلاعات دیگری در #en[set] بروزرسانی نمی شود.

*شرایط عملکرد مناسب و نامناسب:*

سیاست #en[LRU] وقتی خوب کار می کند که برنامه از داده هایی که استفاده می کند به تعداد بالاتری نیز مجدد استفاده بکند.

در مقابل، #en[LRU] در حالت های #en[scan] های خطی یا حلقه ای که در #en[cache] جا نشوند بد عمل می کند، چون به ترتیب داده ها یکبار مصرف می شوند و در دومی تا به سر آرایه برسیم آن داده ها دور ریخته شده اند و عملا فقط #en[cache] را کثیف کردیم.

*نکات کد:*

=== قطعه ۱ — ساختار داده ی کمکی و سازنده

```cpp
class lru : public champsim::modules::replacement
{
  long NUM_WAY;
  std::vector<uint64_t> last_used_cycles;
  uint64_t cycle = 0;
  ...
};

lru::lru(CACHE* cache) : lru(cache, cache->NUM_SET, cache->NUM_WAY) {}

lru::lru(CACHE* cache, long sets, long ways)
    : replacement(cache), NUM_WAY(ways),
      last_used_cycles(static_cast<std::size_t>(sets * ways), 0) {}
```

اطلاعات اضافه در یک بردار یک-بعدی به طول `sets * ways` نگه داری می شود و آدرس هر بلوک با فرمول `set * NUM_WAY + way` به دست می آید.

=== قطعه ۲ — انتخاب بلوک قربانی

```cpp
long lru::find_victim(uint32_t triggering_cpu, uint64_t instr_id, long set, ...)
{
  auto begin = std::next(std::begin(last_used_cycles), set * NUM_WAY);
  auto end = std::next(begin, NUM_WAY);

  // Find the way whose last use cycle is most distant
  auto victim = std::min_element(begin, end);
  assert(begin <= victim);
  assert(victim < end);
  return std::distance(begin, victim);
}
```

ابتدا با `begin` و `end` بازه ی مربوط به همان #en[set] جدا می شود و بعد `min_element` کوچک ترین برچسب زمان را پیدا می کند. چون برچسب بزرگ تر یعنی دسترسی جدیدتر، کوچک ترین مقدار دقیقا یعنی بلوکی که از همه دیرتر استفاده شده است.

اگر چند بلوک مقدار برابر داشته باشند (مثلا چند #en[way] هنوز دست نخورده و برابر ۰ باشند)، `min_element` اولین آنها را برمی گرداند، پس ترتیب پر شدن #en[set] از #en[way] کوچک به بزرگ است.

=== قطعه ۳ — درج و به روزرسانی

```cpp
void lru::replacement_cache_fill(uint32_t triggering_cpu, long set, long way, ...)
{
  // Mark the way as being used on the current cycle
  last_used_cycles.at((std::size_t)(set * NUM_WAY + way)) = cycle++;
}

void lru::update_replacement_state(..., uint8_t hit)
{
  // Mark the way as being used on the current cycle
  if (hit && access_type{type} != access_type::WRITE) // Skip this for writeback hits
    last_used_cycles.at((std::size_t)(set * NUM_WAY + way)) = cycle++;
}
```

در زمان درج بلوک جدید در موقعیت #en[MRU] قرار می گیرد و کم خطر ترین بلوک #en[set] است.

== #en[FIFO]

*منطق انتخاب بلوک قربانی:*

بین تمام بلوک های موجود در #en[set]، بلوکی که زودتر از همه وارد شده است باید خارج شود (منطق #en[First In First Out]). اینکه بلوک اخیرا دسترسی قرار گرفته یا نه تاثیری در تصمیم گیری ندارد. عملا منطق صف دارد.

*نحوه بروزرسانی اطلاعات کمکی:*

یک ترتیب ورود برای بلوک هایی که به #en[set] وارد می شوند ذخیره می کند. موقع #en[hit] چیزی را تغییر نمی دهد ولی موقع #en[miss] ترتیب عوض می شود (البته بدون آپدیت کردن مقدار بقیه چون زمان اضافه شدن اهمیت دارد).

*نحوه ی بروزرسانی اطلاعات پس از برخورد (#en[hit]):*

هیچ بروزرسانی ای انجام نمی شود و تابع `update_replacement_state` کاملا خالی است.

*نحوه ی بروزرسانی اطلاعات پس از جایگزینی (#en[fill]):*

بعد از درج بلوک جدید، برچسب آن #en[way] برابر مقدار فعلی `cycle` قرار می گیرد و شمارنده یکی زیاد می شود، یعنی بلوک جدید به انتهای صف اضافه می شود. برچسب بقیه ی بلوک ها دست نمی خورد چون ترتیب ورود آنها ثابت است و ربطی به بلوک جدید ندارد.

*شرایط عملکرد مناسب و نامناسب:*

سیاست #en[FIFO] وقتی خوب عمل می کند که ترتیب ورودی داده ها با ترتیب استفاده از آنها هماهنگ باشد.

در جاهایی بد عمل می کند که بلوکی زود وارد #en[cache] شود ولی چون صرفا زود وارد شده ممکن است با اینکه در آینده ی نزدیک خیلی استفاده می شود دور ریخته شود، و هوشمندی این را ندارد که اگر یک بلوک زیاد استفاده می شود نباید سریع بیرون بیندازدش.

*نکات کد:*

=== قطعه ۱ — ساختار داده

```cpp
class fifo : public champsim::modules::replacement
{
  long NUM_WAY;
  std::vector<uint64_t> insertion_cycles;
  uint64_t cycle = 0;
  ...
};
```

ساختار داده دقیقا مثل #en[LRU] است و تنها چیزی که فرق می کند مفهوم عدد کمکی است، که اینجا مفهوم زمان وارد شدن بلوک به #en[set] را می دهد. `cycle` در اینجا یک شمارنده کلی است که برای زمان اضافه شدن استفاده می شود و بیانگر شمارشگر زمان است که در هنگام هر #en[fill] افزایش پیدا می کند.

=== قطعه ۲ — انتخاب قربانی و ثبت زمان ورود

```cpp
long fifo::find_victim(uint32_t triggering_cpu, uint64_t instr_id, long set, ...)
{
    auto begin = std::next(std::begin(insertion_cycles), set * NUM_WAY);
    auto end = std::next(begin, NUM_WAY);

    // Evict the oldest inserted block
    auto victim = std::min_element(begin, end);
    return std::distance(begin, victim);
}

void fifo::replacement_cache_fill(uint32_t triggering_cpu, long set, long way, ...)
{
    // Record insertion time
    insertion_cycles.at((std::size_t)(set * NUM_WAY + way)) = cycle++;
}
```

بدون اینکه صف واقعی داشته باشیم، با یک برچسب زمان ورود همان رفتار صف را می سازیم، کمترین مقدار یعنی قدیمی ترین ورود که همان بلوک از صف خارج می شود.

=== قطعه ۳ — تابع خالی به روزرسانی

```cpp
void fifo::update_replacement_state(..., uint8_t hit)
{
}
```

تابع #en[update] این #en[policy] خالی است چون طبق توضیحات در #en[FIFO] لازم نیست کاری انجام بدهیم.

== #en[MRU]

*منطق انتخاب بلوک قربانی:*

کاملا مخالف #en[LRU] عمل می کند ولی منطق مشابهی دارد به این صورت که بلوکی در #en[set] خارج می شود که نسبت به بقیه اخیرا دسترسی داشته است.

*نحوه بروزرسانی اطلاعات کمکی:*

مشابه #en[LRU] و نکته ای اضافه ای ندارد.

*نحوه ی بروزرسانی اطلاعات پس از برخورد (#en[hit]):*

دقیقا مثل #en[LRU]، برچسب زمان بلوکی که #en[hit] شده برابر `cycle` می شود و شمارنده زیاد می شود (و باز هم دسترسی های #en[WRITE] نادیده گرفته می شوند). ولی معنای این کار برعکس #en[LRU] است.

*نحوه ی بروزرسانی اطلاعات پس از جایگزینی (#en[fill]):*

بلوک تازه #en[fill] شده بزرگترین برچسب زمان #en[set] را می گیرد، پس بلافاصله پرخطرترین بلوک برای خروج می شود.

*شرایط عملکرد مناسب و نامناسب:*

می شود گفت نقطه ی مقابل #en[LRU] است و هر جا آن بد عمل می کند این خوب عمل می کند و هر جا آن خوب عمل می کند این بد عمل می کند. صرفا اینکه برای ذخیره ی استفاده ی مکرر از داده های جدید خیلی بد عمل می کند.

*نکات کد:*

=== قطعه ۱ — تنها تفاوت با #en[LRU]

```cpp
long mru::find_victim(uint32_t triggering_cpu, uint64_t instr_id, long set, ...)
{
  auto begin = std::next(std::begin(last_used_cycles), set * NUM_WAY);
  auto end = std::next(begin, NUM_WAY);

  auto victim = std::max_element(begin, end); //MRU!!!
  return std::distance(begin, victim);
}
```

کل تفاوت پیاده سازی با #en[LRU] استفاده از `max_element` به جای `min_element` است، به همین دلیل بلوکی که اخیرا به #en[set] اضافه شده است قربانی است. بقیه ی کد ها با #en[LRU] کاملا یکسان هستند.

== #en[Random]

*منطق انتخاب بلوک قربانی:*

در هر #en[set] به صورت رندوم یک بلوک را انتخاب می کنیم.

*نحوه بروزرسانی اطلاعات کمکی:*

اطلاعات اضافه ای برای ذخیره لازم نداریم.

*نحوه ی بروزرسانی اطلاعات پس از برخورد (#en[hit]):*

هیچ چیزی بروزرسانی نمی شود و اصلا تابع `update_replacement_state` را #en[override] نکرده ایم، چون هیچ حالتی برای نگه داشتن وجود ندارد. تنها چیزی که با هر انتخاب قربانی تغییر می کند وضعیت داخلی #en[generator] شبه تصادفی است.

*نحوه ی بروزرسانی اطلاعات پس از جایگزینی (#en[fill]):*

اینجا هم هیچ کاری انجام نمی شود و `replacement_cache_fill` خالی است.

*شرایط عملکرد مناسب و نامناسب:*

سیاست #en[Random] وقتی نسبتا خوب عمل می کند که پترن دسترسی برنامه بدون منطق مشخص و رندوم باشد. صرفا یک روش نامنظم در برابر نامنظم است که لزوما بهترین نتیجه را نمی دهد و یک روش ساده ی نسبتا معمولی است.

در برنامه هایی که پترن مشخص مثل #en[scan] خطی و استفاده ی مکرر از داده ها دارند اصلا خوب عمل نمی کند چون یک رفتار نامنظم در برابر یک رفتار منظم است.

*نکات کد:*

=== قطعه ۱ — مولد شبه تصادفی و بازه ی انتخاب

```cpp
struct random : public champsim::modules::replacement {
  std::mt19937_64 rng{};
  std::uniform_int_distribution<long> dist;
  ...
};

random::random(CACHE* cache) : random(cache, cache->NUM_WAY) {}

random::random(CACHE* cache, long ways) : replacement(cache), dist(0, ways - 1) {}
```

رندوم روی بازه ی `[0, ways-1]` یک عدد انتخاب می کنیم که بیانگر آن بلوکی است که باید حذف شود.

=== قطعه ۲ — انتخاب قربانی و نبود توابع دیگر

```cpp
long random::find_victim(uint32_t triggering_cpu, uint64_t instr_id, long set, ...)
{
  return dist(rng);
}
```

در سیاست #en[random] کل خطی که منطق این سیاست را پیاده سازی می کند همین است و توابع دیگر نیاز به #en[override] کردن ندارند چون این سیاست منطق هندل کردن حالت ندارد.

== #en[SRRIP]

به ازای هر بلوک در #en[set] یک عدد به نام #en[RRPV] (#en[Re-Reference Prediction Value]) ذخیره می شود که معمولا ۲ بیت است که ۴ مقدار می تواند به خود بگیرد. در صورتی که ۰ باشد یعنی اینکه احتمالا به زودی استفاده می شود و در صورتی که ۳ باشد احتمالا خیلی در آینده ی دور استفاده می شود و در آینده ی نزدیک احتمالا استفاده نمی شود.

*منطق انتخاب بلوک قربانی:*

در روش #en[SRRIP] (#en[Static Re-Reference Interval Prediction]) کل منطق بر این است که در یک #en[set] بلوک هایی که خیلی استفاده می شوند پایدار می شوند و در صورتی که استفاده ی یک بلوک کم شود احتمالا بلوک قربانی خواهد بود. برای پیدا کردن بلوک قربانی هم بلوکی که #en[RRPV] برابر ۳ (بیشترین مقدار) را دارد خارج می شود. و در صورتی که هیچ بلوکی مقدار ۳ نداشت، مقدار #en[RRPV] تمام بلوک ها را زیاد می کنیم تا یکی به ۳ برسد، و این فرایند تا شرط برقرار شود ادامه پیدا می کند. (بخشی از بروزرسانی هم انجام می دهد)

*نحوه بروزرسانی اطلاعات کمکی:*

در صورتی که بلوک جدید اضافه شود، یک بلوک با #en[RRPV] تقریبا میانه مثل `MAX_RRPV-1` اضافه می کند. در هنگام #en[hit] مقدار #en[RRPV] آن بلوک به ۰ ریست می شود. مقدار بروزرسانی هنگام خارج شدن یک بلوک هم داریم که بالا توضیح دادیم.

*نحوه ی بروزرسانی اطلاعات پس از برخورد (#en[hit]):*

مقدار #en[RRPV] بلوکی که #en[hit] شده به ۰ ریست می شود، یعنی پیش بینی می کنیم که خیلی زود دوباره استفاده می شود و آن را به امن ترین حالت می بریم.

*نحوه ی بروزرسانی اطلاعات پس از جایگزینی (#en[fill]):*

ابتدا در خود `find_victim` و قبل از #en[fill] کردن، اگر بیشترین #en[RRPV] موجود در #en[set] کمتر از `maxRRPV` باشد به همه ی بلوک های آن #en[set] به اندازه ی `diff = maxRRPV - max` اضافه می شود تا قربانی مشخص شود. بعد از آن برای بلوک تازه اضافه شده مقدار `maxRRPV - 1` می دهیم.

*شرایط عملکرد مناسب و نامناسب:*

صرفا یک #en[LRU] پیشرفته تر است، پس یکم هوشمندانه تر از #en[LRU] عمل می کند و حالت های خوب آن مثل #en[scan] های خطی و ... است. که چون کمی هوشمندانه تر عمل می کند از #en[LRU] هم بهتر عمل می کند.

حالت های بد آن تقریبا مشابه #en[LRU] وقتی است که در اسکن حلقه ای #en[cache] پر شود و قبل از اینکه به سر حلقه برسیم داده های اولیه دور ریخته شوند و مجدد از اول باید دریافت شوند که همه چیز هدر می رود.

*نکات کد:*

=== قطعه ۱ — #en[helper] هر #en[set] و مقداردهی اولیه

```cpp
struct srrip_set_helper {
  using rrpv_type = int;
  static constexpr rrpv_type maxRRPV = 3;

  std::vector<rrpv_type> rrpv_values;
  rrpv_type& get_rrpv(long way);

  long victim();
  void update(long way, bool hit);
};

srrip_set_helper::srrip_set_helper(long ways)
    : rrpv_values(static_cast<std::size_t>(ways), maxRRPV) {}

srrip::srrip(CACHE* cache, long sets_, long ways_) : replacement(cache)
{
  std::generate_n(std::back_inserter(sets), sets_,
                  [ways = ways_] { return srrip_set_helper{ways}; });
}
```

برای داده های کمکی یک شی `srrip_set_helper` تعریف می کنیم که داده های مورد نیاز را به صورت گروهی نگه دارد.

مقدار اولیه ی همه ی #en[way] ها `maxRRPV` است، یعنی کش خالی طوری رفتار می کند که انگار همه ی بلوک ها در مرز خروج هستند. با این حرکت #en[way] های خالی بدون هیچ بررسی اضافه ای اول از همه انتخاب می شوند.

در اینجا ما `maxRRPV` را مساوی ۳ قرار دادیم که بیانگر همان ۲ بیت برای این داده است.

=== قطعه ۲ — انتخاب قربانی و افزایش گروهی

```cpp
long srrip_set_helper::victim()
{
  // Find the maximum RRPV
  auto victim = std::max_element(std::begin(rrpv_values), std::end(rrpv_values));

  // If the maximum element has RRPV less than the maximum, increment everything to the maximum
  std::transform(std::cbegin(rrpv_values), std::cend(rrpv_values), std::begin(rrpv_values),
                 [diff = maxRRPV - *victim](auto x) { return x + diff; });

  // Return the way index
  return std::distance(std::begin(rrpv_values), victim);
}
```

همان توصیف حلقه شکلی که در توضیح سیاست داشتیم اینجا به صورت یک عبارت جبری ساده به صورت `diff = maxRRPV - max` است که به همه اضافه می شود. عملا همان کار حلقه را می کند و این دو روش هم ارزند ولی این بار محاسباتی کمتری دارد.

اگر از قبل بلوکی با مقدار بیشینه وجود داشته باشد، `diff` برابر صفر می شود و `transform` عملا هیچ تغییری نمی دهد. یعنی همان حالت عادی که مستقیما قربانی پیدا می شود.

نکته ی دیگر این است که این افزایش فقط در مسیر #en[miss] اتفاق می افتد.

=== قطعه ۳ — به روزرسانی مشترک برای #en[hit] و #en[fill]

```cpp
void srrip_set_helper::update(long way, bool hit) { get_rrpv(way) = hit ? 0 : (maxRRPV - 1); }

void srrip::update_replacement_state(..., uint8_t hit)
{
  sets.at(static_cast<std::size_t>(set)).update(way, hit);
}
```

کد `replacement_cache_fill` بازنویسی نشده است و هر دو حالت #en[hit] و #en[fill] از همین یک تابع استفاده می کنند که برای اینکه بین #en[hit] و #en[fill] تشخیص دهیم یک `bool hit` داریم که بین این دو انتخاب کند.

در صورتی که #en[hit] بشود مقدار به ۰ ریست می شود و در صورتی که #en[fill] باشد مقدار جدید برابر `maxRRPV-1` خواهد بود.

== #en[BIP]

*منطق انتخاب بلوک قربانی:*

روش #en[BIP] (#en[Bimodal Insertion Policy]) عملا روی روش #en[LRU] سوار شده است که منطق خارج کردن بلوک از #en[set] آن دقیقا مشابه #en[LRU] است. صرفا نحوه ی هندل کردن ترتیب بلوک ها بر اساس دسترسی اخیر آنها کمی متفاوت است.

*نحوه بروزرسانی اطلاعات کمکی:*

در روش #en[LRU] در هنگامی که بلوک جدید اضافه می شود، نسبت به بقیه در ترتیب دسترسی بالاتر بود. ولی در این روش هنگامی که بلوک جدید اضافه می شود با یک احتمال مشخص زیادی در ترتیب دسترسی پایینترین خواهد بود (#en[Least Recently Used]) که یعنی در خطر خارج شدن است (بر خلاف روش عادی که بلوکی که جدید اضافه می شد کم خطر ترین برای خارج شدن بود) و با یک احتمال متمم مشخص دیگری در ترتیب دسترسی نسبت به بقیه بالاترین خواهد بود (مثل حالت عادی روش #en[LRU]).

*نحوه ی بروزرسانی اطلاعات پس از برخورد (#en[hit]):*

در هنگام #en[hit] دقیقا مثل #en[LRU] عمل می کنیم و برچسب زمان بلوک برابر `cycle` می شود و شمارنده زیاد می شود (باز هم به جز دسترسی های #en[WRITE]).

*نحوه ی بروزرسانی اطلاعات پس از جایگزینی (#en[fill]):*

بعد از #en[fill] کردن، با احتمال ۱/۳۲ برچسب زمان برابر `cycle` می شود (درج در موقعیت #en[MRU]، مثل #en[LRU]) و با احتمال ۳۱/۳۲ برچسب برابر ۰ قرار می گیرد که یعنی درج در موقعیت #en[LRU]. پس به احتمال زیاد بلوک جدید در اولین #en[miss] بعدی همان #en[set] دوباره خارج می شود و محتوای قدیمی #en[set] تقریبا دست نخورده باقی می ماند. آن احتمال کوچک ۱/۳۲ هم برای این است که اگر #en[working set] برنامه عوض شد، کش بتواند به تدریج محتوای جدید را بپذیرد و برای همیشه روی داده های قدیمی قفل نشود.

*شرایط عملکرد مناسب و نامناسب:*

در این روش هم مشکل #en[scan] های حلقه ای که از سایز #en[cache] بزرگ تر می شوند تا حدی رفع می شود و هم اسکن های خطی که داده های بدردنخور اضافه می شود و فقط یکبار استفاده می شوند، چون یک روش میانی بین #en[LRU] و #en[MRU] است این امکان به وجود می آید. چون با یک احتمال کم بعضی داده ها را نگه می دارد و خیلی ها را دور می اندازد، باعث نمی شود که همه چیز یادمان برود و خیلی چیز ها نگه داشته می شوند؛ در اسکن های خطی هم داده های یکبار مصرف اکثرا دور ریخته می شوند و فقط بخش کمی از آنها نگه داشته می شود.

در جایی بد عمل می کند که کل #en[working set] داخل #en[cache] جا شود و صرفا بخاطر بدبینی این سیاست خیلی از داده ها بیرون ریخته شوند.

*نکات کد:*

=== قطعه ۱ — مولد تصادفی و پارامتر $epsilon$

```cpp
class bip : public champsim::modules::replacement
{
    long NUM_WAY;
    std::vector<uint64_t> last_used_cycles;
    uint64_t cycle = 0;
    std::mt19937 rng;
    std::uniform_int_distribution<int> dist;
    ...
};

bip::bip(CACHE* cache, long sets, long ways)
    : replacement(cache),
      NUM_WAY(ways),
      last_used_cycles((std::size_t)(sets * ways), 0),
      rng(0),
      dist(0, 31)        // 1/32 probability
{
}
```

طبق توزیع `dist(0, 31)` و شرطی که در قطعه ی سوم می آید (`== 0`) یعنی احتمال درج در موقعیت #en[MRU] دقیقا ۱/۳۲ و احتمال درج در موقعیت #en[LRU] برابر ۳۱/۳۲ است. (این همان احتمال هایی است که در توضیح این #en[policy] شرح دادیم) این مقدار به صورت رسمی $epsilon$ نام دارد و انتخاب آن دلخواه نیست و باید هوشمندانه باشد، ولی مقدار معمولی آن همین است. باید آنقدر کوچک باشد که برای جست و جوی خطی حافظه باعث #en[cache pollution] نشود (داده های الکی و اضافه پر نکند) و آنقدر بزرگ باشد که اگر #en[working set] برنامه عوض شد، #en[cache] بتواند محتوای جدید را کم کم بپذیرد.

برای #en[seed] برای رندوم هم `rng(0)` صفر را می دهیم.

بقیه ی ساختار داده دقیقا همان #en[LRU] است.

=== قطعه ۲ — انتخاب قربانی (کاملا مثل #en[LRU])

```cpp
long bip::find_victim(uint32_t, uint64_t, long set, ...)
{
    auto begin = std::next(last_used_cycles.begin(), set * NUM_WAY);
    auto end = std::next(begin, NUM_WAY);

    auto victim = std::min_element(begin, end);
    return std::distance(begin, victim);
}
```

کاملا مشابه #en[LRU] برای قربانی عمل می کنیم و منطق پیشرفته تری ندارد.

=== قطعه ۳ — درج دو حالته

```cpp
void bip::replacement_cache_fill(uint32_t, long set, long way, ...)
{
    auto idx = (std::size_t)(set * NUM_WAY + way);

    // 1/32 insert at MRU
    if (dist(rng) == 0)
    {
        last_used_cycles[idx] = cycle++;
    }
    else
    {
        // Insert as LRU
        last_used_cycles[idx] = 0;
    }
}

void bip::update_replacement_state(..., uint8_t hit)
{
    if (hit && type != access_type::WRITE)
    {
        last_used_cycles[(std::size_t)(set * NUM_WAY + way)] = cycle++;
    }
}
```

فقط منطق #en[fill] طبق توضیحی که دادیم فرق می کرد و بقیه کاملا مشابهند.

== #en[DRRIP]

*منطق انتخاب بلوک قربانی:*

در روش #en[DRRIP] (#en[Dynamic RRIP]) منطق خارج کردن بلوک دقیقا مشابه روش #en[SRRIP] است و تفاوتی ندارد.

*نحوه بروزرسانی اطلاعات کمکی:*

این روش هم چون یک روش تکمیلی روی #en[SRRIP] است تقریبا مشابه عمل می کند به جز قراردادی که در هنگام اضافه کردن بلوک به #en[set] دارد. به این صورت عمل می کند که دو تا #en[sub-policy] دارد که بین این دوتا به صورت پویا عوض می کند. #en[sub-policy] اول به این صورت است که برای بلوک جدیدی که اضافه می شود مثل #en[SRRIP] برای مقدار #en[RRPV] آن `MAX_RRPV-1` را قرار دهیم. و #en[sub-policy] دیگر این است که مثل #en[BIP]، با احتمال خیلی زیاد (ممکن است پیاده سازی این مورد به صورت احتمالی نباشد، مثلا در پیاده سازی ما اینطور نیست) مقدار #en[RRPV] آن را `MAX_RRPV` قرار دهیم (مرز خروجی)، و با احتمال خیلی کمتر `MAX_RRPV-1` را قرار دهیم. در این روش اینکه کدام یک از این #en[sub-policy] ها انتخاب می شود با استفاده از روش #en[set-dueling] انجام می شود. به این صورت که ما ۳ نوع دسته داریم: #en[brrip_leader] و #en[srrip_leader] و #en[follower]. برای دسته های #en[srrip_leader] و #en[brrip_leader] به صورت ثابت به ترتیب از #en[sub-policy] های #en[SRRIP] و #en[BRRIP] استفاده می کنیم ولی برای دسته آخر که #en[follower] است با توجه به یک شمارنده #en[PSEL] انجام می شود.

هنگام #en[hit] هم فارغ از اینکه #en[sub-policy] کدام باشد مقدار #en[RRPV] به ۰ تنظیم می شود.

#diagram(
  caption: [سازوکار #en[set-dueling] و نقش شمارنده ی #en[PSEL] در #en[DRRIP]],
  {
    import cetz.draw: *

    let cell(x0, y0, x1, y1, name, body, fill) = {
      rect((x0, y0), (x1, y1), name: name, fill: fill, stroke: 0.6pt + rule-color, radius: 2pt)
      content(((x0 + x1) / 2, (y0 + y1) / 2), align(center, body))
    }

    cell(0, 4.5, 7.2, 5.9, "srrip", [SRRIP leader sets \ insert RRPV = maxRRPV - 1], accent.transparentize(82%))
    cell(0, 2.5, 7.2, 4.1, "brrip", [BRRIP leader sets \ insert RRPV = maxRRPV \ (every 32nd fill: maxRRPV - 1)], accent.transparentize(82%))
    cell(0, 0.3, 7.2, 1.7, "foll", [follower sets \ follow the winning sub-policy], surface)
    cell(9.0, 2.6, 13.4, 4.6, "psel", [PSEL \ 10-bit saturating \ counter (per core)], surface)

    line("srrip.east", "psel.west", mark: (end: ">"), stroke: 0.6pt + accent)
    line("brrip.east", "psel.west", mark: (end: ">"), stroke: 0.6pt + accent)
    line("psel.south", "foll.east", mark: (end: ">"), stroke: 0.6pt + accent)

    content((11.2, 5.4), align(center)[every miss in a leader set \ trains PSEL (update_bad)])
    content((8.9, 2.2), align(center)[decide(set)])
  },
)

*نحوه ی بروزرسانی اطلاعات پس از برخورد (#en[hit]):*

مستقل از اینکه #en[set] از نوع #en[leader] است یا #en[follower] و مستقل از اینکه کدام #en[sub-policy] فعال است، مقدار #en[RRPV] بلوکی که #en[hit] شده به ۰ ریست می شود. برای دسترسی های #en[WRITE] به جای ۰ مقدار `maxRRPV - 1` گذاشته می شود تا #en[writeback] باعث نشود بلوکی الکی امن به حساب بیاید. نکته ی مهم دیگر این است که در مسیر #en[hit] شمارنده ی #en[PSEL] دست نمی خورد و آموزش #en[PSEL] فقط از روی #en[miss] ها انجام می شود.

*نحوه ی بروزرسانی اطلاعات پس از جایگزینی (#en[fill]):*

اول مثل #en[SRRIP]، در `find_victim` مقدار #en[RRPV] همه ی بلوک های #en[set] به اندازه ی لازم زیاد می شود تا قربانی با مقدار بیشینه پیدا شود. بعد از درج بلوک جدید، تابع `decide(set)` مشخص می کند کدام #en[sub-policy] اجرا شود: #en[set] های #en[leader] همیشه سیاست ثابت خودشان (#en[SRRIP] یا #en[BRRIP]) و #en[set] های #en[follower] بر اساس مقدار فعلی #en[PSEL]. در حالت #en[SRRIP] مقدار `maxRRPV - 1` و در حالت #en[BRRIP] مقدار `maxRRPV` داده می شود، به جز یک بار در هر ۳۲ درج که به صورت چرخشی مقدار `maxRRPV - 1` می گیرد.

سپس برای خود #en[PSEL] داریم: در پایان هر #en[fill] تابع `update_bad(set)` صدا زده می شود. چون #en[fill] فقط بعد از #en[miss] اتفاق می افتد، هر #en[miss] در یک #en[set] رهبر شمارنده را به ضرر سیاست همان رهبر حرکت می دهد و بعد از مدتی #en[PSEL] به سمت سیاستی می رود که در #en[set] های نمونه #en[miss] کمتری داشته است. این تنها بخش واقعا پویای این روش است (شمارنده ی #en[PSEL] از روی #en[set] های #en[leader] یاد می گیرد و مثل دیکتاتور به #en[set] های #en[follower] غالب می کند).

*شرایط عملکرد مناسب و نامناسب:*

سیاست #en[DRRIP] تقریبا در همه ی شرایط خوب عمل می کند چون به صورت پویا بین دو روش جابه جا می شود. صرفا در جاهایی ممکن است بد عمل کند که #en[working set] اینقدر کم باشد که روش فرصت یادگیری نداشته باشد و #en[overkill] باشد.

*نکات کد:*

=== قطعه ۱ — ثابت ها و شمارنده ی #en[PSEL]

```cpp
struct drrip : public champsim::modules::replacement {
  static constexpr unsigned maxRRPV = 3;
  static constexpr unsigned BRRIP_MAX = 32;
  static constexpr unsigned PSEL_WIDTH = 10;

  enum class set_type { follower, brrip_leader, srrip_leader };

  unsigned brrip_counter;

  std::vector<unsigned> rrpv;
  std::vector<champsim::msl::dscounter<long, PSEL_WIDTH>> PSEL;
};

drrip::drrip(CACHE* cache)
    : replacement(cache), NUM_SET(cache->NUM_SET), NUM_WAY(cache->NUM_WAY),
      rrpv(static_cast<std::size_t>(NUM_SET * NUM_WAY)),
      PSEL(NUM_CPUS, champsim::msl::dscounter<long, PSEL_WIDTH>(champsim::msl::get_sample_rate(NUM_SET)))
{
}
```

یک شمارنده ی #en[PSEL] با طول ۱۰ بیت به ازای هر هسته داریم. ۳ دسته برای #en[set] ها طبق توضیحی که دادیم داریم. و بقیه ی المان های #en[SRRIP] و المان های مشابه #en[BIP] را نیز مشاهده می کنیم.

=== قطعه ۲ — دو #en[sub-policy] درج

```cpp
void drrip::update_brrip(long set, long way)
{
  get_rrpv(set, way) = maxRRPV;

  brrip_counter++;
  if (brrip_counter == BRRIP_MAX) {
    brrip_counter = 0;
    get_rrpv(set, way) = maxRRPV - 1;
  }
}

void drrip::update_srrip(long set, long way) { get_rrpv(set, way) = maxRRPV - 1; }
```

در حالت #en[BRRIP] بلوک جدید در ۳۱ حالت از هر ۳۲ حالت با مقدار `maxRRPV` اضافه می شود (اینجا یک تفاوت ریز با #en[BIP] دارد و آن این است که در #en[BIP] این موضوع رندوم بود ولی اینجا به صورت چرخشی و سیکلی است و رندوم نیست، تاثیر عملکردی آن شاید ناچیز باشد و تقریبا یکسان باشند ولی از لحاظ سخت افزاری خیلی ساده تر از رندوم است)، یعنی در مرز خروج قرار می گیرد و اگر تا اولین جست وجوی قربانی استفاده نشود بیرون می رود. فقط یک بار در هر ۳۲ درج، مقدار `maxRRPV - 1` داده می شود تا #en[cache] بتواند به تدریج محتوای جدید را نگه دارد.

تابع `update_srrip` دقیقا همان درج #en[SRRIP] است و هیچ تفاوتی با آن ندارد.

=== قطعه ۳ — انتخاب #en[sub-policy] در زمان درج

```cpp
void drrip::replacement_cache_fill(uint32_t triggering_cpu, long set, long way, ...)
{
  // do not update replacement state for writebacks
  if (access_type{type} == access_type::WRITE) {
    get_rrpv(set, way) = maxRRPV - 1;
    return;
  }
  if (PSEL[triggering_cpu].decide(set)) {
    update_brrip(set, way);
  } else {
    update_srrip(set, way);
  }
  // cache miss, update bad
  PSEL[triggering_cpu].update_bad(set);
}
```

تابع `decide(set)` برای #en[set] های #en[leader] همیشه سیاست فیکس شده ی خودشان را برمی گرداند و برای #en[set] های #en[follower] بر اساس مقدار فعلی #en[PSEL] تصمیم می گیرد.

تابع `update_bad(set)` در هر #en[fill] صدا زده می شود و چون #en[fill] فقط بعد از #en[miss] اتفاق می افتد، عملا هر #en[miss] در یک #en[set] رهبر، #en[PSEL] را به ضرر سیاست همان رهبر تغییر می دهد. در نتیجه بعد از مدتی #en[PSEL] به سمت سیاستی می رود که در #en[set] های نمونه #en[miss] کمتری داده است. این همان بخش پویای این روش است. اینکه خود تابع `update_bad` چطوری پیاده سازی شده است در فایل های داخلی #en[ChampSim] است و خیلی جزیی می شود.

=== قطعه ۴ — #en[hit] و انتخاب قربانی

```cpp
void drrip::update_replacement_state(..., uint8_t hit)
{
  if (hit) {
    if (access_type{type} == access_type::WRITE) {
      get_rrpv(set, way) = maxRRPV - 1;
      return;
    }
    get_rrpv(set, way) = 0; // DRRIP always promotes a cache line to the MRU position
  }
}

long drrip::find_victim(uint32_t triggering_cpu, uint64_t instr_id, long set, ...)
{
  auto begin = std::next(std::begin(rrpv), set * NUM_WAY);
  auto end = std::next(begin, NUM_WAY);

  auto victim = std::max_element(begin, end);
  if (auto rrpv_update = maxRRPV - *victim; rrpv_update != 0)
    for (auto it = begin; it != end; ++it)
      *it += rrpv_update;

  return std::distance(begin, victim);
}
```

تابع `find_victim` از نظر منطقی دقیقا همان #en[SRRIP] است و فقط به جای `std::transform` از یک حلقه استفاده کرده است.

در زمان برخورد، بدون توجه به اینکه کدام #en[sub-policy] فعال است، مقدار #en[RRPV] به ۰ می رسد.

== #en[SHiP]

*منطق انتخاب بلوک قربانی:*

در روش #en[SHiP] (#en[Signature-based Hit Predictor])، کاملا مشابه روش #en[SRRIP] مقادیر #en[RRPV] به ازای هر بلوک داریم که دقیقا به همان روش #en[SRRIP] بلوک هدف را خارج می کنیم.

*نحوه بروزرسانی اطلاعات کمکی:*

در این #en[policy] ما روی مقدار اولیه #en[RRPV] که به ازای هر بلوک نسبت می دهیم خلاقیت به خرج می دهیم و سعی می کنیم مقدار هوشمندانه ای برای آن تعیین کنیم. به این صورت که در کنار #en[RRPV] یک تگ به اسم #en[signature] هم به هر بلوک هنگام اضافه شدن به #en[set] به آن می دهیم که بر اساس ناحیه ی حافظه ای است که در آن قرار داشته است یا آدرس حافظه مربوط به آن است (#en[PC]) (کلا قرارداد مخصوص به خود دارد، مثلا در کد ما همان #en[PC] است). یک جدول به اسم #en[SHCT] (#en[Signature History Counter Table]) نگه می داریم که به ازای هر #en[signature] یک شمارنده دارد که در هر بار دسترسی به بلوک با ان #en[signature] خاص شمارنده مربوط به #en[signature] در جدول کم می شود. عملا مقدار به ازای هر #en[signature] در این جدول بیان می کند که این پترن خاص از حافظه چقدر امکان مجدد بازخواست و دسترسی دارند. هنگام اضافه کردن بلوک به #en[set] از این جدول #en[lookup] انجام می دهیم و مقدار مربوط به #en[signature] این بلوک را می خوانیم، بر اساس این مقدار #en[RRPV] را مقداردهی می کنیم. در صورتی که این مقدار کم باشد و یعنی احتمال بازخواست این #en[signature] زیاد باشد مقدار #en[RRPV] آن را یک چیز کم مثل ۰ یا ۱ می دهیم (البته اینکه در حالت خوب یک مقدار #en[RRPV] به آن داده شود در کد نیست و در اولین پیاده سازی های این ایده هم ظاهرا نبوده و در مقالات و ورژن های بعدی که بهبود یافته است ظاهر می شود). و اگر مقدار جدول زیاد باشد و یعنی این #en[signature] احتمالا زیاد بازخواست نمی شود مقدار #en[RRPV] بالایی مثل `MAX_RRPV` به آن نسبت می دهیم.

در هنگام #en[hit] مقدار #en[RRPV] بلوک به ۰ ریست می شود و ورودی داخل جدول #en[SHCT] که مربوط به #en[signature] این بلوک است یکی کم می شود.

در هنگامی که بلوک بدون اینکه یکبار هم #en[hit] شده باشد در جدول مقدار مربوط به #en[signature] آن یکی زیاد می شود.

نکته ی بسیار مهم این است که این جدول اگر برای تمام #en[set] های موجود ذخیره شود سخت افزار خیلی بزرگی می خواهد، پس به جای اینکار ما این را برای تعداد محدودی #en[set] انجام می دهیم و به بقیه #en[set] ها تعمیم می دهیم. به این #en[sampler] می گوییم که چیزی شبیه شبکه عصبی که با یک سری #en[set] ها #en[train] می شود و روی بقیه تست می شود. به این شکل سخت افزار کمتری مصرف می شود. در جاهای مختلف کد این موضوع تکرار شده ولی چون از توضیحی که دادیم خارج نیست، فرض می کنیم کلا #en[sampler] را ندید می گیریم و کلی توضیح می دهیم، پس داخل کد و توضیحات بیشتر جاها منظورمان خود #en[sampler] است که در یادگیری استفاده می شود ولی برای ساده سازی به خود جدول اشاره کردیم.

#diagram(
  caption: [مسیر پیش بینی و مسیر آموزش جدول #en[SHCT] در #en[SHiP]],
  length: 0.82cm,
  {
    import cetz.draw: *

    let cell(x0, y0, x1, y1, name, body, fill) = {
      rect((x0, y0), (x1, y1), name: name, fill: fill, stroke: 0.6pt + rule-color, radius: 2pt)
      content(((x0 + x1) / 2, (y0 + y1) / 2), align(center, body))
    }

    cell(0, 4.2, 3.0, 5.6, "pc", [access PC \ (ip)], surface)
    cell(4.0, 4.2, 9.0, 5.6, "sig", [signature \ PC[31:0] % SHCT_PRIME], surface)
    cell(10.0, 3.9, 14.0, 5.9, "shct", [SHCT \ 16384 entries \ 3-bit counters], accent.transparentize(82%))
    cell(15.0, 5.0, 20.6, 6.2, "bad", [is_max (= 7): \ RRPV = maxRRPV], surface)
    cell(15.0, 3.4, 20.6, 4.6, "good", [otherwise: \ RRPV = maxRRPV - 1], surface)
    cell(9.2, 0.4, 14.8, 1.8, "samp", [sampler sets \ (own LRU + used bit)], surface)

    line("pc.east", "sig.west", mark: (end: ">"), stroke: 0.6pt + accent)
    line("sig.east", "shct.west", mark: (end: ">"), stroke: 0.6pt + accent)
    line("shct.east", "bad.west", mark: (end: ">"), stroke: 0.6pt + accent)
    line("shct.east", "good.west", mark: (end: ">"), stroke: 0.6pt + accent)
    line("samp.north", "shct.south", mark: (end: ">"), stroke: 0.6pt + accent)

    content((17.8, 2.4), align(center)[insertion RRPV \ of the new block])
    content((11.7, 2.85), align(right)[hit: counter - 1 \ unused evict: counter + 1], anchor: "east")
    content((8.8, 1.1), align(right)[only sampled sets \ train the table], anchor: "east")
    line((9.0, 1.1), "samp.west", mark: (end: ">"), stroke: (paint: muted, dash: "dashed", thickness: 0.6pt))
  },
)

*نحوه ی بروزرسانی اطلاعات پس از برخورد (#en[hit]):*

ابتدا در کش اصلی مقدار #en[RRPV] آن بلوک مثل #en[SRRIP] به ۰ ریست می شود و سپس برای #en[train] اگر #en[set] مورد نظر جزو #en[set] های #en[sampler] باشد، خانه ی متناظر در جدول #en[SHCT] پیدا می شود و مقدار آن یکی کم می شود، چون این #en[hit] ثابت می کند که آن #en[signature] (یعنی همان #en[PC]) داده ای می آورد که واقعا دوباره استفاده می شود. همچنین بیت `used` آن خانه ی #en[sampler] برابر `true` می شود تا بعدا موقع خروج، این بلوک به عنوان «بدرد نخور» جریمه نشود. اگر #en[set] جزو نمونه ها نباشد هیچ #en[train] ای انجام نمی شود و فقط #en[RRPV] ریست می شود.

*نحوه ی بروزرسانی اطلاعات پس از جایگزینی (#en[fill]):*

ابتدا #en[signature] بلوک جدید از ۳۲ بیت پایین #en[PC] ساخته و با `% SHCT_PRIME` روی جدول مپ می شود و مقدار آن خانه خوانده می شود. اگر شمارنده به بیشینه رسیده باشد (`is_max`، یعنی مقدار ۷) بلوک با `maxRRPV` درج می شود که یعنی همان لحظه در مرز خروج است، وگرنه مقدار پیشفرض `maxRRPV - 1` مثل #en[SRRIP] را می گیرد. برای دسترسی های #en[WRITE] هم بدون هیچ #en[lookup] ای همان مقدار امن `maxRRPV - 1` گذاشته می شود.

سپس برای #en[train] وقتی در یک #en[set] نمونه یک خانه ی #en[sampler] بازنویسی می شود، اگر آن خانه بیت `used` نداشته باشد یعنی بلوک قبلی بدون حتی یک بار استفاده خارج شده است، پس شمارنده ی مربوط به #en[signature] آن یکی زیاد می شود. بعد خانه با آدرس و #en[PC] جدید مقداردهی و `used` دوباره صفر می شود. توجه کنیم که #en[sampler] برای خودش یک سیاست #en[LRU] مستقل با `last_used` دارد که هیچ ربطی به #en[RRPV] های کش اصلی ندارد.

*شرایط عملکرد مناسب و نامناسب:*

سیاست #en[SHiP] وقتی بهترین عملکرد را دارد که پترن استفاده ی برنامه از یک سری خانه های حافظه مشخص و الگودار باشد؛ #en[SHiP] می تواند این الگو ها را تشخیص بدهد و از آنها استفاده بکند (عملا استفاده های مجدد از یک سری از خانه های حافظه معنی دار و الگو دار باشند).

چون #en[SHiP] به مرور یاد می گیرد و جدول #en[SHCT] را باید پر کند، فرآیند یادگیری آن کمی طول می کشد و به همین دلیل در اوایل شاید خوب عمل نکند. همچنین وقتی که پترن و جنس الگوی دسترسی برنامه عوض می شود، چون جدول هنوز روی پترن قبلی یاد گرفته، اوایل خوب عمل نمی کند و بندری می زند.

*نکات کد:*

=== قطعه ۱ — ساختار #en[sampler] و جدول #en[SHCT]

```cpp
struct ship : public champsim::modules::replacement {
  static constexpr int maxRRPV = 3;
  static constexpr std::size_t SHCT_SIZE = 16384;
  static constexpr unsigned SHCT_PRIME = 16381;
  static constexpr unsigned SHCT_MAX = 7;

  class SAMPLER_class
  {
  public:
    bool valid = false;
    bool used = false;
    champsim::address address{};
    champsim::address ip{};
    uint64_t last_used = 0;
  };

  std::vector<SAMPLER_class> sampler;
  std::vector<int> rrpv_values;
  champsim::msl::categorizer<long> set_categorizer;
  champsim::data::bits sampler_tag_bits;

  std::vector<std::array<champsim::msl::fwcounter<champsim::msl::lg2(SHCT_MAX + 1)>, SHCT_SIZE>> SHCT;
};
```

ساختار داده #en[SHCT] یک جدول با ۱۶۳۸۴ خانه است که هر خانه ی آن یک شمارنده ۳ بیتی است (چون `SHCT_MAX = 7` است).

هر خانه ی #en[sampler] یک بیت `used` دارد که می گوید آیا آن بلوک بعد از درج حداقل یک بار استفاده شد یا نه.

=== قطعه ۲ — آموزش جدول از روی #en[sampler]

```cpp
void ship::update_replacement_state(..., uint8_t hit)
{
  // update sampler
  if (set_categorizer.get_sample_category(set) == 0) {
    auto s_idx = set / champsim::msl::get_sample_rate(NUM_SET);
    auto s_set_begin = std::next(std::begin(sampler), s_idx * NUM_WAY + ...);
    auto s_set_end = std::next(s_set_begin, NUM_WAY);

    // check hit
    auto match = std::find_if(s_set_begin, s_set_end, [addr = full_addr, shamt = sampler_tag_bits](auto x) {
      return x.valid && x.address.slice_upper(shamt) == addr.slice_upper(shamt);
    });
    if (match != s_set_end) {
      auto SHCT_idx = match->ip.slice_lower<32_b>().to<std::size_t>() % SHCT_PRIME;
      SHCT[triggering_cpu][SHCT_idx] -= 1;
      match->used = true;
    } else {
      match = std::min_element(s_set_begin, s_set_end, [](auto x, auto y) { return x.last_used < y.last_used; });

      if (!match->used) {
        auto SHCT_idx = match->ip.slice_lower<32_b>().to<std::size_t>() % SHCT_PRIME;
        SHCT[triggering_cpu][SHCT_idx] += 1;
      }

      match->valid = true;
      match->address = full_addr;
      match->ip = ip;
      match->used = false;
    }

    // update LRU state
    match->last_used = access_count++;
  }

  if (hit)
    get_rrpv(set, way) = 0;
}
```

در صورتی که #en[hit] داشته باشیم از شمارنده مربوط به آن #en[signature] یکی کم می شود و اگر بدون اینکه از بلوک اضافه شده استفاده ی مجدد شود و #en[evict] شود شمارنده را یکی زیاد می کنیم.

بخش #en[signature] همان ۳۲ بیت پایین #en[PC] است که با `% SHCT_PRIME` روی جدول مپ می شود.

بخش #en[sampler] برای خودش یک سیاست #en[LRU] مستقل دارد که با `last_used` و `access_count` پیاده شده و هیچ ربطی به #en[RRPV] های کش اصلی ندارد. یعنی #en[sampler] یک کش مجازی کوچک است که فقط برای آموزش نگه داشته می شود.

در صورت #en[hit] در #en[cache] مقدار #en[RRPV] را به ۰ ریست می کند.

=== قطعه ۳ — استفاده از پیش بینی در زمان درج

```cpp
void ship::replacement_cache_fill(uint32_t triggering_cpu, long set, long way, ...)
{
  // handle writeback access
  if (access_type{type} == access_type::WRITE) {
    get_rrpv(set, way) = maxRRPV - 1;
    return;
  }

  // SHIP prediction
  auto SHCT_idx = ip.slice_lower<32_b>().to<std::size_t>() % SHCT_PRIME;

  get_rrpv(set, way) = maxRRPV - 1;
  if (SHCT[triggering_cpu][SHCT_idx].is_max())
    get_rrpv(set, way) = maxRRPV;
}
```

همان بخش پویا که بر اساس مقدار جدول تصمیم می گیرد که مقدار اولیه #en[RRPV] چه باشد. حالت پیشفرض مثل #en[SRRIP] مقدار `maxRRPV - 1` است و حالت خیلی بد مقدار `maxRRPV` را به خود می گیرد.

شرط `is_max` همان بررسی حالت خیلی بد است که در صورتی که شمارنده پر شده باشد (یعنی مقدار ۷ را به خود گرفته باشد) فعال می شود.

=== قطعه ۴ — انتخاب قربانی

```cpp
long ship::find_victim(uint32_t triggering_cpu, uint64_t instr_id, long set, ...)
{
  auto begin = std::next(std::begin(rrpv_values), set * NUM_WAY);
  auto end = std::next(begin, NUM_WAY);

  auto victim = std::max_element(begin, end);
  if (auto rrpv_update = maxRRPV - *victim; rrpv_update != 0)
    for (auto it = begin; it != end; ++it)
      *it += rrpv_update;

  return std::distance(begin, victim);
}
```

این تابع عینا همان `find_victim` سیاست های #en[SRRIP] و #en[DRRIP] است.

= مقایسه ی سیاست ها روی ردپا ها

برای تعیین عملکرد هر سیاست، از معیار #en[IPC] استفاده شده است. چرا که در نهایت، افزایش سرعت کلی برنامه را دقیق تر از معیار های دیگری نظیر #en[Hit rate] نشان می دهد.

== سوال ۱: عملکرد میانگین هر سیاست

عملکرد میانگین هر سیاست در میان همه ی ردپا ها و همه ی تعداد #en[set] ها به این صورت است:

#figure(
  table(
    columns: (auto, auto, auto),
    align: center + horizon,
    [#en[Strategy]], [#en[Average IPC]], [#en[Average IPC/LRU]],
    en[bip], en[0.3799], en[1.0269],
    en[drrip], en[0.3789], en[1.0244],
    en[fifo], en[0.3685], en[0.9962],
    en[lru], en[0.3699], en[1.0000],
    en[mru], en[0.3630], en[0.9813],
    en[random], en[0.3720], en[1.0057],
    en[ship], en[0.3807], en[1.0292],
    en[srrip], en[0.3769], en[1.0189],
  ),
  caption: [میانگین #en[IPC] هر سیاست روی همه ی ردپا ها و همه ی اندازه های کش],
)

که این مقادیر بسیار به هم نزدیک هستند. دلیل این اتفاق این است که تاثیر کش های لایه های بالاتر و باقی سخت افزار پردازنده بسیار بیشتر از تاثیر صرفا کش لایه ی آخر در سرعت کلی برنامه است. طبق این آمار، سیاست #en[ship] با بیشترین مقدار میانگین #en[IPC]، در میانگین همه ی ردپا ها بهترین عملکرد را داشته است.

== سوال ۲: آیا یک سیاست ثابت در همه ی ردپا ها بهترین است؟

با توجه به نمودار های #en[IPC]، مثلا در ردپای #en[mcf]، سیاست های #en[ship] و #en[srrip] و #en[bip] بهترین عملکرد را دارند. ولی #en[ship] در ردپای #en[gcc] عملکرد بسیار پایینی دارد. همچنین #en[srrip] و #en[bip] در ردپا های #en[lbm] و #en[omnetpp] عملکرد جالبی ندارند. پس می توان نتیجه گرفت هیچ سیاست ثابتی بین آنهایی که بررسی شدند وجود ندارد که در همه ی ردپا ها بهترین باشد.

== سوال ۳: مقایسه ی سیاست های پیشرفته با #en[LRU]

با بررسی نمودار ها، می توان گفت در ردپای #en[gcc]، همه ی سیاست های پیشرفته (#en[ship] و #en[srrip] و #en[drrip] و #en[bip]) بهتر از #en[lru] عمل کرده اند. در مورد ردپای #en[lbm] می توان گفت که عملکرد سیاست های مختلف به شدت به تعداد #en[set] ها وابسته بوده. به طوری که در تعداد کمتر آن (حدود ۱۰۲۴ یا ۲۰۴۸ #en[set]) تفاوت معناداری بین سیاست های پیشرفته ی #en[ship] و #en[srrip] و #en[drrip] با #en[lru] وجود ندارد و صرفا سیاست #en[bip] بوده که بسیار بهتر از آن عمل کرده است. اما در تعداد #en[set] های بیشتر (مثلا ۴۰۹۶)، فقط عملکرد #en[ship] و #en[drrip] به طور قابل ملاحظه ای بیشتر از #en[lru] است. در مورد ردپای #en[mcf]، باز هم همه ی سیاست های پیشرفته از #en[lru] بهتر عمل کرده اند؛ صرفا #en[drrip] در تعداد #en[set] های پایین مقداری کمتر از بقیه عمل می کند. در نهایت در ردپای #en[omnetpp] می توان گفت که هیچ سیاست پیشرفته ای چندان بهتر از #en[lru] عمل نکرده است، مگر در تعداد #en[set] های پایینتر (حدود ۱۰۲۴) که باز هم تفاوت خیلی زیادی ندارند.

== سوال ۴: کجا #en[LRU] و #en[FIFO] کفایت می کنند؟

با توجه به بخش قبلی و نیز نمودار ها می توان نتیجه گرفت که فقط در ردپای #en[omnetpp]، دو سیاست #en[lru] و #en[fifo] کفایت می کنند و عملکرد بسیار خوبی دارند.

== سوال ۵: آیا کاهش #en[Miss Rate] همیشه به افزایش #en[IPC] منجر می شود؟

نه لزوما. اگرچه معمولا کاهش #en[Miss Rate] باعث افزایش #en[IPC] می شود، اما رابطه کاملا خطی نیست. برای مثال #en[SHiP] در بعضی ردپا ها نرخ #en[Miss] کمتری نسبت به #en[LRU] دارد ولی افزایش #en[IPC] آن بسیار اندک است. در بعضی موارد نیز اختلاف زیاد در #en[Miss Rate] تنها به افزایش جزیی #en[IPC] منجر شده است. دلیل آن این است که #en[IPC] علاوه بر کش، به عواملی مانند وابستگی های داده، پیش بینی انشعاب، اجرای موازی دستور ها، و سایر #en[stall] های پردازنده نیز وابسته است. بنابراین کاهش #en[Miss Rate] شرط لازم برای افزایش #en[IPC] است، اما همیشه شرط کافی نیست.

== سوال ۶: رفتار سیاست های تطبیقی

سیاست هایی مانند #en[BIP] و #en[DRRIP] و #en[SHiP] تلاش می کنند رفتار برنامه را هنگام اجرا تشخیص داده و خود را با آن تطبیق دهند. در ردپا هایی مانند #en[mcf] و #en[lbm] این سیاست ها توانسته اند خطوط مفید را مدت بیشتری در کش نگه دارند و از جایگزینی زودهنگام جلوگیری کنند؛ در نتیجه هم نرخ #en[Miss] کاهش یافته و هم #en[IPC] افزایش یافته است.

در #en[omnetpp]، الگوی دسترسی از قبل با رفتار #en[LRU] سازگار بوده است؛ بنابراین سازوکار های تطبیقی سودی نداشته و حتی سربار تصمیم گیری باعث افت جزیی عملکرد می شود.

با بزرگ تر شدن اندازه ی کش (از ۱۰۲۴ به ۴۰۹۶ #en[set])، مزیت سیاست های تطبیقی در ردپا های ظرفیت محور مانند #en[mcf] بیشتر نمایان شده است، زیرا فضای بیشتر کش امکان استفاده ی بهتر از تصمیم های هوشمندانه را فراهم کرده است.

== نمودار ها

در این بخش تمام نمودار هایی که تحلیل های بالا بر اساس آنها نوشته شده اند را کنار هم آورده ایم. هر دو دسته هر سه اندازه ی کش (۱۰۲۴ و ۲۰۴۸ و ۴۰۹۶ #en[set]) را پوشش می دهند و فقط در اینکه چه چیزی روی محور افقی است با هم فرق دارند.

=== مقایسه بر حسب سیاست، برای هر سه اندازه ی کش

در این دسته محور افقی سیاست جایگزینی است و هر منحنی مربوط به یکی از سه اندازه ی کش (۱۰۲۴ و ۲۰۴۸ و ۴۰۹۶ #en[set]) است، پس اثر خود سیاست را در اندازه های مختلف نشان می دهد.

#figure(
  grid(
    columns: 2,
    column-gutter: 0.6em,
    image("figures/policy_on_x/403.gcc-17B_ipc.png", width: 100%),
    image("figures/policy_on_x/403.gcc-17B_hit_rate.png", width: 100%),
  ),
  caption: [ردپای #en[403.gcc]: #en[IPC] و نرخ برخورد بر حسب سیاست، برای هر سه اندازه ی کش],
)

#figure(
  grid(
    columns: 2,
    column-gutter: 0.6em,
    image("figures/policy_on_x/429.mcf-51B_ipc.png", width: 100%),
    image("figures/policy_on_x/429.mcf-51B_hit_rate.png", width: 100%),
  ),
  caption: [ردپای #en[429.mcf]: #en[IPC] و نرخ برخورد بر حسب سیاست، برای هر سه اندازه ی کش],
)

#figure(
  grid(
    columns: 2,
    column-gutter: 0.6em,
    image("figures/policy_on_x/470.lbm-1274B_ipc.png", width: 100%),
    image("figures/policy_on_x/470.lbm-1274B_hit_rate.png", width: 100%),
  ),
  caption: [ردپای #en[470.lbm]: #en[IPC] و نرخ برخورد بر حسب سیاست، برای هر سه اندازه ی کش],
)

#figure(
  grid(
    columns: 2,
    column-gutter: 0.6em,
    image("figures/policy_on_x/471.omnetpp-188B_ipc.png", width: 100%),
    image("figures/policy_on_x/471.omnetpp-188B_hit_rate.png", width: 100%),
  ),
  caption: [ردپای #en[471.omnetpp]: #en[IPC] و نرخ برخورد بر حسب سیاست، برای هر سه اندازه ی کش],
)

=== مقایسه بر حسب تعداد #en[set]

در این دسته محور افقی تعداد #en[set] هاست و هر منحنی مربوط به یک سیاست است، پس نشان می دهد هر سیاست با بزرگ تر شدن کش چطور رفتار می کند.

#figure(
  grid(
    columns: 2,
    column-gutter: 0.6em,
    image("figures/size_on_x/403.gcc-17B_ipc.png", width: 100%),
    image("figures/size_on_x/403.gcc-17B_hit_rate.png", width: 100%),
  ),
  caption: [ردپای #en[403.gcc]: #en[IPC] و نرخ برخورد بر حسب تعداد #en[set]],
)

#figure(
  grid(
    columns: 2,
    column-gutter: 0.6em,
    image("figures/size_on_x/429.mcf-51B_ipc.png", width: 100%),
    image("figures/size_on_x/429.mcf-51B_hit_rate.png", width: 100%),
  ),
  caption: [ردپای #en[429.mcf]: #en[IPC] و نرخ برخورد بر حسب تعداد #en[set]],
)

#figure(
  grid(
    columns: 2,
    column-gutter: 0.6em,
    image("figures/size_on_x/470.lbm-1274B_ipc.png", width: 100%),
    image("figures/size_on_x/470.lbm-1274B_hit_rate.png", width: 100%),
  ),
  caption: [ردپای #en[470.lbm]: #en[IPC] و نرخ برخورد بر حسب تعداد #en[set]],
)

#figure(
  grid(
    columns: 2,
    column-gutter: 0.6em,
    image("figures/size_on_x/471.omnetpp-188B_ipc.png", width: 100%),
    image("figures/size_on_x/471.omnetpp-188B_hit_rate.png", width: 100%),
  ),
  caption: [ردپای #en[471.omnetpp]: #en[IPC] و نرخ برخورد بر حسب تعداد #en[set]],
)

= توضیح #en[Trace] ها

در رابطه با #en[trace] ها انتخاب شده: #en[trace] اول #en[403.gcc] بود و برای آن انتخابش کردیم که همجواری زمانی بالایی داشت. علت هم آن است که مربوط به کامپایلر #en[gcc] است کامپایلر بار ها به ساختار های داده یکسان (مثل جدول نماد ها و …) دسترسی میخواهد بنابراین بلوک های کشی که به تازگی به از آنها استفاده شده، احتمالا دوباره از آنها استفاده خواهد شد و همانطور هم که در نمودار ها مشخص است و مورد انتظار ماست، سیاست #en[LRU] عملکرد خیلی خوبی روی آن داشته است.

ردپای دوم #en[429.mcf] بود و علت انتخاب این بود که همجواری مکانی بالایی داشت. علت این اتفاق هم این است که این ردپا مربوط به حل مسایل بهینه سازی شبکه است و حجم خیلی زیادی داده را در حافظه پردازش میکند. این دسترسی ها معمولا به آدرس های مجاور هستند و برای همین همجواری مکانی در آن مهم است. یک نکته دیگر هم این است که به خاطر دسترسی های زیاد به حافظه، تاثیر اندازه کش در آن به خوبی محسوس است که در نمودار ها هم قابل مشاهده است.

ردپای سوم #en[470.lbm] بود و علت انتخاب این بود که رفتار جریانی را درون خود دارد. این برنامه مربوط به شبیه سازی دینامیک سیالات است و داده ها را عمدتا به صورت ترتیبی و یک بار مصرف پردازش می کند. بنابراین پس از دسترسی به یک بلوک حافظه، احتمال استفاده مجدد از آن بسیار کم است. بنابراین این ردپا نمونه ی خوبی از رفتار جریانی محسوب می شود و همانطور که در نمودار ها واضح است #en[hit rate] برای برخی از سیاست ها بسیار پایین است که مطابق انتظار ماست.

ردپای آخر هم #en[471.omnetpp] بود و برای این انتخاب شد که بین سیاست های جایگزینی تفاوت قابل قبولی قایل میشد. چرا که این ردپا مربوط به شبیه سازی شبکه های کامپیوتری است. الگوی دسترسی آن به نسبت پیچیده است و مجموعه داده های فعال آن به گونه ای است که انتخاب بلوک برای جایگزینی می تواند تاثیر قابل توجهی بر نرخ برخورد و عملکرد سیستم داشته باشد. این مورد هم دقیقا روی نمودار ها قابل مشاهده است و بین سیاست ها تفاوت وجود دارد.

نکته دیگر درباره شبیه سازی ها این است که تمام ۹۶ شبیه سازی، با ۱۲۵۰۰۰۰۰ دستور گرم سازی و ۵۰۰۰۰۰۰۰ دستور شبیه سازی انجام شد. این اتفاق خوبی بود که تمام شبیه سازی ها با تعداد دستور یکسان اجرا شدند زیرا باعث عدالت شد و تعداد دستورات هم مقدار زیادی بود تا به خوبی سیاست های مختلف روی ردپا های مختلف مورد آزمایش قرار بگیرند و تفاوت میان ردپا ها قابل حس باشد ولی طبیعتا به خاطر اینکه ردپا های مختلف داشیم، تفاوت زمانی بین شبیه سازی ها دیده میشود. مثلا شبیه سازی ها با این تعداد دستور روی ردپای #en[429.mcf] حدود +۲۰ دقیقه زمان میبرد در حالی که بقیه شبیه سازی ها معمولا زیر ۱۰ دقیقه بودند و علت آن هم طبیعتا نوع متفاوت ردپاهاست و همانطور که گفته شده بود ردپای #en[429.mcf] خیلی به حافظه دسترسی دارد (تعداد دسترسی ها همانطور که در #en[llc_results] مشاهده میشود برای این ردپا بیشتر از بقیه است) بنابراین نسبت به بقیه ردپا ها خیلی بیشتر در #en[llc] خطا داریم و از آنجا که خطا در #en[llc] پنالتی خیلی زیادی دارد، باعث طولانی تر شدن شبیه سازی در این ردپا در مقایسه با بقیه شده است. میانگین دسترسی به #en[llc] در بقیه نزدیک به هم هستند و فقط #en[471.omnetpp] مقدار کمی از بقیه کمتر به #en[llc] دسترسی دارد و همین مورد هم سبب این شده که این ردپا هم کمی نسبت به بقیه زمان کمتری بگیرد.

= تحلیل پیچیدگی و هزینه ی سخت افزاری هر #en[Policy]

در گام های قبل سیاست ها را از نظر کارایی (نرخ برخورد و #en[IPC]) با هم مقایسه کردیم. اما در عمل، انتخاب یک سیاست جایگزینی فقط به کارایی آن وابسته نیست؛ هر سیاست برای پیاده سازی روی سخت افزار واقعی هزینه ای دارد که شامل بیت های کمکی ذخیره شده به ازای هر خط کش، نیاز به شمارنده های سراسری، و پیچیدگی منطق انتخاب قربانی و به روزرسانی وضعیت است. در این بخش هر هشت سیاست را از این جنبه ها بررسی می کنیم و در پایان جمع بندی می کنیم که با توجه به داده های به دست آمده، کدام سیاست از نظر نسبت کارایی به هزینه انتخاب بهتری است.

در پیاده سازی ما بسیاری از سیاست ها برای سادگی از یک برچسب زمانی پهن (`uint64_t`) استفاده می کنند؛ برای مثال #en[LRU] به ازای هر خط یک شمارنده ی زمانی ۶۴ بیتی نگه می دارد. این کار در یک شبیه ساز نرم افزاری کاملا منطقی است، ولی در سخت افزار واقعی هیچ کس ۶۴ بیت به ازای هر خط خرج نمی کند. بنابراین در ستون بیت های کمکی ما هزینه ی *سخت افزاری ایده آل* (یعنی حداقل بیت لازم در یک پیاده سازی واقعی) را گزارش می کنیم و در صورت تفاوت، به پیاده سازی خودمان هم اشاره می کنیم. فرض ما یک کش ۱۶ راهه است (مطابق پیکربندی پایه)، پس هر خط برای نگه داری ترتیب کامل به اندازه ی `ceil(log2(16)) = 4` بیت نیاز دارد.

باید بین دو نوع شمارنده ی سراسری تفاوت قایل شویم. برخی سیاست ها مثل #en[DRRIP] به یک شمارنده ی سراسری *الگوریتمی* (مثل #en[PSEL]) نیاز دارند که بخشی از منطق تصمیم گیری سیاست است. اما در پیاده سازی نرم افزاری ما، سیاست های مبتنی بر برچسب زمان (#en[LRU] و #en[FIFO] و #en[MRU] و #en[BIP]) هم یک شمارنده ی `cycle` سراسری دارند که صرفا برای تولید برچسب های زمانی افزایشی استفاده می شود. این شمارنده یک جز ذاتی الگوریتم نیست و در سخت افزار واقعی با روش های دیگری (مثل جابه جایی ترتیب در خود مجموعه) قابل حذف است. در جدول، این تفاوت را مشخص کرده ایم.

== جدول مقایسه ی کلی

#figure(
  table(
    columns: 6,
    align: center + horizon,
    [سیاست], [بیت کمکی هر خط (ایده آل)], [شمارنده ی سراسری], [پیچیدگی انتخاب قربانی], [پیچیدگی به روزرسانی], [مناسب سخت افزار؟],

    [*#en[Random]*], [۰], [ندارد (فقط مولد شبه تصادفی)], [حداقلی: یک عدد تصادفی], [ندارد], [بله، ارزان ترین],
    [*#en[FIFO]*], [۴ بیت (ترتیب ورود)], [فقط شمارنده ی زمان (نه الگوریتمی)], [کم: کوچک ترین برچسب ورود], [فقط هنگام درج (نه در #en[hit])], [بله],
    [*#en[LRU]*], [۴ بیت (ترتیب دسترسی)], [فقط شمارنده ی زمان (نه الگوریتمی)], [کم: کوچک ترین برچسب زمان], [در هر #en[hit] و هر درج], [نسبتا؛ به روزرسانی پرهزینه],
    [*#en[MRU]*], [۴ بیت (مثل #en[LRU])], [فقط شمارنده ی زمان (نه الگوریتمی)], [کم: بزرگ ترین برچسب زمان], [مثل #en[LRU]], [مثل #en[LRU]],
    [*#en[SRRIP]*], [۲ بیت (#en[RRPV])], [ندارد], [متوسط: یافتن #en[RRPV] برابر ۳ و افزایش گروهی], [مقدار ثابت در #en[hit] و درج], [بله، بسیار مناسب],
    [*#en[BIP]*], [۴ بیت (مثل #en[LRU])], [شمارنده ی زمان + مولد تصادفی], [مثل #en[LRU]], [درج دوحالته (۱/۳۲)], [بله],
    [*#en[DRRIP]*], [۲ بیت (#en[RRPV])], [شمارنده ی #en[PSEL] ۱۰ بیتی هر هسته], [مثل #en[SRRIP]], [#en[SRRIP]/#en[BRRIP] + به روزرسانی #en[PSEL]], [بله، سربار کم],
    [*#en[SHiP]*], [۲ بیت #en[RRPV] + امضا هر خط], [جدول #en[SHCT] با ۱۶۳۸۴ شمارنده ی ۳ بیتی + #en[sampler]], [مثل #en[SRRIP]], [جست و جو و به روزرسانی جدول #en[SHCT]], [نسبتا؛ پرهزینه ترین],
  ),
  caption: [مقایسه ی هزینه ی سخت افزاری و پیچیدگی هشت سیاست],
)

== بررسی سیاست به سیاست

=== #en[Random]

این ارزان ترین سیاست ممکن است. هیچ اطلاعات کمکی به ازای هر خط ذخیره نمی کند (صفر بیت) و هیچ شمارنده ی سراسری ای ندارد؛ تنها به یک مولد شبه تصادفی نیاز دارد. انتخاب قربانی صرفا تولید یک عدد در بازه ی `[0, ways-1]` است و هیچ تابع به روزرسانی ای ندارد (در کد ما فقط `find_victim` نوشته شده است). از نظر سخت افزاری بی رقیب است، ولی چون هیچ اطلاعاتی از رفتار برنامه نگه نمی دارد، کارایی آن قابل پیش بینی نیست.

=== #en[FIFO]

به ازای هر خط یک برچسب ترتیب ورود نگه می دارد (در پیاده سازی ما `uint64_t`، ولی به طور ایده آل حدود ۴ بیت کافی است) و یک شمارنده ی زمان مشترک برای ثبت ترتیب ورود دارد. نکته ی مهم این است که تابع به روزرسانی آن *خالی* است: در هنگام #en[hit] هیچ کاری انجام نمی دهد و برچسب فقط در زمان درج ثبت می شود. به همین دلیل هزینه ی به روزرسانی آن از #en[LRU] کمتر است، ولی چون به دسترسی های مکرر بی توجه است، کارایی ضعیف تری دارد.

=== #en[LRU]

به ازای هر خط یک برچسب زمان دسترسی نگه می دارد (ایده آل: ۴ بیت). شمارنده ی سراسری آن فقط برای تولید برچسب زمان است و جزیی از منطق تصمیم گیری نیست. انتخاب قربانی ساده است (کوچک ترین برچسب)، اما نکته ی اصلی هزینه ی آن در *به روزرسانی* است: در هر بار #en[hit] باید ترتیب دسترسی خط به روز شود. در سخت افزار واقعی، نگه داری ترتیب کامل #en[LRU] برای درجه ی همنشینی بالا پرهزینه است و معمولا از تقریب های آن (مثل #en[Pseudo-LRU]) استفاده می شود. به همین دلیل #en[LRU] با اینکه مبنای مقایسه ی ماست، لزوما ارزان ترین گزینه نیست.

=== #en[MRU]

از نظر سخت افزاری دقیقا هم هزینه ی #en[LRU] است؛ تنها تفاوت آن استفاده از `max_element` به جای `min_element` در انتخاب قربانی است. بنابراین همان ۴ بیت به ازای هر خط و همان منطق به روزرسانی را دارد. هزینه ی اضافه ای نسبت به #en[LRU] ندارد، ولی همان طور که در داده ها دیدیم در بیشتر ردپا ها کارایی بسیار پایینی دارد.

=== #en[SRRIP]

از نظر نسبت کارایی به هزینه یکی از بهترین هاست. تنها *۲ بیت* به ازای هر خط نیاز دارد (مقدار #en[RRPV] با `maxRRPV=3`) و هیچ شمارنده ی سراسری ای ندارد. این نکته جالب است که #en[SRRIP] هم *کم بیت تر* از #en[LRU] است (۲ بیت در برابر ۴ بیت) و هم در بیشتر ردپا ها کارایی بهتری دارد. انتخاب قربانی کمی پیچیده تر است چون ممکن است لازم باشد #en[RRPV] همه ی خطوط تا رسیدن یکی به مقدار بیشینه افزایش یابد (که در کد ما با یک `transform` جبری به جای حلقه پیاده شده تا ارزان تر باشد)، ولی به روزرسانی آن بسیار ساده است: در #en[hit] مقدار صفر و در درج مقدار `maxRRPV-1`. از نظر سخت افزاری بسیار مناسب است.

=== #en[BIP]

ساختار داده ی آن دقیقا مثل #en[LRU] است (۴ بیت به ازای هر خط) و انتخاب قربانی آن هم عینا مثل #en[LRU] است. تفاوت فقط در منطق درج است: با احتمال ۱/۳۲ بلوک جدید را در موقعیت #en[MRU] و با احتمال ۳۱/۳۲ در موقعیت #en[LRU] قرار می دهد. بنابراین سربار سخت افزاری اضافه ی آن تنها یک مولد تصادفی کوچک و پارامتر $epsilon$ است. پیچیدگی آن کمی بیشتر از #en[LRU] خام است ولی همچنان کاملا مناسب سخت افزار است.

=== #en[DRRIP]

روی #en[SRRIP] سوار شده و همان *۲ بیت* #en[RRPV] به ازای هر خط را دارد. هزینه ی سراسری اضافه ی آن یک *شمارنده ی #en[PSEL] ۱۰ بیتی به ازای هر هسته* است (در کد ما `PSEL_WIDTH=10`) به همراه منطق دسته بندی مجموعه ها به سه گروه (رهبر #en[SRRIP]، رهبر #en[BRRIP]، و #en[follower]). این هزینه ی سراسری بسیار ناچیز است: تنها ۱۰ بیت برای کل کش، در برابر ۲ بیت در هر تک تک خطوط. انتخاب قربانی مثل #en[SRRIP] است و به روزرسانی، علاوه بر منطق #en[SRRIP]/#en[BRRIP]، شامل به روز کردن #en[PSEL] در مجموعه های رهبر است. نکته ی جالب سخت افزاری این است که #en[BRRIP] در پیاده سازی ما به جای احتمالی بودن، *چرخه ای* پیاده شده (هر ۳۲ درج یک بار)، که از نظر عملکردی تقریبا یکسان ولی از نظر سخت افزاری ساده تر از یک مولد تصادفی است.

=== #en[SHiP]

پرهزینه ترین سیاست از نظر سخت افزاری است. علاوه بر ۲ بیت #en[RRPV] به ازای هر خط، به یک *امضا (#en[signature])* به ازای هر خط نیاز دارد (در کد ما مشتق شده از #en[PC]) و مهم تر از آن، یک *جدول سراسری #en[SHCT] با ۱۶۳۸۴ خانه* که هر خانه یک شمارنده ی ۳ بیتی است (`SHCT_MAX=7`). این جدول به تنهایی حجم قابل توجهی سخت افزار می طلبد. برای کاهش این هزینه، پیاده سازی به جای رصد همه ی مجموعه ها فقط تعداد محدودی مجموعه را به عنوان *#en[sampler]* رصد می کند و نتیجه را به بقیه تعمیم می دهد؛ ولی حتی با این ترفند، #en[SHiP] همچنان بیشترین بیت کمکی و پیچیده ترین منطق به روزرسانی (جست و جو، آموزش و به روزرسانی جدول) را دارد. انتخاب قربانی آن اما دقیقا مثل #en[SRRIP] ساده است؛ همه ی هزینه در منطق پیش بینی و به روزرسانی جدول است.

== جمع بندی: کارایی در برابر سادگی

اگر *تنها کارایی* مهم باشد، انتخاب ما به اندازه ی کش بستگی دارد و این نکته ی جالبی است که در داده های ما دیده می شود:

- در کش های بزرگ تر (۴۰۹۶ مجموعه)، سیاست های پیشرفته ی تطبیقی بهترین عملکرد را دارند: به طور میانگین #en[SHiP] با بهبود حدود ۹ درصد و #en[DRRIP] با حدود ۸ درصد نسبت به #en[LRU] در صدر قرار می گیرند. در این حالت، هزینه ی سخت افزاری بالای #en[SHiP] توجیه می شود.
- در کش های کوچک تر (۱۰۲۴ و ۲۰۴۸ مجموعه)، جالب اینکه *#en[BIP]* با وجود سادگی، به طور میانگین بهترین بهبود (حدود ۴ درصد) را دارد و از #en[SHiP] و #en[DRRIP] هم جلو می زند.

بنابراین اگر صرفا کارایی مهم باشد و کش بزرگ باشد، *#en[SHiP] یا #en[DRRIP]* را انتخاب می کنیم.

اما اگر *سادگی سخت افزاری هم مهم باشد*، انتخاب ما تغییر می کند. در این حالت *#en[DRRIP]* گزینه ی بسیار جذابی است: تقریبا تمام قابلیت تطبیق پذیری #en[SHiP] را دارد ولی به جای یک جدول ۱۶۳۸۴ خانه ای و امضا به ازای هر خط، تنها به ۲ بیت در هر خط و یک شمارنده ی ۱۰ بیتی سراسری نیاز دارد. اگر بخواهیم از این هم ساده تر برویم، *#en[SRRIP]* با تنها ۲ بیت به ازای هر خط و بدون هیچ شمارنده ی سراسری، بخش بزرگی از بهبود را با کمترین هزینه ی ممکن به دست می آورد و حتی از #en[LRU] هم کم بیت تر است.

جمع بندی نهایی ما این است: *#en[DRRIP] نقطه ی تعادل بهینه بین کارایی و هزینه ی سخت افزاری است.* #en[SHiP] سقف کارایی را کمی بالاتر می برد ولی با هزینه ی سخت افزاری به مراتب بیشتر، و #en[SRRIP] ساده ترین انتخاب منطقی برای شرایطی است که بودجه ی سخت افزاری محدود است.

= نحوه ی اجرا و خروجی گرفتن پروژه

کل فرایند اجرا با سه اسکریپت داخل پوشه ی `scripts` انجام می شود که به ترتیب پشت سر هم اجرا می شوند: اول ساخت باینری ها، بعد اجرای شبیه سازی ها و در آخر استخراج نتایج از #en[log] ها. برای هر کانفیگ کش مجبوریم یک بیلد جدا بگیریم چون #en[ChampSim] اینطوری برنامه نویسی شده است.

== اسکریپت #en[make_bins.sh] — ساخت باینری ها

این اسکریپت به ازای هر ترکیب از تعداد #en[set] و #en[replacement policy] یک باینری جدا می سازد. لیست مقادیر آن سه اندازه ی ۱۰۲۴ و ۲۰۴۸ و ۴۰۹۶ برای #en[set] و هشت سیاست `lru` و `mru` و `random` و `fifo` و `ship` و `srrip` و `drrip` و `bip` است و تعداد #en[way] در همه ی حالت ها روی ۱۶ ثابت می ماند. در هر تکرار حلقه، با استفاده از `jq` سه فیلد `LLC.sets` و `LLC.ways` و `LLC.replacement` در فایل `champsim_config.json` بازنویسی می شود، بعد پوشه ی `.csconfig` پاک و با `config.sh` سورس ها دوباره تولید می شوند و در نهایت `make` اجرا می شود. باینری ساخته شده با نام گذاری `champsim_llc_<sets>s_<ways>w_<policy>` داخل پوشه ی `bin` ذخیره می شود تا بعدا در نتایج قابل تشخیص باشد. در مجموع #ltr-isolate("۳ × ۸ = ۲۴") باینری ساخته می شود.

== اسکریپت #en[run_all.sh] — اجرای شبیه سازی ها

این اسکریپت روی تمام باینری های داخل `bin` حلقه می زند و هر کدام را روی هر چهار ردپای انتخاب شده (#en[403.gcc] و #en[429.mcf] و #en[470.lbm] و #en[471.omnetpp]) اجرا می کند، یعنی #ltr-isolate("۲۴ × ۴ = ۹۶") شبیه سازی که همان عددی است که در بخش ردپا ها به آن اشاره کردیم. تعداد دستورات هم برای همه یکسان و به صورت `--warmup-instructions=12500000` و `--simulation-instructions=50000000` تنظیم شده است. خروجی هر اجرا در فایلی با اسم `logs/<binary>_<trace>.log` ذخیره می شود. برای اینکه اجرای کل مجموعه بیش از حد طول نکشد، شبیه سازی ها به صورت موازی و در پس زمینه اجرا می شوند و متغیر `MAX_JOBS` تعداد اجرا های همزمان را به ۸ محدود می کند (مقدار معقول باید باشد که کل هسته های #en[CPU] درگیر نشوند که زمان اجرای آنها روی هم تاثیر بگذارد). حلقه ی انتظار داخل اسکریپت تا وقتی که تعداد #en[job] های در حال اجرا به زیر این حد نرسد اجرای جدید شروع نمی کند.

== اسکریپت #en[ex_info.sh] — استخراج نتایج

بعد از تمام شدن شبیه سازی ها، این اسکریپت تمام فایل های داخل `logs` را می خواند و از هر کدام سه عدد مورد نیاز ما را بیرون می کشد: از خط `cpu0->LLC TOTAL` مقادیر `ACCESS` و `HIT` و از آخرین خط `cumulative IPC` مقدار #en[IPC] نهایی. نتیجه به صورت یک فایل `llc_results.csv` با ستون های `Binary,LLC_Access,LLC_Hit,IPC` نوشته می شود که همان فایلی است که تمام نمودار ها و تحلیل های این گزارش از روی آن ساخته شده اند. نرخ برخورد هم از تقسیم `LLC_Hit` بر `LLC_Access` به دست می آید.
