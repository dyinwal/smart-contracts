#[allow(unused_field, unused_const)]

module dyinwal::payment_term;

use dyinwal::utils;
use std::debug;
use std::string::{Self, String};
use sui::clock::{Self, Clock};

// === Constants ===

const PAYMENT_TERM_NET: u64 = 0;
const PAYMENT_TERM_END_OF_MONTH: u64 = 1;
const PAYMENT_TERM_DISCOUNTED_NET: u64 = 2;
const PAYMENT_TERM_PARTIAL_PAYMENT: u64 = 3;
const PAYMENT_TERM_INSTALLMENT: u64 = 4;
const PAYMENT_TERM_PAYMENT_IN_ADVANCE: u64 = 5;
const PAYMENT_TERM_CASH_ON_DELIVERY: u64 = 6;
const PAYMENT_TERM_LATE_FEE: u64 = 7;

const ENotImplemented: u64 = 0;
const EInvalidPaymentTerm: u64 = 1;
const EInvalidPaymentTermDetails: u64 = 2;
const EInvalidPaymentTermType: u64 = 3;
const EInvalidPaymentTermDetailsType: u64 = 4;
const EInvalidPaymentTermDetailsValue: u64 = 5;

// === Structs ===

/// "Net D": Payment due in D days
public struct Net has copy, drop, store {
    days: u64,
}

/// "EOM + D": Payment due in D days after the end of the month
public struct EndOfMonth has copy, drop, store {
    days_after_month_end: u64,
}

/// "X/Y Net D": X% discount if paid within Y days, otherwise full amount due in D days
public struct DiscountedNet has copy, drop, store {
    discount_percent: u64,
    discount_days: u64,
    net_days: u64,
}

/// "PP X% D": X% of the total amount due in D days, remaining amount due later
public struct PartialPayment has copy, drop, store {
    percent: u64,
    due_date: u64,
}

/// "INST P1 P2 ...": P1% due on date 1, P2% due on date 2, etc.
public struct Installment has copy, drop, store {
    percent_per_installment: vector<u64>,
    period: u64,
}

/// "CIA X%" - X% payment required in advance
public struct PaymentInAdvance has copy, drop, store {
    percent: u64,
}

/// "Late X% After D" - X% penalty applied after D overdue days
public struct LateFee has copy, drop, store {
    percent: u64,
    days_after_due: u64,
}

public struct PaymentTermDetails has copy, drop, store {
    net: Option<Net>,
    end_of_month: Option<EndOfMonth>,
    discounted_net: Option<DiscountedNet>,
    partial_payment: Option<PartialPayment>,
    installment: Option<Installment>,
    payment_in_advance: Option<PaymentInAdvance>,
    late_fee: Option<LateFee>,
}

public struct PaymentTerm has copy, drop, store {
    term_type: u64,
    details: PaymentTermDetails,
}

// === Public Functions ===

/// Create a new empty payment term
public fun new(term_type: u64): PaymentTerm {
    assert!(term_type < PAYMENT_TERM_LATE_FEE, EInvalidPaymentTerm);
    let details = PaymentTermDetails {
        net: option::none(),
        end_of_month: option::none(),
        discounted_net: option::none(),
        partial_payment: option::none(),
        installment: option::none(),
        payment_in_advance: option::none(),
        late_fee: option::none(),
    };
    let payment_term = PaymentTerm {
        term_type,
        details,
    };

    payment_term
}

public fun create_payment_term_details(
    net_days: Option<u64>,
    discount_percent: Option<u64>,
    discount_days: Option<u64>,
    days_after_month_end: Option<u64>,
    percent: Option<u64>,
    due_date: Option<u64>,
    percent_per_installment: Option<vector<u64>>,
    period: Option<u64>,
): PaymentTermDetails {
    let net = if (option::is_some(&net_days)) {
        let days = option::borrow(&net_days);
        let net = Net {
            days: *days,
        };
        option::some(net)
    } else {
        option::none()
    };

    let end_of_month = if (option::is_some(&days_after_month_end)) {
        let days_after_month_end = option::borrow(&days_after_month_end);
        let end_of_month = EndOfMonth {
            days_after_month_end: *days_after_month_end,
        };
        option::some(end_of_month)
    } else {
        option::none()
    };

    let discounted_net = if (
        option::is_some(&discount_percent) && option::is_some(&discount_days)
    ) {
        let discount_percent = option::borrow(&discount_percent);
        let discount_days = option::borrow(&discount_days);
        let net_days = option::borrow(&net_days);
        let discounted_net = DiscountedNet {
            discount_percent: *discount_percent,
            discount_days: *discount_days,
            net_days: *net_days,
        };
        option::some(discounted_net)
    } else {
        option::none()
    };

    let partial_payment = if (option::is_some(&percent) && option::is_some(&due_date)) {
        let percent = option::borrow(&percent);
        let due_date = option::borrow(&due_date);
        let partial_payment = PartialPayment {
            percent: *percent,
            due_date: *due_date,
        };
        option::some(partial_payment)
    } else {
        option::none()
    };

    let installment = if (option::is_some(&percent_per_installment) && option::is_some(&period)) {
        let percent_per_installment = option::borrow(&percent_per_installment);
        let period = option::borrow(&period);
        let installment = Installment {
            percent_per_installment: *percent_per_installment,
            period: *period,
        };
        option::some(installment)
    } else {
        option::none()
    };

    let payment_in_advance = if (option::is_some(&percent)) {
        let percent = option::borrow(&percent);
        let payment_in_advance = PaymentInAdvance {
            percent: *percent,
        };
        option::some(payment_in_advance)
    } else {
        option::none()
    };

    let late_fee = if (option::is_some(&percent) && option::is_some(&due_date)) {
        let percent = option::borrow(&percent);
        let days_after_due = option::borrow(&due_date);
        let late_fee = LateFee {
            percent: *percent,
            days_after_due: *days_after_due,
        };
        option::some(late_fee)
    } else {
        option::none()
    };

    PaymentTermDetails {
        net,
        end_of_month,
        discounted_net,
        partial_payment,
        installment,
        payment_in_advance,
        late_fee,
    }
}

