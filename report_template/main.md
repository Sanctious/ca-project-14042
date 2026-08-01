## مقدمه:
مسله ای اصلی که در این پروژه باید بحث می شد بررسی Replacement Policy های مختلف Cache در لایه ی آخر (LLC) است.
سیاست های بررسی شده:

| مخفف | نام کامل | مرجع |
|---|---|---|
| LRU | Least Recently Used | ویکی پدیا: سیاست های جایگزینی کش [^wiki-repl] |
| MRU | Most Recently Used | ویکی پدیا: سیاست های جایگزینی کش [^wiki-repl] |
| FIFO | First In First Out | ویکی پدیا: سیاست های جایگزینی کش [^wiki-repl] |
| Random | Random Replacement | ویکی پدیا: سیاست های جایگزینی کش [^wiki-repl] |
| SRRIP | Static Re-Reference Interval Prediction | مقاله ی RRIP [^rrip] |
| DRRIP | Dynamic Re-Reference Interval Prediction | مقاله ی RRIP [^rrip] |
| BIP | Bimodal Insertion Policy | مقاله ی DIP [^dip] |
| SHiP | Signature-based Hit Predictor | مقاله ی SHiP [^ship] |

شبیه سازی ها همگی با شبیه ساز ChampSim [^champsim] انجام شده اند و ردپا های استفاده شده را از مخزن ردپا های آماده ی ChampSim دانلود کرده ایم [^spec].
 
نکته:
برای بخش امتیازی ما تغییر sets ها را انتخاب کردیم و بین مقادیر ۱۰۲۴ و ۲۰۴۸ و ۴۰۹۶ تغییر دادیم. تحلیل های قبل حالت امتیازی روی ۲۰۴۸ انجام شده اند.
نکته:
تعداد دستورات برای بخش warmup برابر ۱۲.۵ میلیون و برای بخش شبیه سازی ۵۰ میلیون. است.
## توضیح Replacement Policy های استفاده شده:
برای تمام Replacement Policy ها یک دور روش آنها را به طور کامل توضیح می دهیم که گزارش کامل باشد.
نکات ناقص رو نیز باید اضافه بکنیم.
  یک نکته ی مشترک بین چند policy: نوع دسترسی `access_type::WRITE`
در چند تا از سیاست های، یک شرط روی `access_type` می بینیم که دسترسی های نوع `WRITE` را جدا می کند. این نوع دسترسی ها مربوط به writeback می شود. نکته این است که این نوشتن نشانه ی استفاده ی پردازنده از داده در همان لحظه نیست، بلکه صرفا نتیجه ی replacement در سطح بالاتر است. اگر writeback ها را مثل دسترسی عادی حساب کنیم و سیاست ها را روی آنها نیز اجرا کنیم، دو مشکل پیش می آید: اول اینکه بلوک هایی که فقط نوشته شده اند بی دلیل تازه به حساب می آیند و در کش ماندگار می شوند و دوم اینکه در سیاست های پویا مثل DRRIP آمار تصمیم گیری منحرف می شود چون این دسترسی ها رفتار واقعی برنامه را نشان نمی دهند. به همین دلیل در سیاست های ما یا اثر writeback نادیده گرفته می شود یا بلوک با یک مقدار امن و غیر مخرب پر می شود.

توابع مهم برای هر سیاست:
تابع `find_victim`: وقتی miss رخ داد، شماره ی way قربانی را برمی گرداند.
تابع `replacement_cache_fill`: بعد از اینکه بلوک جدید داخل way قرار گرفت صدا زده می شود (منطق fill).
- تابع `update_replacement_state`: در هر دسترسی صدا زده می شود و پارامتر `hit` مشخص می کند دسترسی hit بوده یا نه.
نکته ی نهایی این نیز که بیشتر تنظیمات کلی و global به ازای هر CPU Core است، مثلا برای شمارنده ها و ...
#### LRU:

منطق انتخاب بلوک قربانی:
بین تمام بلوک های موجود در یک set، بلوکی حذف می شود که بیشترین زمان بدون استفاده مانده است، به همین دلیل بلوک های که دسترسی بیشتری در طول زمان دارند کمتر حذف می شوند.
نحوه بروزرسانی اطلاعات کمکی:
هر بلوک یک مقدار زمان دسترسی نگه می دارد که نشان می دهد نسبت به بقیه بلوک ها داخل همان set کی مورد دسترسی واقع شده است. مقدار ۰ یعنی اینکه نسبت به بقیه قدیمی تر استفاده شده است، و هرچه مقدار آن بزرگتر باشد یعنی اینکه نسبت به بقیه جدید تر مورد دسترسی واقع شده است، و جدیدترین دسترسی این set است. هر دسترسی با توجه به Miss یا Hit شدن مقادیر را تغییر می دهیم که ترتیب دسترسی حفظ شود.

نحوه ی بروزرسانی اطلاعات پس از برخورد (hit):
در هنگام hit برچسب زمان همان بلوک برابر مقدار فعلی شمارنده ی `cycle` می شود و بعد `cycle` یکی زیاد می شود. یعنی آن بلوک تبدیل به جدیدترین بلوک (MRU) در set خودش می شود و برچسب بقیه ی بلوک ها دست نخورده باقی می ماند، پس به صورت نسبی همه ی آنها یک واحد زمانی قدیمی تر می شوند. تنها استثنا دسترسی های نوع `WRITE` است که مطابق توضیح ابتدای بخش نادیده گرفته می شوند و برچسب زمان را عوض نمی کنند.

نحوه ی بروزرسانی اطلاعات پس از جایگزینی (fill):
بعد از اینکه بلوک قربانی خارج شد و بلوک جدید در همان way نشست، تابع `replacement_cache_fill` برچسب زمان آن way را برابر `cycle` قرار می دهد و شمارنده را زیاد می کند. پس بلوک تازه درج شده در موقعیت MRU قرار می گیرد و امن ترین بلوک set است، یعنی تا وقتی که تمام بلوک های دیگر یک بار خارج نشوند نوبت به آن نمی رسد. هیچ اطلاعات دیگری در set بروزرسانی نمی شود.

شرایط عملکرد مناسب و نامناسب:
سیاست LRU وقتی خوب کار می کند که برنامه از داده هایی که استفاده می کند به تعداد بالاتری نیز مجدد استفاده بکند.
در مقابل، LRU در حالت های scan های خطی یا حلقه ای که در cache جا نشوند بد عمل می کند، چون به ترتیب داده ها یکبار مصرف می شوند و در دومی تا به سر آرایه برسیم آن داده ها دور ریخته شده اند و عملا فقط cache را کثیف کردیم.

نکات کد:

قطعه ۱ — ساختار داده ی کمکی و سازنده

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
قطعه ۲ — انتخاب بلوک قربانی

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
ابتدا با `begin` و `end` بازه ی مربوط به همان set جدا می شود و بعد `min_element` کوچک ترین برچسب زمان را پیدا می کند. چون برچسب بزرگ تر یعنی دسترسی جدیدتر، کوچک ترین مقدار دقیقا یعنی بلوکی که از همه دیرتر استفاده شده است.
اگر چند بلوک مقدار برابر داشته باشند (مثلا چند way هنوز دست نخورده و برابر ۰ باشند)، `min_element` اولین آنها را برمی گرداند، پس ترتیب پر شدن set از way کوچک به بزرگ است.

قطعه ۳ — درج و به روزرسانی
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
در زمان درج بلوک جدید در موقعیت MRU قرار می گیرد و کم خطر ترین بلوک set است.

FIFO:

منطق انتخاب بلوک قربانی:
بین تمام بلوک های موجود در set، بلوکی که زودتر از همه وارد شده است باید خارج شود(منطق First In First Out). اینکه بلوک اخیرا دسترسی قرار گرفته یا نه تاثیری در تصمیم گیری ندارد. عملا منطق صف دارد.
نحوه بروزرسانی اطلاعات کمکی:
یک ترتیب ورود برای بلوک هایی که به set وارد می شوند ذخیره می کند. موقع hit چیزی را تغییر نمی دهد ولی موقع miss ترتیب عوض می شود (البته بدون آپدیت کردن مقدار بقیه چون زمان اضافه شدن اهمیت دارد)

نحوه ی بروزرسانی اطلاعات پس از برخورد (hit):
هیچ بروزرسانی ای انجام نمی شود و تابع `update_replacement_state` کاملا خالی است.

