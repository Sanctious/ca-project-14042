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
    ([استاد درس], [نام استاد]),
    ([درس], [معماری کامپیوتر]),
  ),
  abstract: [
    پر شود
  ],
  refs: bibliography("refs.bib", title: none, style: "ieee"),
)

= مقدمه

#en[12.5M warmup 50M simulation]

= توضیح #en[Replacement Policy] ها

برای تمام #en[Replacement Policy] ها یک دور روش آنها را به طور کامل توضیح می دهیم که گزارش کامل باشد.
نکات ناقص رو نیز باید اضافه بکنیم.

== یک نکته ی مشترک بین چند #en[policy]: نوع دسترسی `access_type::WRITE`

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

= توضیح #en[Trace] ها

در رابطه با #en[trace] ها انتخاب شده: #en[trace] اول #en[403.gcc] بود و برای آن انتخابش کردیم که همجواری زمانی بالایی داشت. علت هم آن است که مربوط به کامپایلر #en[gcc] است کامپایلر بار ها به ساختار های داده یکسان (مثل جدول نماد ها و …) دسترسی میخواهد بنابراین بلوک های کشی که به تازگی به از آنها استفاده شده، احتمالا دوباره از آنها استفاده خواهد شد و همانطور هم که در نمودار ها مشخص است و مورد انتظار ماست، سیاست #en[LRU] عملکرد خیلی خوبی روی آن داشته است.

ردپای دوم #en[429.mcf] بود و علت انتخاب این بود که همجواری مکانی بالایی داشت. علت این اتفاق هم این است که این ردپا مربوط به حل مسایل بهینه سازی شبکه است و حجم خیلی زیادی داده را در حافظه پردازش میکند. این دسترسی ها معمولا به آدرس های مجاور هستند و برای همین همجواری مکانی در آن مهم است. یک نکته دیگر هم این است که به خاطر دسترسی های زیاد به حافظه، تاثیر اندازه کش در آن به خوبی محسوس است که در نمودار ها هم قابل مشاهده است.

ردپای سوم #en[470.lbm] بود و علت انتخاب این بود که رفتار جریانی را درون خود دارد. این برنامه مربوط به شبیه سازی دینامیک سیالات است و داده ها را عمدتا به صورت ترتیبی و یک بار مصرف پردازش می کند. بنابراین پس از دسترسی به یک بلوک حافظه، احتمال استفاده مجدد از آن بسیار کم است. بنابراین این ردپا نمونه ی خوبی از رفتار جریانی محسوب می شود و همانطور که در نمودار ها واضح است #en[hit rate] برای برخی از سیاست ها بسیار پایین است که مطابق انتظار ماست.

ردپای آخر هم #en[471.omnetpp] بود و برای این انتخاب شد که بین سیاست های جایگزینی تفاوت قابل قبولی قایل میشد. چرا که این ردپا مربوط به شبیه سازی شبکه های کامپیوتری است. الگوی دسترسی آن به نسبت پیچیده است و مجموعه داده های فعال آن به گونه ای است که انتخاب بلوک برای جایگزینی می تواند تاثیر قابل توجهی بر نرخ برخورد و عملکرد سیستم داشته باشد. این مورد هم دقیقا روی نمودار ها قابل مشاهده است و بین سیاست ها تفاوت وجود دارد.

نکته دیگر درباره شبیه سازی ها این است که تمام ۹۶ شبیه سازی، با ۱۲۵۰۰۰۰۰ دستور گرم سازی و ۵۰۰۰۰۰۰۰ دستور شبیه سازی انجام شد. این اتفاق خوبی بود که تمام شبیه سازی ها با تعداد دستور یکسان اجرا شدند زیرا باعث عدالت شد و تعداد دستورات هم مقدار زیادی بود تا به خوبی سیاست های مختلف روی ردپا های مختلف مورد آزمایش قرار بگیرند و تفاوت میان ردپا ها قابل حس باشد ولی طبیعتا به خاطر اینکه ردپا های مختلف داشیم، تفاوت زمانی بین شبیه سازی ها دیده میشود. مثلا شبیه سازی ها با این تعداد دستور روی ردپای #en[429.mcf] حدود +۲۰ دقیقه زمان میبرد در حالی که بقیه شبیه سازی ها معمولا زیر ۱۰ دقیقه بودند و علت آن هم طبیعتا نوع متفاوت ردپاهاست و همانطور که گفته شده بود ردپای #en[429.mcf] خیلی به حافظه دسترسی دارد (تعداد دسترسی ها همانطور که در #en[llc_results] مشاهده میشود برای این ردپا بیشتر از بقیه است) بنابراین نسبت به بقیه ردپا ها خیلی بیشتر در #en[llc] خطا داریم و از آنجا که خطا در #en[llc] پنالتی خیلی زیادی دارد، باعث طولانی تر شدن شبیه سازی در این ردپا در مقایسه با بقیه شده است. میانگین دسترسی به #en[llc] در بقیه نزدیک به هم هستند و فقط #en[471.omnetpp] مقدار کمی از بقیه کمتر به #en[llc] دسترسی دارد و همین مورد هم سبب این شده که این ردپا هم کمی نسبت به بقیه زمان کمتری بگیرد.

= نحوه ی اجرا و خروجی گرفتن پروژه

توضیح #en[script] ها و ...

#note[
  برای گام های اولیه #en[sets=2048] دیفالت باشد.

  تمام فعل ها و اشاره ها باید به صورت «ما» باشد نه «من».
]