public fun set_payment_term(
    payment_term: &mut PaymentTerm,
    term_type: u64,
    details: PaymentTermDetails,
) {
    assert!(term_type < PAYMENT_TERM_LATE_FEE, EInvalidPaymentTerm);

    match (term_type) {
        PAYMENT_TERM_NET => {
            assert!(option::is_some(&details.net), EInvalidPaymentTermDetails);
        },
        PAYMENT_TERM_END_OF_MONTH => {
            assert!(option::is_some(&details.end_of_month), EInvalidPaymentTermDetails);
        },
        PAYMENT_TERM_DISCOUNTED_NET => {
            assert!(option::is_some(&details.discounted_net), EInvalidPaymentTermDetails);
        },
        PAYMENT_TERM_PARTIAL_PAYMENT => {
            assert!(option::is_some(&details.partial_payment), EInvalidPaymentTermDetails);
        },
        PAYMENT_TERM_INSTALLMENT => {
            assert!(option::is_some(&details.installment), EInvalidPaymentTermDetails);
        },
        PAYMENT_TERM_PAYMENT_IN_ADVANCE => {
            assert!(option::is_some(&details.payment_in_advance), EInvalidPaymentTermDetails);
        },
        PAYMENT_TERM_LATE_FEE => {
            assert!(option::is_some(&details.late_fee), EInvalidPaymentTermDetails);
        },
        _ => {},
    };

    payment_term.term_type = term_type;
    payment_term.details = details;
}

public fun get_payment_term_details(payment_term: &PaymentTerm): PaymentTermDetails {
    payment_term.details
}

public fun get_payment_term_net_details(payment_term: &PaymentTerm): (u64) {
    let net = option::borrow(&payment_term.details.net);
    let days = net.days;

    days
}

public fun get_payment_term_end_of_month_details(payment_term: &PaymentTerm): (u64) {
    let end_of_month = option::borrow(&payment_term.details.end_of_month);
    let days_after_month_end = end_of_month.days_after_month_end;

    days_after_month_end
}

public fun get_payment_term_discounted_net_details(payment_term: &PaymentTerm): (u64, u64) {
    let discounted_net = option::borrow(&payment_term.details.discounted_net);
    let net_days = discounted_net.net_days;
    let discount_percent = discounted_net.discount_percent;

    (net_days, discount_percent)
}

public fun get_payment_term_partial_payment_details(payment_term: &PaymentTerm): (u64, u64) {
    let partial_payment = option::borrow(&payment_term.details.partial_payment);
    let percent = partial_payment.percent;
    let due_date = partial_payment.due_date;

    (percent, due_date)
}

public fun get_payment_term_installment_details(payment_term: &PaymentTerm): (vector<u64>, u64) {
    let installment = option::borrow(&payment_term.details.installment);
    let percent_per_installment = installment.percent_per_installment;
    let period = installment.period;

    (percent_per_installment, period)
}

public fun get_payment_term_payment_in_advance_details(payment_term: &PaymentTerm): (u64) {
    let payment_in_advance = option::borrow(&payment_term.details.payment_in_advance);
    let percent = payment_in_advance.percent;

    percent
}

public fun get_payment_term_late_fee_details(payment_term: &PaymentTerm): (u64, u64) {
    let late_fee = option::borrow(&payment_term.details.late_fee);
    let percent = late_fee.percent;
    let days_after_due = late_fee.days_after_due;

    (percent, days_after_due)
}

public fun get_payment_term_type(payment_term: &PaymentTerm): u64 {
    payment_term.term_type
}

public fun check_payment_term(
    creation_date: u64,
    due_date: u64,
    subtotal: u64,
    payment_term: &PaymentTerm,
    ctx: &TxContext,
): (bool, u64) {
    assert!(due_date >= creation_date, 0);

    return match (payment_term.term_type) {
        PAYMENT_TERM_NET => {
            if (option::is_none(&payment_term.details.net)) {
                return (false, subtotal)
            };
            let net = option::borrow(&payment_term.details.net);
            let days = net.days;
            let current = ctx.epoch_timestamp_ms();
            let pass = current <= utils::days_to_ms(days);

            (pass, subtotal)
        },
        _ => (true, subtotal),
    }
}