نحوه ی بروزرسانی اطلاعات پس از جایگزینی (fill):
بعد از درج بلوک جدید، برچسب آن way برابر مقدار فعلی `cycle` قرار می گیرد و شمارنده یکی زیاد می شود، یعنی بلوک جدید به انتهای صف اضافه می شود. برچسب بقیه ی بلوک ها دست نمی خورد چون ترتیب ورود آنها ثابت است و ربطی به بلوک جدید ندارد.

شرایط عملکرد مناسب و نامناسب:
سیاست FIFO وقتی خوب عمل می کند و ترتیب ورودی داده ها با ترتیب استفاده از آنها هماهنگ باشد.
در جاهایی بد عمل می کند که بلوکی زود وارد cache شود ولی چون صرفا زود وارد شده ولی ممکن است خیلی استفاده شود در آینده ی نزدیک دور ریخته می شود، و هوشمندی این را ندارد که اگر یک بلوک زیاد استفاده می شود نباید سریع بیرون بیندازدش.

نکات کد:

قطعه ۱ — ساختار داده
```cpp
class fifo : public champsim::modules::replacement
{
  long NUM_WAY;
  std::vector<uint64_t> insertion_cycles;
  uint64_t cycle = 0;
  ...
};
```
ساختار داده دقیقا مثل LRU است و تنها چیزی که فرق می کند مفهوم عدد کمکی است، که اینجا مفهوم زمان وارد شدن بلوک به set را می دهد. cycle در اینجا یک شمارنده کلی است که برای زمان اضافه شدن استفاده می شود و بیانگر شمارشگر زمان است که در هنگام هر fill افزایش پیدا می کند.

قطعه ۲ — انتخاب قربانی و ثبت زمان ورود
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

قطعه ۳ — تابع خالی به روزرسانی
```cpp
void fifo::update_replacement_state(..., uint8_t hit)
{
}
```
تابع update این policy خالی است چون طبق توضیحات در FIFO لازم نیست کاری انجام بدهیم.

MRU:

منطق انتخاب بلوک قربانی:
کاملا مخالف LRU عمل می کند ولی منطق مشابهی داردند به این صورت که بلوکی در set خارج می شود که نسبت به بقیه اخیرا دسترسی داشته است. 
نحوه بروزرسانی اطلاعات کمکی:
مشابه LRU و نکته ای اضافه ای ندارد.

نحوه ی بروزرسانی اطلاعات پس از برخورد (hit):
دقیقا مثل LRU، برچسب زمان بلوکی که hit شده برابر `cycle` می شود و شمارنده زیاد می شود (و باز هم دسترسی های `WRITE` نادیده گرفته می شوند). ولی معنای این کار برعکس LRU است.

نحوه ی بروزرسانی اطلاعات پس از جایگزینی (fill):
بلوک تازه fill شده بزرگترین برچسب زمان set را می گیرد، پس بلافاصله پرخطرترین بلوک برای خروج می شود.

شرایط عملکرد مناسب و نامناسب:
می شود گفت نقطه مقابل LRU است و هر جا آن بد عمل می کند این خوب عمل می کند و هر جا آن خوب عمل می کند این بد عمل می کند. صرفا اینکه برای ذخیره استفاده مکرر از داده های جدید خیلی بد عمل می کند.

نکات کد:

قطعه ۱ — تنها تفاوت با LRU
```cpp
long mru::find_victim(uint32_t triggering_cpu, uint64_t instr_id, long set, ...)
{
  auto begin = std::next(std::begin(last_used_cycles), set * NUM_WAY);
  auto end = std::next(begin, NUM_WAY);

  auto victim = std::max_element(begin, end); //MRU!!!
  return std::distance(begin, victim);
}
```
کل تفاوت پیاده سازی با LRU استفاده از `max_element` به جای `min_element` است، به همین دلیل بلوکی که اخیرا به set اضافه شده است قربانی است. بقیه ی کد ها با LRU کاملا یکسان هستند.

Random:

منطق انتخاب بلوک قربانی:
در هر set به صورت رندوم یک بلوک را انتخاب می کنیم.
نحوه بروزرسانی اطلاعات کمکی:
اطلاعات اضافه ای برای ذخیره لازم نداریم.

نحوه ی بروزرسانی اطلاعات پس از برخورد (hit):
هیچ چیزی بروزرسانی نمی شود و اصلا تابع `update_replacement_state` را override نکرده ایم، چون هیچ حالتی برای نگه داشتن وجود ندارد. تنها چیزی که با هر انتخاب قربانی تغییر می کند وضعیت داخلی generator شبه تصادفی است.

نحوه ی بروزرسانی اطلاعات پس از جایگزینی (fill):
اینجا هم هیچ کاری انجام نمی شود و `replacement_cache_fill` خالی است.

شرایط عملکرد مناسب و نامناسب:
سیاست Random وقتی نسبتا خوب عمل می کند که پترن دسترسی برنامه بدون منطق مشخص و رندوم باشد. صرفا یک روش نامنظم در برابر نامنظم است که لزوما بهترین نتیجه را نمی دهد و یک روش ساده نسبتا معمولی است.
در برنامه هایی که پترن مشخص مثل scan خطی و استفاده ی مکرر از داده ها دارد اصلا خوب عمل نمی کند چون یک رفتار نامنظم در برابر یک رفتار منظم است.

نکات کد:

قطعه ۱ — مولد شبه تصادفی و بازه ی انتخاب
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

قطعه ۲ — انتخاب قربانی و نبود توابع دیگر
```cpp
long random::find_victim(uint32_t triggering_cpu, uint64_t instr_id, long set, ...)
{
  return dist(rng);
}
```
در سیاست random کل خطی که منطق این سیاست را پیاده سازی می کند همین است و توابع دیگر نیاز به override کردن ندارند چون این سیاست منطق هندل کردن حالت ندارد.

SRRIP:
به ازای هر بلوک در set یک عدد به نام RRPV (Re-Reference Prediction Value) ذخیره می شود که معمولا ۲ بیت است که ۴ مقدار می تواند به خود بگیر. در صورتی که ۰ باشد یعنی اینکه احتمالا به زودی استفاده می شود و در صورتی که ۳ باشد احتمالا خیلی در آینده ی دور استفاده می شود و در آینده ی نزدیک احتمالا استفاده نمی شود. 
منطق انتخاب بلوک قربانی:
در روش SRRIP (Static Re-Reference Interval Prediction) کل منطق بر این است که در یک set بلوک هایی که خیلی استفاده می شوند پایدار می شوند و در صورتی که استفاده ی یک بلوک کم شود احتمالا بلوک قربانی خواهد بود. برای پیدا کردن بلوک قربانی هم بلوکی که RRPV برابر ۳ (بیشترین مقدار) را دارد خارج می شود. و در صورتی که هیچ بلوکی مقدار ۳ نداشت، مقدار RRPV تمام بلوک ها را زیاد می کنیم تا یکی به ۳ برسد، و این فرایند تا شرط برقرار شود ادامه پیدا می کند. (بخشی از بروزرسانی هم انجام می دهد)
نحوه بروزرسانی اطلاعات کمکی:
در صورتی که بلوک جدید اضافه شود، یک بلوک با RRPV تقریبا میانه مثل `MAX_RRPV-1` اضافه می کند. در هنگام hit مقدار RRPV آن بلوک به ۰ ریست می شود. مقدار بروزرسانی هنگام خارج شدن یک بلوک هم داریم که بالا توضیح دادیم.

نحوه ی بروزرسانی اطلاعات پس از برخورد (hit):
مقدار RRPV بلوکی که hit شده به ۰ ریست می شود، یعنی پیش بینی می کنیم که خیلی زود دوباره استفاده می شود و آن را به امن ترین حالت می بریم.

نحوه ی بروزرسانی اطلاعات پس از جایگزینی (fill):
ابتدا در خود `find_victim` و قبل از fill کردن، اگر بیشترین RRPV موجود در set کمتر از `maxRRPV` باشد به همه ی بلوک های آن set به اندازه ی `diff = maxRRPV - max` اضافه می شود تا قربانی مشخص شود. بعد از آن برای بلوک تازه اضافه شده مقدار `maxRRPV - 1` می دهیم.

شرایط عملکرد مناسب و نامناسب:
صرفا یک LRU پیشرفته تر است، پس یکم هوشمندانه تر از LRU عمل می کند و حالت های خوب آن مثل scan های خطی و ... است. که چون کمی هوشمندانه تر عمل می کند از LRU هم بهتر عمل می کند.
حالت های بد آن تقریبا مشابه LRU وقتی که در اسکن حلقه ای cache پر شود و قبل از اینکه به سر حلقه برسیم cache پر می شود و داده های اولیه دور ریخته می شوند و مجدد از اول باید دریافت شوند که همه چیز هدر می رود.

