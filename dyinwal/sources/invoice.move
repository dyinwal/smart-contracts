/*
/// Module: dyinwal
module dyinwal::dyinwal;
*/

// For Move coding conventions, see
// https://docs.sui.io/concepts/sui-move-concepts/conventions

#[allow(unused_field, unused_const)]

module dyinwal::invoice;

use dyinwal::payment_term::PaymentTerm;
use std::string::{Self, String};
use sui::event::emit;

// === Constants ===

const EInvoiceNotFound: u64 = 0;
const EInvoiceAlreadyPaid: u64 = 1;
const EInvoiceExpired: u64 = 2;
const EInvalidAmount: u64 = 3;
const EInvoiceCancelled: u64 = 4;
const EUnauthorized: u64 = 5;
const EInvalidCurrency: u64 = 6;
const EInsufficientStorage: u64 = 7;
const EInvalidAddress: u64 = 8;

const STATUS_PENDING: u8 = 0;
const STATUS_PAID: u8 = 1;
const STATUS_CANCELLED: u8 = 2;
const STATUS_EXPIRED: u8 = 3;

const STORAGE_TEMPORARY: u8 = 0; // 7-day storage (free)
const STORAGE_PERMANENT: u8 = 1; // Permanent storage (one-time fee)

// === Structs ===

public struct Invoice has key, store {
    id: UID,
    status: u8,
    creator: address,
    recipient: address,
    subtotal: u64, // The total amount for the items (excluding any additional fees)
    total: u64, // The final amount to be paid (including fees like taxes, shipping, etc.)
    paid_amount: u64, // Amount already paid
    invoice_currency: String, // Currency of the invoice
    payment_currencies: vector<String>, // List of accepted payment currencies
    due_date: u64,
    creation_date: u64,
    payment_term: Option<PaymentTerm>, // Payment terms (Net, Discount, Installment, etc.)
    metadata_walrus_id: Option<ID>, // ID for storing metadata on Walrus
}

// === Events ===

public struct InvoiceCreatedEvent has copy, drop {
    invoice_id: ID,
    creation_date: u64,
}

public struct InvoicePaidEvent has copy, drop {
    invoice_id: ID,
    payment_date: u64,
}

public struct InvoiceCancelledEvent has copy, drop {
    invoice_id: ID,
    cancellation_date: u64,
}

public struct StorageUpgradedEvent has copy, drop {
    invoice_id: ID,
    upgrade_date: u64,
}

// === Public Functions ===

fun new(
    creator: address,
    recipient: address,
    subtotal: u64,
    total: u64,
    invoice_currency: String,
    payment_currencies: vector<String>,
    due_date: u64,
    payment_term: Option<PaymentTerm>,
    metadata_walrus_id: Option<ID>,
    ctx: &mut TxContext,
): Invoice {
    Invoice {
        id: object::new(ctx),
        status: STATUS_PENDING,
        creator: creator,
        recipient: recipient,
        subtotal: subtotal,
        total: total,
        paid_amount: 0,
        invoice_currency: invoice_currency,
        payment_currencies: payment_currencies,
        due_date: due_date,
        creation_date: tx_context::epoch(ctx),
        payment_term: payment_term,
        metadata_walrus_id: metadata_walrus_id,
    }
}

public fun create_invoice(
    creator: address,
    recipient: address,
    subtotal: u64,
    total: u64,
    invoice_currency: String,
    payment_currencies: vector<String>,
    due_date: u64,
    payment_term: Option<PaymentTerm>,
    metadata_walrus_id: Option<ID>,
    ctx: &mut TxContext,
) {
    assert!(creator != @0x0, EInvalidAddress);
    assert!(recipient != @0x0, EInvalidAddress);
    assert!(subtotal <= total, EInvalidAmount);
    assert!(due_date > tx_context::epoch(ctx), EInvoiceExpired);
    assert!(vector::length(&payment_currencies) > 0, EInvalidCurrency);
    assert!(string::length(&invoice_currency) > 0, EInvalidCurrency);

    let invoice = new(
        creator,
        recipient,
        subtotal,
        total,
        invoice_currency,
        payment_currencies,
        due_date,
        payment_term,
        metadata_walrus_id,
        ctx,
    );

    emit(InvoiceCreatedEvent {
        invoice_id: object::uid_to_inner(&invoice.id),
        creation_date: invoice.creation_date,
    });

    transfer::public_transfer(invoice, creator);
}

// public fun check_payment_terms(invoice: &Invoice, clock: &Clock): (bool, u64) {
//     let payment_term = invoice.get_invoice_payment_term();
//     let day_duration: u64 = 24 * 60 * 60 * 1000;

