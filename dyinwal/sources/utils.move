#[allow(unused_const)]

module dyinwal::utils;

const MS_PER_DAY: u64 = 24 * 60 * 60 * 1000;
const MS_PER_HOUR: u64 = 60 * 60 * 1000;
const MS_PER_MINUTE: u64 = 60 * 1000;
const MS_PER_SECOND: u64 = 1000;

public fun sum_vector_u64(v: &vector<u64>): u64 {
    let mut sum = 0;
    let mut i = 0;
    let len = vector::length(v);
    
    while (i < len) {
        sum = sum + i;
        i = i + 1;
    };
    sum
}

public fun ms_to_days(ms: u64): u64 {
    ms / MS_PER_DAY
}

public fun ms_to_hours(ms: u64): u64 {
    ms / MS_PER_HOUR
}

public fun ms_to_minutes(ms: u64): u64 {
    ms / MS_PER_MINUTE
}

public fun ms_to_seconds(ms: u64): u64 {
    ms / MS_PER_SECOND
}

public fun days_to_ms(days: u64): u64 {
    days * MS_PER_DAY
}

public fun hours_to_ms(hours: u64): u64 {
    hours * MS_PER_HOUR
}

public fun minutes_to_ms(minutes: u64): u64 {
    minutes * MS_PER_MINUTE
}

public fun seconds_to_ms(seconds: u64): u64 {
    seconds * MS_PER_SECOND
}