نکات کد:

قطعه ۱ — helper هر set و مقداردهی اولیه
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
مقدار اولیه ی همه ی way ها `maxRRPV` است، یعنی کش خالی طوری رفتار می کند که انگار همه ی بلوک ها در مرز خروج هستند. با این حرکت way های خالی بدون هیچ بررسی اضافه ای اول از همه انتخاب می شوند.
در اینجا ما `maxRRPV` را مساوی ۳ قرار دادیم که بیانگر همان ۲ بیت برای این داده است.

قطعه ۲ — انتخاب قربانی و افزایش گروهی
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
نکته ی دیگر این است که این افزایش فقط در مسیر miss اتفاق می افتد.

قطعه ۳ — به روزرسانی مشترک برای hit و fill
```cpp
void srrip_set_helper::update(long way, bool hit) { get_rrpv(way) = hit ? 0 : (maxRRPV - 1); }

void srrip::update_replacement_state(..., uint8_t hit)
{
  sets.at(static_cast<std::size_t>(set)).update(way, hit);
}
```
کد `replacement_cache_fill` بازنویسی نشده است و هر دو حالت hit و fill از همین یک تابع استفاده می کنند که برای اینکه بین hit و fill تشخیص دهیم یک `bool hit` که بین این دو انتخاب کند.
در صورتی که hit بشود مقدار به ۰ ریست می شود و در صورتی که fill باشد مقدار جدید برابر `maxRRPV-1` خواهد بود.

BIP:
منطق انتخاب بلوک قربانی:
روش BIP (Bimodal Insertion Policy) عملا روی روش LRU سوار شده است که منطق خارج کردن بلوک از set آن دقیقا مشابه LRU است. صرفا نحوه ی هندل کردن ترتیب بلوک ها بر اساس دسترسی اخیر آنها کمی متفاوت است.
نحوه بروزرسانی اطلاعات کمکی:
در روش LRU در هنگامی که بلوک جدید اضافه می شود، نسبت به بقیه در ترتیب دسترسی بالاتر بود. ولی در این روش هنگامی که بلوک جدید اضافه می شود با یک احتمال مشخص زیادی در ترتیب دسترسی پایینترین خواهد بود (Least Recently Used) که یعنی در خطر خارج شدن است (بر خلاف روش عادی که بلوکی که جدید اضافه می شد کم خطر ترین برای خارج شدن بود) و با یک احتمال متمم مشخص دیگری در ترتیب دسترسی نسبت به بقیه بالاترین خواهد بود (مثل حالت عادی روش LRU).

نحوه ی بروزرسانی اطلاعات پس از برخورد (hit):
در هنگام hit دقیقا مثل LRU عمل می کنیم و برچسب زمان بلوک برابر `cycle` می شود و شمارنده زیاد می شود (باز هم به جز دسترسی های `WRITE`).

نحوه ی بروزرسانی اطلاعات پس از جایگزینی (fill):
بعد از fill کردن، با احتمال ۱/۳۲ برچسب زمان برابر `cycle` می شود (درج در موقعیت MRU، مثل LRU) و با احتمال ۳۱/۳۲ برچسب برابر ۰ قرار می گیرد که یعنی درج در موقعیت LRU. پس به احتمال زیاد بلوک جدید در اولین miss بعدی همان set دوباره خارج می شود و محتوای قدیمی set تقریبا دست نخورده باقی می ماند. آن احتمال کوچک ۱/۳۲ هم برای این است که اگر working set برنامه عوض شد، کش بتواند به تدریج محتوای جدید را بپذیرد و برای همیشه روی داده های قدیمی قفل نشود.

شرایط عملکرد مناسب و نامناسب:
در این روش هم مشکل scan های حلقه ای که از سایز cache اسکن بزرگ تر می شود تا حدی رفع می شود هم اسکن های خطی که داده های بدردنخور اضافه می شود و فقط یکبار استفاده می شوند، چون یک روش میانی بین LRU و MRU است این امکان به وجود میاید. در حالت چون با یک احتمال کمی بعضی داده ها را نگه دارد و خیلی ها را دور می اندازد باعث نمی شود که همه چیز یادمان برود و خیلی چیز ها نگه داشته می شوند، در اسکن های خطی هم داده های یکبار مصرف اکثرا دور ریخته می شوند و اصلا نگه داشته نمی شوند و فقط بخش کمی از آنها نگه داشته می شود.
در جایی بد عمل می کند که کل working set داخل cache جا شود و صرفا بخاطر بدبینی این سیاست خیلی از داده بیرون ریخته شوند.

نکات کد:
قطعه ۱ — مولد تصادفی و پارامتر ε
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
طبق توزیع `dist(0, 31)` و شرطی که در قطعه ی سوم می آید (`== 0`) یعنی احتمال درج در موقعیت MRU دقیقا ۱/۳۲ و احتمال درج در موقعیت LRU برابر ۳۱/۳۲ است. (این همان احتمال هایی است که در توضیح این policy شرح دادیم) این مقدار به صورت رسمی ε و انتخاب آن دلخواه نیست و باید هوشمندانه باشد، ولی مقدار معمولی آن همین است. باید آنقدر کوچک باشد که برای جست و جوی خطی حافظه باعث cache pollution نشود (داده های الکی و اضافه پر نکند) و آنقدر بزرگ باشد که اگر working set برنامه عوض شد، cache بتواند محتوای جدید را کم کم بپذیرد.
برای seed برای رندوم هم `rng(0)` صفر را می دهیم.
بقیه ی ساختار داده دقیقا همان LRU است.

قطعه ۲ — انتخاب قربانی (کاملا مثل LRU)
```cpp
long bip::find_victim(uint32_t, uint64_t, long set, ...)
{
    auto begin = std::next(last_used_cycles.begin(), set * NUM_WAY);
    auto end = std::next(begin, NUM_WAY);

    auto victim = std::min_element(begin, end);
    return std::distance(begin, victim);
}
```
کاملا مشابه LRU برای قربانی عمل می کنیم و منطق پیشرفته تری ندارد.

قطعه ۳ — درج دو حالته
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
فقط منطق fill طبق توضیحی که دادیم فرق می کرد و بقیه کاملا مشابهند.

DRRIP:
منطق انتخاب بلوک قربانی:
در روش DRRIP (Dyanmic RRIP) منطق خارج کردن بلوک دقیقا مشابه روش SRRIP است و تفاوتی ندارد.
نحوه بروزرسانی اطلاعات کمکی:
این روش هم چون یک روش تکمیلی روی SRRIP است تقریبا مشابه عمل می کند به جز قراردادی که در هنگام اضافه کردن بلوک به set دارد. به این صورت عمل می کند که دو تا sub-policy دارد که بین این دوتا به صورت پویا عوض می کند. sub-policy اول به این صورت است که برای بلوک جدیدی که اضافه می شود مثل SRRIP برای مقدار RRPV آن `MAX_RRPV-1` را قرار دهیم. و sub-policy دیگر این است که مثل BIP، با احتمال خیلی زیاد (ممکن است پیاده سازی این مورد به صورت احتمالی نباشد، مثلا در پیاده سازی ما اینطور نیست) مقدار RRPV آن را `MAX_RRPV` قرار دهیم (مرز خروجی)، و با احتمال خیلی کمتر `MAX_RRPV-1` را قرار دهیم. در این روش اینکه کدام یک از این sub-policy ها انتخاب می شود با استفاده از روش set-dueling انجام می شود. به این صورت که ما ۳ نوع دسته داریم: brrip_leader و srrip_leader و follower. برای دسته های srrip_leader و brrip_leader به صورت ثابت به ترتیب از sub_policy های srrip و brrip استفاده می کنیم ولی برای دسته آخر که follower است با توجه به یک شمارنده کلی PSEL انجام می شود. 
هنگام hit هم فارغ از اینکه sub-policy کدام باشد مقدار RRPV به ۰ تنظیم می شود.

[شکل CETZ در main.typ: سازوکار set-dueling و نقش شمارنده ی PSEL در DRRIP — سه دسته ی set (رهبر SRRIP، رهبر BRRIP، follower)، فلش آموزش PSEL از رهبر ها و فلش decide(set) از PSEL به follower ها]