//     if (option::is_none(&payment_term)) {
//         return (true, invoice.get_invoice_subtotal())
//     };

//     match (option::borrow(&payment_term)) {
//         PaymentTerm::Net { days } => {
//             let current = clock::timestamp_ms(clock);
//             let total = invoice.get_invoice_subtotal();
//             let pass = current <= *days * day_duration;

//             (pass, total)
//         },
//         PaymentTerm::EndOfMonth { days_after_month_end } => {
//             let current = clock::timestamp_ms(clock);
//             let pass = current <= *days_after_month_end * day_duration;
//             let total = invoice.get_invoice_subtotal();
//             (pass, total)
//         },
//         PaymentTerm::DiscountedNet { discount_days, net_days, discount_percent } => {
//             let current = clock::timestamp_ms(clock);
//             let pass = current <= *net_days * day_duration;
//             let isDiscounted = current <= *discount_days * day_duration;
//             let subtotal = invoice.get_invoice_subtotal();
//             let total = if (isDiscounted) {
//                 subtotal * (100 - *discount_percent) / 100
//             } else {
//                 subtotal
//             };

//             (pass, total)
//         },
//         PaymentTerm::PartialPayment { percent, due_date } => {
//             let current = clock::timestamp_ms(clock);
//             let subtotal = invoice.get_invoice_subtotal();
//             let partial_amount = (subtotal * *percent) / 100;
//             let remaining_amount = subtotal - partial_amount;
//             let total = if (current <= *due_date) {
//                 partial_amount
//             } else {
//                 remaining_amount
//             };

//             (true, total)
//         },
//         PaymentTerm::Installment { percent_per_installment, period } => {
//             let current = clock::timestamp_ms(clock);
//             let subtotal = invoice.subtotal;
//             let paid_amount = invoice.paid_amount;

//             let elapsed_periods = (current - invoice.creation_date) / utils::days_to_ms(*period);
//             let num_installments = vector::length(percent_per_installment);
//             let pass = elapsed_periods < num_installments;

//             let mut payable_total: u64 = 0;
//             let mut i: u64 = 0;

//             while (i <= elapsed_periods && i < num_installments) {
//                 payable_total = payable_total + (subtotal * percent_per_installment[i] / 100);
//                 i = i + 1;
//             };

//             let remaining_amount = if (payable_total > paid_amount) {
//                 payable_total - paid_amount
//             } else {
//                 0
//             };

//             (pass, remaining_amount)
//         },
//         PaymentTerm::CashInAdvance { percent } => {
//             let subtotal = invoice.subtotal;
//             let total = (subtotal * *percent) / 100;

//             (true, total)
//         },
//         PaymentTerm::CashOnDelivery { percent } => {
//             let subtotal = invoice.subtotal;
//             let total = (subtotal * *percent) / 100;

//             (true, total)
//         },
//         PaymentTerm::LateFee { percent, days_after_due } => {
//             let current = clock::timestamp_ms(clock);
//             let subtotal = invoice.subtotal;
//             let total = (subtotal * *percent) / 100;
//             let pass = current > *days_after_due * 24 * 60 * 60 * 1000;

//             (pass, total)
//         },
//     }
// }

// === Accessors Functions ===

public fun get_invoice_id(invoice: &Invoice): ID {
    object::uid_to_inner(&invoice.id)
}

public fun get_invoice_status(invoice: &Invoice): u8 {
    invoice.status
}

public fun get_invoice_creator(invoice: &Invoice): address {
    invoice.creator
}

public fun get_invoice_recipient(invoice: &Invoice): address {
    invoice.recipient
}

public fun get_invoice_subtotal(invoice: &Invoice): u64 {
    invoice.subtotal
}

public fun get_invoice_total(invoice: &Invoice): u64 {
    invoice.total
}

public fun get_invoice_currency(invoice: &Invoice): String {
    invoice.invoice_currency
}

public fun get_invoice_payment_currencies(invoice: &Invoice): vector<String> {
    invoice.payment_currencies
}

public fun get_invoice_due_date(invoice: &Invoice): u64 {
    invoice.due_date
}

public fun get_invoice_creation_date(invoice: &Invoice): u64 {
    invoice.creation_date
}

public fun get_invoice_payment_term(invoice: &Invoice): Option<PaymentTerm> {
    invoice.payment_term
}

public fun get_invoice_metadata_walrus_id(invoice: &Invoice): Option<ID> {
    invoice.metadata_walrus_id
}

#[test_only]
public fun set_invoice_payment_term(invoice: &mut Invoice, payment_term: Option<PaymentTerm>) {
    invoice.payment_term = payment_term;
}
