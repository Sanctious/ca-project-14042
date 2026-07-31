#include "bip.h"

#include <algorithm>
#include <cassert>

bip::bip(CACHE* cache)
    : bip(cache, cache->NUM_SET, cache->NUM_WAY)
{
}

bip::bip(CACHE* cache, long sets, long ways)
    : replacement(cache),
      NUM_WAY(ways),
      last_used_cycles((std::size_t)(sets * ways), 0),
      rng(0),
      dist(0, 31)        // 1/32 probability
{
}

long bip::find_victim(uint32_t,
                      uint64_t,
                      long set,
                      const champsim::cache_block*,
                      champsim::address,
                      champsim::address,
                      access_type)
{
    auto begin = std::next(last_used_cycles.begin(), set * NUM_WAY);
    auto end = std::next(begin, NUM_WAY);

    auto victim = std::min_element(begin, end);

    assert(victim >= begin);
    assert(victim < end);

    return std::distance(begin, victim);
}

void bip::replacement_cache_fill(uint32_t,
                                 long set,
                                 long way,
                                 champsim::address,
                                 champsim::address,
                                 champsim::address,
                                 access_type)
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

void bip::update_replacement_state(uint32_t,
                                   long set,
                                   long way,
                                   champsim::address,
                                   champsim::address,
                                   champsim::address,
                                   access_type type,
                                   uint8_t hit)
{
    if (hit && type != access_type::WRITE)
    {
        last_used_cycles[(std::size_t)(set * NUM_WAY + way)] = cycle++;
    }
}