نحوه ی بروزرسانی اطلاعات پس از برخورد (hit):
مستقل از اینکه set از نوع leader است یا follower و مستقل از اینکه کدام sub-policy فعال است، مقدار RRPV بلوکی که hit شده به ۰ ریست می شود. برای دسترسی های `WRITE` به جای ۰ مقدار `maxRRPV - 1` گذاشته می شود تا writeback باعث نشود بلوکی الکی امن به حساب بیاید. نکته ی مهم دیگر این است که در مسیر hit شمارنده ی PSEL دست نمی خورد و آموزش PSEL فقط از روی miss ها انجام می شود.

نحوه ی بروزرسانی اطلاعات پس از جایگزینی (fill):
اول مثل SRRIP، در `find_victim` مقدار RRPV همه ی بلوک های set به اندازه ی لازم زیاد می شود تا قربانی با مقدار بیشینه پیدا شود. بعد از درج بلوک جدید، تابع `decide(set)` مشخص می کند کدام sub-policy اجرا شود: set های leader همیشه سیاست ثابت خودشان (SRRIP یا BRRIP) و set های follower بر اساس مقدار فعلی PSEL. در حالت SRRIP مقدار `maxRRPV - 1` و در حالت BRRIP مقدار `maxRRPV` داده می شود، به جز یک بار در هر ۳۲ درج که به صورت چرخشی مقدار `maxRRPV - 1` می گیرد.
سپس برای خود PSEL داریم: در پایان هر fill تابع `update_bad(set)` صدا زده می شود. چون fill فقط بعد از miss اتفاق می افتد، هر miss در یک leader set شمارنده را به ضرر سیاست همان رهبر حرکت می دهد و بعد از مدتی PSEL به سمت سیاستی می رود که در set های نمونه miss کمتری داشته است. این تنها بخش واقعا پویای این روش است. (شمارنده ی PSEL از روی set های leader یاد می گیرد و مثل دیکتاتور به set های follower غالب می کند)

شرایط عملکرد مناسب و نامناسب:
سیاست DRRIP تقریبا در همه ی شرایط خوب عمل می کند چون به صورت پویا بین دو روش جابه جا می شود. صرفا در جاهایی ممکن است بد عمل کند که working set اینقدر کم باشد که روش فرصت یادگیری نداشته باشد و overkill باشد.

نکات کد:

قطعه ۱ — ثابت ها و شمارنده ی PSEL
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
یک شمارنده ی کلی PSEL با طول ۱۰ بیت داریم. ۳ دسته برای set ها طبق توضیحی که دادیم داریم. و بقیه ی المان های SRRIP و المان های مشابه BIP را نیز مشاهده می کنیم.

قطعه ۲ — دو sub-policy درج
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
در حالت BRRIP بلوک جدید در ۳۱ حالت از هر ۳۲ حالت با مقدار `maxRRPV` اضافه می شود (اینجا یک تفاوت ریز با BIP دارد و آن این است که در BIP این موضوع رندوم بود ولی اینجا به صورت چرخشی و سیکلی است و رندوم نیست، تاثیر عملکردی آن شاید ناچیز باشد و تقریبا یکسان باشند ولی از لحاظ سخت افزاری خیلی ساده تر از رندوم است)، یعنی در مرز خروج قرار می گیرد و اگر تا اولین جست وجوی قربانی استفاده نشود بیرون می رود. فقط یک بار در هر ۳۲ درج، مقدار `maxRRPV - 1` داده می شود تا cache بتواند به تدریج محتوای جدید را نگه دارد.
تابع `update_srrip` دقیقا همان درج SRRIP است و هیچ تفاوتی با آن ندارد.

قطعه ۳ — انتخاب sub-policy در زمان درج
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
تابع `decide(set)` برای set های leader همیشه سیاست فیکس شده ی خودشان را برمی گرداند و برای set های follower را بر اساس مقدار فعلی PSEL تصمیم می گیرد.
تابع `update_bad(set)` در هر fill صدا زده می شود و چون fill فقط بعد از miss اتفاق می افتد، عملا هر miss در یک set رهبر، PSEL را به ضرر سیاست همان رهبر تغییر می دهد. در نتیجه بعد از مدتی PSEL به سمت سیاستی می رود که در set های نمونه miss کمتری داده است. این همان بخش پویای این روش است. اینکه خود تابع `update_bad` چطوری پیاده سازی شده است در فایل های داخلی ChampSim است و خیلی جزیی می شود.

قطعه ۴ — hit و انتخاب قربانی
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
تابع `find_victim` از نظر منطقی دقیقا همان SRRIP است و فقط به جای `std::transform` از یک حلقه استفاده کرده است.
در زمان برخورد، بدون توجه به اینکه کدام sub-policy فعال است، مقدار RRPV به ۰ می رسد.

SHiP:
منطق انتخاب بلوک قربانی:
در روش SHIP (Signature-based Hit Predictor)، کاملا مشابه روش SRRIP مقادیر RRPV به ازای هر بلوک داریم که دقیقا به همان روش SRRIP بلوک هدف را خارج می کنیم.
نحوه بروزرسانی اطلاعات کمکی:
در این policy ما روی مقدار اولیه RRPV که به ازای هر بلوک نسبت می دهیم خلاقیت به خرج می دهیم و سعی می کنیم مقدار هوشمندانه ای برای آن تعیین کنیم. به این صورت که در کنار RRPV یک تگ به اسم signature هم به هر بلوک هنگام اضافه شدن به set به آن می دهیم که بر اساس ناحیه ی حافظه ای است که در آن قرار داشته است یا آدرس حافظه مربوط به آن است (PC) (کلا قرارداد مخصوص به خود دارد، مثلا در کد ما همان PC است). یک جدول به اسم SHCT (Signature History Counter Table) نگه می داریم که به ازای هر signature یک شمارنده دارد که در هر بار دسترسی به بلوک با ان signature خاص شمارنده مربوط به signature در جدول کم می شود. عملا مقدار به ازای هر signature در این جدول بیان می کند که این پترن خاص از حافظه چقدر امکان مجدد بازخواست و دسترسی دارند. هنگام اضافه کردن بلوک به set از این جدول lookup انجام می دهیم و مقدار مربوط به signature این بلوک را می خوانیم، بر اساس این مقدار RRPV را مقداردهی می کنیم. در صورتی که این مقدار کم باشد و یعنی احتمال بازخواست این signature زیاد باشد مقدار RRPV آن را یک چیز کم مثل ۰ یا ۱ می دهیم (البته اینکه در حالت خوب یک مقدار RRPV به آن داده شود در کد نیست و در اولین پیاده سازی های این ایده هم ظاهرا نبوده و در مقالات و ورژن های بعدی که بهبود یافته است ظاهر می شود). و اگر مقدار جدول زیاد باشد و یعنی این signature احتمالا زیاد بازخواست نمی شود مقدار RRPV بالایی مثل `MAX_RRPV` به آن نسبت می دهیم.
در هنگام hit مقدار RRPV بلوک به ۰ ریست می شود و ورودی داخل جدول SHCT که مربوط به signature این بلوک است یکی کم می شود.
در هنگامی که بلوک بدون اینکه یکبار هم hit شده باشد در جدول مقدار مربوط به signature آن یکی زیاد می شود.
نکته ی بسیار مهم این است که این جدول اگر برای تمام set های موجود ذخیره شود سخت افزار خیلی بزرگی می خواهد، پس به جای اینکار ما این را برای تعداد محدودی set انجام می دهیم و به بقیه set ها تعمیم می دهیم. به این sampler می گوییم که چیزی شبیه شبکه عصبی که با یک سری set ها train می شود و روی بقیه تست می شود. به این شکل سخت افزار کمتری مصرف می شود. در جاهای مختلف کد این موضوع تکرار شده ولی چون از توضیحی که دادیم خارج نیست، فرض می کنیم کلا sampler را ندید می گیریم و کلی توضیح می دهیم، پس داخل کد و توضیحات بیشتر جاها منظور ما خود sampler است که در یادگیری استفاده می شود ولی برای ساده سازی به خود جدول اشاره کرده ایم.

[شکل CETZ در main.typ: مسیر پیش بینی و مسیر آموزش جدول SHCT در SHiP — PC → signature → SHCT → مقدار اولیه ی RRPV، و مسیر آموزش از sampler به SHCT]

نحوه ی بروزرسانی اطلاعات پس از برخورد (hit):
ابتدا در cache اصلی مقدار RRPV آن بلوک مثل SRRIP به ۰ ریست می شود و سپس برای train اگر set مورد نظر جزو set های sampler باشد، خانه ی متناظر در جدول SHCT پیدا می شود و مقدار آن یکی کم می شود، چون این hit ثابت می کند که آن signature (یعنی همان PC) داده ای می آورد که واقعا دوباره استفاده می شود. همچنین بیت `used` آن خانه ی sampler برابر true می شود تا بعدا موقع خروج، این بلوک به عنوان "بدرد نخور" جریمه نشود. اگر set جزو نمونه ها نباشد هیچ train ای انجام نمی شود و فقط RRPV ریست می شود.

نحوه ی بروزرسانی اطلاعات پس از جایگزینی (fill):
ابتدا signature بلوک جدید از ۳۲ بیت پایین PC ساخته و با `% SHCT_PRIME` روی جدول مپ می شود و مقدار آن خانه خوانده می شود. اگر شمارنده به بیشینه رسیده باشد (`is_max`، یعنی مقدار ۷) بلوک با `maxRRPV` درج می شود که یعنی همان لحظه در مرز خروج است، وگرنه مقدار پیشفرض `maxRRPV - 1` مثل SRRIP را می گیرد. برای دسترسی های `WRITE` هم بدون هیچ lookup ای همان مقدار امن `maxRRPV - 1` گذاشته می شود.
سپس برای train وقتی در یک set نمونه یک خانه ی sampler بازنویسی می شود، اگر آن خانه بیت `used` نداشته باشد یعنی بلوک قبلی بدون حتی یک بار استفاده خارج شده است، پس شمارنده ی مربوط به signature آن یکی زیاد می شود. بعد خانه با آدرس و PC جدید مقداردهی و `used` دوباره صفر می شود. توجه کنیم که sampler برای خودش یک سیاست LRU مستقل با `last_used` دارد که هیچ ربطی به RRPV های کش اصلی ندارد.

شرایط عملکرد مناسب و نامناسب:
در سیاست SHiP وقتی بهترین عملکرد را دارد که پترن استفاده ی برنامه از یک سری خانه های حافظه مشخص و الگودار باشد، SHiP می تواند این الگو ها را تشخیص بدهد و از آنها استفاده بکند. (عملا استفاده های مجدد از یک سری از خانه های حافظه معنی دار باشند و الگو دار باشند)
چون SHiP هم به مرور یاد می گیرد و جدول SHCT را باید پر کند، کمی شاید فرآیند یادگیری آن طول بکشد به همین دلیل در اوایل شاید خوب عمل نکند. همچنین وقتی که پترن و جنس الگوی دسترسی برنامه عوض می شود، چون جدول هنوز روی پترن قبلی یادگرفته اوایل خوب عمل نمی کند و بندری می زند.

نکات کد:
قطعه ۱ — ساختار sampler و جدول SHCT
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
ساختاد داده SHCT یک جدول با ۱۶۳۸۴ خانه است که هر خانه ی آن یک شمارنده ۳ بیتی است (چون `SHCT_MAX = 7` است).
هر خانه ی sampler یک بیت `used` دارد که می گوید آیا آن بلوک بعد از درج حداقل یک بار استفاده شد یا نه.

قطعه ۲ — آموزش جدول از روی sampler
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
در صورتی که hit داشته باشیم از شمارنده مربوط به آن signature یکی کم می شود و اگر بدون اینکه از بلوک اضافه شده استفاده ی مجدد شود و evict شود شمارنده را یکی زیاد می کنیم.
بخش signature همان ۳۲ بیت پایین PC است که با `% SHCT_PRIME` روی جدول مپ می شود.
بخش sampler برای خودش یک سیاست LRU مستقل دارد که با `last_used` و `access_count` پیاده شده و هیچ ربطی به RRPV های کش اصلی ندارد. یعنی sampler یک کش مجازی کوچک است که فقط برای آموزش نگه داشته می شود.
در صورت hit در cache مقدار RRPV را به ۰ ریست می کند.

قطعه ۳ — استفاده از پیش بینی در زمان درج
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
همان بخش پویا که بر اساس مقدار جدول تصمیم می گیرد که مقدار اولیه RRPV چه باشد. حالت پیشفرض مثل SRRIP مقدار `maxRRPV - 1` است و حالت خیلی بد مقدار `maxRRPV` را به خود می گیرد.
شرط `is_max` همان بررسی حالت خیلی بد است که در صورتی که شمارنده پر شده باشد (یعنی مقدار ۷ را به خود گرفته باشد) فعال می شود.

قطعه ۴ — انتخاب قربانی
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
این تابع عینا همان `find_victim` سیاست های SRRIP و DRRIP است.

## مقایسه سیاست ها روی ردپا ها و پاسخ سوالات مفهومی:

برای تایین عملکرد هر سیاست، از معیار IPC استفاده شده است. چرا که در نهایت، افزایش سرعت کلی برنامه را دقیق‌تر از معیار‌های دیگری نظیر Hit rate نشان می‌دهد.

**سوال ۱:**
عملکرد میانگین هر سیاست در میان همه‌ی رد‌پا‌ها و همه‌ی تعداد setها به این صورت است:

| Strategy | Average IPC | Average IPC/LRU |
|-|-|-|
| bip      | 0.3799      | 1.0269          |
| drrip    | 0.3789      | 1.0244          |
| fifo     | 0.3685      | 0.9962          |
| lru      | 0.3699      | 1.0000          |
| mru      | 0.3630      | 0.9813          |
| random   | 0.3720      | 1.0057          |
| ship     | 0.3807      | 1.0292          |
| srrip    | 0.3769      | 1.0189          |

که این مقادیر بسیار به هم نزدیک هستند. دلیل این اتفاق این است که تاثیر کش‌های لایه‌های بالاتر و باقی سخت‌افزار پردازنده بسیار بیشتر از تاثیر صرفا کش لایه‌ی آخر در سرعت کلی برنامه است. طبق این آمار، سیاست ship با بیشترین مقدار میانگین IPC، در میانگین همه‌ی رد‌پا‌ها بهترین عملکرد را داشته است.

**سوال ۲:**
با توجه به نمودار‌های IPC، مثل در ردپای mcf، سیاست‌های ship،‌ srrip و bip بهترین عملکرد را دارند. ولی ship در ردپای gcc عملکرد بسیار پایینی دارد. همچنین srrip و bip در رد‌پا‌های lbm و omnetpp عملکرد جالبی ندارند. پس می‌توان نتیجه گرفت هیچ سیاست ثابتی بین آنهایی که بررسی شدند، وجود ندارد که در همه‌ی رد‌پا‌ها بهترین باشد.

**سوال ۳:**
با بررسی نمودار‌ها، می‌توان گفت در ردپای gcc، همه‌ی سیاست‌های پیشرفته (ship, srrip, drrip, bip) بهتر از lru عمل کرده‌اند. در مورد ردپای lbm می‌توان گفت که عملکرد سیاست‌های مختلف به شدت به تعداد setها وابسته بوده. به طوری که در تعداد کمتر آن (حدود ۱۰۲۴ یا ۲۰۴۸ ست) تفاوت معناداری بین سیاست‌های پیشرفته‌ی ship, srrip و drrip با lru وجود ندارد و صرفا سیاست bip بوده که بسیار بهتر از آن عمل کرده است. امّا در تعداد ست‌های بیشتر (مثلا ۴۰۹۶)،‌ فقط عملکرد ship و drrip به طور قابل ملاحظه بیشتر از lru است. در مورد ردپای mcf، باز هم همه‌ی سیاست‌های پیشرفته از lru بهتر عمل کرده‌اند. صرفا drrip در تعداد ست‌های پایین مقداری کمتر از بقیه عمل می‌کند. در نهایت در ردپای omnetpp می‌توان گفت که هیچ سیاست پیشرفته‌ای چندان بهتر از lru عمل نکرده است، مگر در تعداد ست‌ها پایینتر (حدود ۱۰۲۴) که باز هم تفاوت خیلی زیادی ندارند.

**سوال ۴:**
با توجه به بخش قبلی و نیز نمودار‌ها می‌توان نتیجه گرفت که فقط در ردپای omnetpp، دو سیاست lru و fifo کفایت می‌کنند و عملکرد بسیار خوبی دارند.

**سوال ۵:**
نه لزوما. اگرچه معمولا کاهش Miss Rate باعث افزایش IPC می‌شود، اما رابطه کاملاً خطی نیست. برای مثال در ردپا‌های SHIP نرخ Miss کمتری نسبت به LRU دارد ولی افزایش IPC آن بسیار اندک است. در بعضی موارد نیز اختلاف زیاد در Miss Rate تنها به افزایش جزئی IPC منجر شده است. دلیل آن این است که IPC علاوه بر کش، به عواملی مانند وابستگی‌های داده، پیش‌بینی انشعاب، اجرای موازی دستورها، و سایر stallهای پردازنده نیز وابسته است. بنابراین کاهش Miss Rate شرط لازم برای افزایش IPC است، اما همیشه شرط کافی نیست.

**سوال ۶:**
سیاست‌هایی مانند BIP، DRRIP و SHIP تلاش می‌کنند رفتار برنامه را هنگام اجرا تشخیص داده و خود را با آن تطبیق دهند. در ردپا‌هایی مانند mcf و lbm این سیاست‌ها توانسته‌اند خطوط مفید را مدت بیشتری در کش نگه دارند و از جایگزینی زودهنگام جلوگیری کنند؛ در نتیجه هم نرخ Miss کاهش یافته و هم IPC افزایش یافته است.
در omnetpp، الگوی دسترسی از قبل با رفتار LRU سازگار بوده است؛ بنابراین سازوکارهای تطبیقی سودی نداشته و حتی سربار تصمیم‌گیری باعث افت جزئی عملکرد می‌شود.
با بزرگ‌تر شدن اندازه کش (از ۱۰۲۴ به ۴۰۹۶ ست)، مزیت سیاست‌های تطبیقی در ردپا‌های ظرفیت‌محور مانند mcf بیشتر نمایان شده است، زیرا فضای بیشتر کش امکان استفاده بهتر از تصمیم‌های هوشمندانه را فراهم کرده است.

### نمودار ها

در این بخش تمام نمودار هایی که تحلیل های بالا بر اساس آنها نوشته شده اند را کنار هم آورده ایم. هر دو دسته هر سه اندازه ی کش (۱۰۲۴ و ۲۰۴۸ و ۴۰۹۶ set) را پوشش می دهند و فقط در اینکه چه چیزی روی محور افقی است با هم فرق دارند.

- مقایسه بر حسب سیاست برای هر سه اندازه ی کش: محور افقی سیاست و هر منحنی یک اندازه ی کش (فایل ها در `figures/policy_on_x/`).
- مقایسه بر حسب تعداد set: محور افقی تعداد set و هر منحنی یک سیاست (فایل ها در `figures/size_on_x/`).

ردپا ها به ترتیب 403.gcc و 429.mcf و 470.lbm و 471.omnetpp هستند و برای هر کدام یک شکل جدا در گزارش آمده است.

## توضیح Trace ها:

در رابطه با trace ها انتخاب شده: trace اول 403.gcc بود و برای آن انتخابش کردیم که همجواری زمانی بالایی داشت. علت هم آن است که مربوط به کامپایلر gcc است کامپایلر بار ها به ساختار های داده یکسان( مثل جدول نماد ها و …) دسترسی میخواهد بنابراین بلوک های کشی که به تازگی به از آنها استفاده شده، احتمالا دوباره از آنها استفاده خواهد شد و همانطور هم که در نمودار ها مشخص است و مورد انتظار ماست، سیاست LRU عملکرد خیلی خوبی روی آن داشته است.

ردپای دوم 429.mcf بود و علت انتخاب این بود که همجواری مکانی بالایی داشت. علت این اتفاق هم این است که این ردپا مربوط به حل مسایل بهینه سازی شبکه است و حجم خیلی زیادی داده را در حافظه پردازش میکند. این دسترسی ها معمولا به آدرس های مجاور هستند و برای همین همجواری مکانی در آن مهم است. یک نکته دیگر هم این است که به خاطر دسترسی های زیاد به حافظه، تاثیر اندازه کش در آن به خوبی محسوس است که در نمودار ها هم قابل مشاهده است.

ردپای سوم 470.lbm بود و علت انتخاب این بود که رفتار جریانی را درون خود دارد. این برنامه مربوط به شبیه سازی دینامیک سیالات است و داده ها را عمدتا به صورت ترتیبی و یک بار مصرف پردازش می کند. بنابراین پس از دسترسی به یک بلوک حافظه، احتمال استفاده مجدد از آن بسیار کم است. بنابراین این ردپا نمونه ی خوبی از رفتار جریانی محسوب می‌شود و همانطور که در نمودار ها واضح است hit rate برای برخی از سیاست ها بسیار پایین است که مطابق انتظار ماست.

ردپای آخر هم 471.omnetpp بود و برای این انتخاب شد که بین سیاست های جایگزینی تفاوت قابل قبولی قایل میشد. چرا که این ردپا مربوط به شبیه سازی شبکه های کامپیوتری است. الگوی دسترسی آن به نسبت پیچیده است و مجموعه داده های فعال آن به گونه ای است که انتخاب بلوک برای جایگزینی می‌تواند تاثیر قابل توجهی بر نرخ برخورد و عملکرد سیستم داشته باشد. این مورد هم دقیقا روی نمودار ها قابل مشاهده است و بین سیاست ها تفاوت وجود دارد.

نکته دیگر درباره شبیه سازی ها این است که تمام ۹۶ شبیه سازی، با ۱۲۵۰۰۰۰۰ دستور گرم سازی و ۵۰۰۰۰۰۰۰ دستور شبیه سازی انجام شد. این اتفاق خوبی بود که تمام شبیه سازی ها با تعداد دستور یکسان اجرا شدند زیرا باعث عدالت شد و تعداد دستورات هم مقدار زیادی بود تا به خوبی سیاست های مختلف روی ردپا های مختلف مورد آزمایش قرار بگیرند و تفاوت میان ردپا ها قابل حس باشد ولی طبیعتا به خاطر اینکه ردپا های مختلف داشیم، تفاوت زمانی بین شبیه سازی ها دیده میشود. مثلا شبیه سازی ها با این تعداد دستور روی ردپای 428.mcf حدود +۲۰ دقیقه زمان میبرد در حالی که بقیه شبیه سازی ها معمولا زیر ۱۰ دقیقه بودند و  علت آن هم طبیعتا نوع متفاوت ردپاهاست و همانطور که گفته شده بود ردپای 429.mcf خیلی به حافظه دسترسی دارد( تعداد دسترسی ها همانطور که در llc_results مشاهده میشود برای این ردپا بیشتر از بقیه است) بنابراین نسبت به بقیه ردپا ها خیلی بیشتر در llc خطا داریم و از آنجا که خطا در llc پنالتی خیلی زیادی دارد، باعث طولانی تر شدن شبیه سازی در این ردپا در مقایسه با بقیه شده است. میانگین دسترسی به llc در بقیه نزدیک به هم هستند و فقط 471.omnetpp مقدار کمی از بقیه کمتر به llc دسترسی دارد و همین مورد هم سبب این شده که این ردپا هم کمی نسبت به بقیه زمان کمتری بگیرد

## تحلیل پیچیدگی و هزینه‌ی سخت‌افزاری هر Policy:

در گام‌های قبل سیاست‌ها را از نظر کارایی (نرخ برخورد و IPC) با هم مقایسه کردیم. اما در عمل، انتخاب یک سیاست جایگزینی فقط به کارایی آن وابسته نیست؛ هر سیاست برای پیاده‌سازی روی سخت‌افزار واقعی هزینه‌ای دارد که شامل بیت‌های کمکی ذخیره‌شده به ازای هر خط کش، نیاز به شمارنده‌های سراسری، و پیچیدگی منطق انتخاب قربانی و به‌روزرسانی وضعیت است. در این بخش هر هشت سیاست را از این پنج جنبه بررسی می‌کنیم و در پایان جمع‌بندی می‌کنیم که با توجه به داده‌های به‌دست‌آمده، کدام سیاست از نظر نسبت کارایی به هزینه انتخاب بهتری است.

 در پیاده‌سازی ما بسیاری از سیاست‌ها برای سادگی از یک برچسب زمانی پهن (`uint64_t`) استفاده می‌کنند؛ برای مثال LRU به ازای هر خط یک شمارنده‌ی زمانی ۶۴بیتی نگه می‌دارد. این کار در یک شبیه‌ساز نرم‌افزاری کاملاً منطقی است، ولی در سخت‌افزار واقعی هیچ‌کس ۶۴بیت به ازای هر خط خرج نمی‌کند. بنابراین در ستون بیت‌های کمکی ما هزینه‌ی **سخت‌افزاری ایده‌آل** (یعنی حداقل بیت لازم در یک پیاده‌سازی واقعی) را گزارش می‌کنیم و در صورت تفاوت، به پیاده‌سازی خودمان هم اشاره می‌کنیم. فرض ما یک کش ۱۶راهه است (مطابق پیکربندی پایه)، پس هر خط برای نگه‌داری ترتیب کامل به اندازه‌ی `⌈log₂(16)⌉ = ۴` بیت نیاز دارد.

 باید بین دو نوع شمارنده‌ی سراسری تفاوت قائل شویم. برخی سیاست‌ها مثل DRRIP به یک شمارنده‌ی سراسری **الگوریتمی** (مثل PSEL) نیاز دارند که بخشی از منطق تصمیم‌گیری سیاست است. اما در پیاده‌سازی نرم‌افزاری ما، سیاست‌های مبتنی بر برچسب زمان (LRU، FIFO، MRU، BIP) هم یک شمارنده‌ی `cycle` سراسری دارند که صرفاً برای تولید برچسب‌های زمانی افزایشی استفاده می‌شود. این شمارنده یک جزء ذاتی الگوریتم نیست و در سخت‌افزار واقعی با روش‌های دیگری (مثل جابه‌جایی ترتیب در خود مجموعه) قابل حذف است. در جدول، این تفاوت را مشخص کرده‌ایم.

### جدول مقایسه‌ی کلی

| سیاست | بیت کمکی هر خط (ایده‌آل) | شمارنده‌ی سراسری | پیچیدگی انتخاب قربانی | پیچیدگی به‌روزرسانی | مناسب سخت‌افزار؟ |
|---|---|---|---|---|---|
| **Random** | ۰ | ندارد (فقط مولد شبه‌تصادفی) | حداقلی: یک عدد تصادفی | ندارد | بله، ارزان‌ترین |
| **FIFO** | ۴ بیت (ترتیب ورود) | فقط شمارنده‌ی زمان (نه الگوریتمی) | کم: کوچک‌ترین برچسب ورود | فقط هنگام درج (نه در hit) | بله |
| **LRU** | ۴ بیت (ترتیب دسترسی) | فقط شمارنده‌ی زمان (نه الگوریتمی) | کم: کوچک‌ترین برچسب زمان | در هر hit و هر درج | نسبتاً؛ به‌روزرسانی پرهزینه |
| **MRU** | ۴ بیت (مثل LRU) | فقط شمارنده‌ی زمان (نه الگوریتمی) | کم: بزرگ‌ترین برچسب زمان | مثل LRU | مثل LRU |
| **SRRIP** | ۲ بیت (RRPV) | ندارد | متوسط: یافتن RRPV=۳ و افزایش گروهی | مقدار ثابت در hit و درج | بله، بسیار مناسب |
| **BIP** | ۴ بیت (مثل LRU) | شمارنده‌ی زمان + مولد تصادفی | مثل LRU | درج دوحالته (۱٬۳۲) | بله |
| **DRRIP** | ۲ بیت (RRPV) | شمارنده‌ی PSEL ۱۰بیتی هر هسته | مثل SRRIP | SRRIP/BRRIP + به‌روزرسانی PSEL | بله، سربار کم |
| **SHiP** | ۲ بیت RRPV + امضا هر خط | جدول SHCT با ۱۶۳۸۴ شمارنده‌ی ۳بیتی + sampler | مثل SRRIP | جست‌وجو و به‌روزرسانی جدول SHCT | نسبتاً؛ پرهزینه‌ترین |

### بررسی سیاست به سیاست

Random

این ارزان‌ترین سیاست ممکن است. هیچ اطلاعات کمکی به ازای هر خط ذخیره نمی‌کند (صفر بیت) و هیچ شمارنده‌ی سراسری‌ای ندارد؛ تنها به یک مولد شبه‌تصادفی نیاز دارد. انتخاب قربانی صرفاً تولید یک عدد در بازه‌ی `[0, ways-1]` است و هیچ تابع به‌روزرسانی‌ای ندارد (در کد ما فقط `find_victim` نوشته شده است). از نظر سخت‌افزاری بی‌رقیب است، ولی چون هیچ اطلاعاتی از رفتار برنامه نگه نمی‌دارد، کارایی آن قابل پیش‌بینی نیست.

FIFO

به ازای هر خط یک برچسب ترتیب ورود نگه می‌دارد (در پیاده‌سازی ما `uint64_t`، ولی به‌طور ایده‌آل حدود ۴ بیت کافی است) و یک شمارنده‌ی زمان مشترک برای ثبت ترتیب ورود دارد. نکته‌ی مهم این است که تابع به‌روزرسانی آن **خالی** است: در هنگام hit هیچ کاری انجام نمی‌دهد و برچسب فقط در زمان درج ثبت می‌شود. به همین دلیل هزینه‌ی به‌روزرسانی آن از LRU کمتر است، ولی چون به دسترسی‌های مکرر بی‌توجه است، کارایی ضعیف‌تری دارد.

LRU

به ازای هر خط یک برچسب زمان دسترسی نگه می‌دارد (ایده‌آل: ۴ بیت). شمارنده‌ی سراسری آن فقط برای تولید برچسب زمان است و جزئی از منطق تصمیم‌گیری نیست. انتخاب قربانی ساده است (کوچک‌ترین برچسب)، اما نکته‌ی اصلی هزینه‌ی آن در **به‌روزرسانی** است: در هر بار hit باید ترتیب دسترسی خط به‌روز شود. در سخت‌افزار واقعی، نگه‌داری ترتیب کامل LRU برای درجه‌ی همنشینی بالا پرهزینه است و معمولاً از تقریب‌های آن (مثل Pseudo-LRU) استفاده می‌شود. به همین دلیل LRU با اینکه مبنای مقایسه‌ی ماست، لزوماً ارزان‌ترین گزینه نیست.

MRU

از نظر سخت‌افزاری دقیقاً هم‌هزینه‌ی LRU است؛ تنها تفاوت آن استفاده از `max_element` به‌جای `min_element` در انتخاب قربانی است. بنابراین همان ۴ بیت به ازای هر خط و همان منطق به‌روزرسانی را دارد. هزینه‌ی اضافه‌ای نسبت به LRU ندارد، ولی همان‌طور که در داده‌ها دیدیم در بیشتر ردپاها کارایی بسیار پایینی دارد.

SRRIP

از نظر نسبت کارایی به هزینه یکی از بهترین‌هاست. تنها **۲ بیت** به ازای هر خط نیاز دارد (مقدار RRPV با `maxRRPV=3`) و هیچ شمارنده‌ی سراسری‌ای ندارد. این نکته جالب است که SRRIP هم **کم‌بیت‌تر** از LRU است (۲ بیت در برابر ۴ بیت) و هم در بیشتر ردپاها کارایی بهتری دارد. انتخاب قربانی کمی پیچیده‌تر است چون ممکن است لازم باشد RRPV همه‌ی خطوط تا رسیدن یکی به مقدار بیشینه افزایش یابد (که در کد ما با یک `transform` جبری به‌جای حلقه پیاده شده تا ارزان‌تر باشد)، ولی به‌روزرسانی آن بسیار ساده است: در hit مقدار صفر و در درج مقدار `maxRRPV-1`. از نظر سخت‌افزاری بسیار مناسب است.

BIP

ساختار داده‌ی آن دقیقاً مثل LRU است (۴ بیت به ازای هر خط) و انتخاب قربانی آن هم عیناً مثل LRU است. تفاوت فقط در منطق درج است: با احتمال ۱٬۳۲ بلوک جدید را در موقعیت MRU و با احتمال ۳۱٬۳۲ در موقعیت LRU قرار می‌دهد. بنابراین سربار سخت‌افزاری اضافه‌ی آن تنها یک مولد تصادفی کوچک و پارامتر ε است. پیچیدگی آن کمی بیشتر از LRU خام است ولی همچنان کاملاً مناسب سخت‌افزار است.

DRRIP

روی SRRIP سوار شده و همان **۲ بیت** RRPV به ازای هر خط را دارد. هزینه‌ی سراسری اضافه‌ی آن یک **شمارنده‌ی PSEL ۱۰بیتی به ازای هر هسته** است (در کد ما `PSEL_WIDTH=10`) به‌همراه منطق دسته‌بندی مجموعه‌ها به سه گروه (رهبر SRRIP، رهبر BRRIP، و follower). این هزینه‌ی سراسری بسیار ناچیز است: تنها ۱۰ بیت برای کل کش، در برابر ۲ بیت در هر تک‌تک خطوط. انتخاب قربانی مثل SRRIP است و به‌روزرسانی، علاوه بر منطق SRRIP/BRRIP، شامل به‌روز کردن PSEL در مجموعه‌های رهبر است. نکته‌ی جالب سخت‌افزاری این است که BRRIP در پیاده‌سازی ما به‌جای احتمالی بودن، **چرخه‌ای** پیاده شده (هر ۳۲ درج یک بار)، که از نظر عملکردی تقریباً یکسان ولی از نظر سخت‌افزاری ساده‌تر از یک مولد تصادفی است.

SHiP

پرهزینه‌ترین سیاست از نظر سخت‌افزاری است. علاوه بر ۲ بیت RRPV به ازای هر خط، به یک **امضا (signature)** به ازای هر خط نیاز دارد (در کد ما مشتق‌شده از PC) و مهم‌تر از آن، یک **جدول سراسری SHCT با ۱۶۳۸۴ خانه** که هر خانه یک شمارنده‌ی ۳بیتی است (`MAX_SHCT=7`). این جدول به‌تنهایی حجم قابل‌توجهی سخت‌افزار می‌طلبد. برای کاهش این هزینه، پیاده‌سازی به‌جای رصد همه‌ی مجموعه‌ها فقط تعداد محدودی مجموعه را به‌عنوان **sampler** رصد می‌کند و نتیجه را به بقیه تعمیم می‌دهد؛ ولی حتی با این ترفند، SHiP همچنان بیشترین بیت کمکی و پیچیده‌ترین منطق به‌روزرسانی (جست‌وجو، آموزش و به‌روزرسانی جدول) را دارد. انتخاب قربانی آن اما دقیقاً مثل SRRIP ساده است؛ همه‌ی هزینه در منطق پیش‌بینی و به‌روزرسانی جدول است.

### جمع‌بندی: کارایی در برابر سادگی

اگر **تنها کارایی** مهم باشد، انتخاب ما به اندازه‌ی کش بستگی دارد و این نکته‌ی جالبی است که در داده‌های ما دیده می‌شود:

- در کش‌های بزرگ‌تر (۴۰۹۶ مجموعه)، سیاست‌های پیشرفته‌ی تطبیقی بهترین عملکرد را دارند: به‌طور میانگین SHiP با بهبود حدود ۹ درصد و DRRIP با حدود ۸ درصد نسبت به LRU در صدر قرار می‌گیرند. در این حالت، هزینه‌ی سخت‌افزاری بالای SHiP توجیه می‌شود.
- در کش‌های کوچک‌تر (۱۰۲۴ و ۲۰۴۸ مجموعه)، جالب اینکه **BIP** با وجود سادگی، به‌طور میانگین بهترین بهبود (حدود ۴ درصد) را دارد و از SHiP و DRRIP هم جلو می‌زند.

بنابراین اگر صرفاً کارایی مهم باشد و کش بزرگ باشد، **SHiP یا DRRIP** را انتخاب می‌کنیم.

اما اگر **سادگی سخت‌افزاری هم مهم باشد**، انتخاب ما تغییر می‌کند. در این حالت **DRRIP** گزینه‌ی بسیار جذابی است: تقریباً تمام قابلیت تطبیق‌پذیری SHiP را دارد ولی به‌جای یک جدول ۱۶۳۸۴خانه‌ای و امضا به ازای هر خط، تنها به ۲ بیت در هر خط و یک شمارنده‌ی ۱۰بیتی سراسری نیاز دارد. اگر بخواهیم از این هم ساده‌تر برویم، **SRRIP** با تنها ۲ بیت به ازای هر خط و بدون هیچ شمارنده‌ی سراسری، بخش بزرگی از بهبود را با کمترین هزینه‌ی ممکن به دست می‌آورد و حتی از LRU هم کم‌بیت‌تر است.

جمع‌بندی نهایی ما این است: **DRRIP نقطه‌ی تعادل بهینه بین کارایی و هزینه‌ی سخت‌افزاری است.** SHiP سقف کارایی را کمی بالاتر می‌برد ولی با هزینه‌ی سخت‌افزاری به‌مراتب بیشتر، و SRRIP ساده‌ترین انتخاب منطقی برای شرایطی است که بودجه‌ی سخت‌افزاری محدود است.


## نحوه ی اجرا و خروجی گرفتن پروژه:

کل فرایند اجرا با سه اسکریپت داخل پوشه ی `scripts` انجام می شود که به ترتیب پشت سر هم اجرا می شوند: اول ساخت باینری ها، بعد اجرای شبیه سازی ها و در آخر استخراج نتایج از log ها. برای هر کانفیگ cache مجبوریم یک بیلد جدا بگیریم چون ChampSim اینطوری برنامه نویسی شده است.

اسکریپت `make_bins.sh` — ساخت باینری ها

این اسکریپت به ازای هر ترکیب از تعداد set و replacement policy یک باینری جدا می سازد. لیست مقادیر آن سه اندازه ی ۱۰۲۴ و ۲۰۴۸ و ۴۰۹۶ برای set و هشت سیاست `lru`، `mru`، `random`، `fifo`، `ship`، `srrip`، `drrip` و `bip` است و تعداد way در همه ی حالت ها روی ۱۶ ثابت می ماند. در هر تکرار حلقه، با استفاده از `jq` سه فیلد `LLC.sets` و `LLC.ways` و `LLC.replacement` در فایل `champsim_config.json` بازنویسی می شود، بعد پوشه ی `.csconfig` پاک و با `config.sh` سورس ها دوباره تولید می شوند و در نهایت `make` اجرا می شود. باینری ساخته شده با نام گذاری `champsim_llc_<sets>s_<ways>w_<policy>` داخل پوشه ی `bin` ذخیره می شود تا بعدا در نتایج قابل تشخیص باشد. در مجموع ۳ × ۸ = ۲۴ باینری ساخته می شود.

اسکریپت `run_all.sh` — اجرای شبیه سازی ها

این اسکریپت روی تمام باینری های داخل `bin` حلقه می زند و هر کدام را روی هر چهار ردپای انتخاب شده (`403.gcc` و `429.mcf` و `470.lbm` و `471.omnetpp`) اجرا می کند، یعنی ۲۴ × ۴ = ۹۶ شبیه سازی که همان عددی است که در بخش ردپا ها به آن اشاره کردیم. تعداد دستورات هم برای همه یکسان و به صورت `--warmup-instructions=12500000` و `--simulation-instructions=50000000` تنظیم شده است. خروجی هر اجرا در فایلی با اسم `logs/<binary>_<trace>.log` ذخیره می شود. برای اینکه اجرای کل مجموعه بیش از حد طول نکشد، شبیه سازی ها به صورت موازی و در پس زمینه اجرا می شوند و متغیر `MAX_JOBS` تعداد اجرا های همزمان را به ۸ محدود می کند (مقدار معقول باید باشد که کل هسته های CPU درگیر نشوند که زمان اجرای آنها روی هم تاثیر بگذارد) حلقه ی انتظار داخل اسکریپت تا وقتی که تعداد job های در حال اجرا به زیر این حد نرسد اجرای جدید شروع نمی کند.

اسکریپت `ex_info.sh` — استخراج نتایج

بعد از تمام شدن شبیه سازی ها، این اسکریپت تمام فایل های داخل `logs` را می خواند و از هر کدام سه عدد مورد نیاز ما را بیرون می کشد: از خط `cpu0->LLC TOTAL` مقادیر `ACCESS` و `HIT` و از آخرین خط `cumulative IPC` مقدار IPC نهایی.نتیجه به صورت یک فایل `llc_results.csv` با ستون های `Binary,LLC_Access,LLC_Hit,IPC` نوشته می شود که همان فایلی است که تمام نمودار ها و تحلیل های این گزارش از روی آن ساخته شده اند. نرخ برخورد هم از تقسیم `LLC_Hit` بر `LLC_Access` به دست می آید.


## مراجع

[^wiki-repl]: Cache replacement policies — Wikipedia. <https://en.wikipedia.org/wiki/Cache_replacement_policies>
[^champsim]: N. Gober et al., "The Championship Simulator: Architectural Simulation for Education and Competition", 2022. <https://arxiv.org/abs/2210.14324> — مخزن کد: <https://github.com/ChampSim/ChampSim>
[^spec]: DPC-3 ChampSim Trace Repository: SPEC CPU2006 Traces — The 3rd Data Prefetching Championship (DPC-3), hosted by the COMPAS Lab, Stony Brook University. <https://dpc3.compas.cs.stonybrook.edu/champsim-traces/speccpu/>




[REMOVE THIS SECTION IN THE FINAL TYPST]
تمام فعل ها و اشاره ها باید به صورت "ما" باشد نه "من".
تمام اعداد داخل متن های فارسی باید فارسی باشند. به جز این باید انگلیسی باشند.
برای بخش SHiP و DRRIP از CETZ برای نمایش نمودار تاثیر گذاری و شکل کلی استفاده شود.