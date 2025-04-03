#[test_only]
#[allow(unused_use, unused_variable, unused_const)]
module dyinwal::dyinwal_tests;

use dyinwal::invoice::{Self, Invoice};
use dyinwal::payment_term::{Self, PaymentTerm, PaymentTermDetails};
use dyinwal::utils;
use std::debug;
use std::string::{Self, String};
use sui::clock::{Self, Clock};
use sui::test_scenario::{Self as ts, Scenario};
use sui::test_utils;

const ENotImplemented: u64 = 0;
const EInvalidPaymentTerm: u64 = 1;
const EInvalidPaymentTermDetails: u64 = 2;
const EInvalidPaymentTermType: u64 = 3;

const EOptionNotSet: u64 = 4;
const EInvalidInvoiceData: u64 = 5;
const EInvalidCreator: u64 = 6;
const EInvalidRecipient: u64 = 7;
const EInvalidSubtotal: u64 = 8;
const EInvalidTotal: u64 = 9;
const EInvalidCurrency: u64 = 10;
const EInvalidDueDate: u64 = 11;
const EInvalidPaymentTermDetailsSet: u64 = 12;

const CREATOR: address = @0x123;
const SENDER: address = @0x234;
const RECIPIENT: address = @0x456;
const DUMMY: address = @0x789;

fun setup_test(): Scenario {
    let scenario = ts::begin(CREATOR);
    scenario
}

#[test]
fun test_create_invoice() {
    let mut scenario = setup_test();

    ts::next_tx(&mut scenario, CREATOR);
    {
        let subtotal = 1000;
        let total = 1200;
        let invoice_currency = string::utf8(b"USD");
        let mut payment_currencies = vector::empty<String>();
        payment_currencies.append(vector::singleton(string::utf8(b"USD")));
        let due_date = ts::ctx(&mut scenario).epoch_timestamp_ms() + 24 * 60 * 60 * 1000;
        let payment_terms: option::Option<PaymentTerm> = option::none();
        let metadata_walrus_id = option::none();

        invoice::create_invoice(
            CREATOR,
            RECIPIENT,
            subtotal,
            total,
            invoice_currency,
            payment_currencies,
            due_date,
            payment_terms,
            metadata_walrus_id,
            ts::ctx(&mut scenario),
        );
    };

    ts::next_tx(&mut scenario, CREATOR);
    {
        let invoice = ts::take_from_sender<Invoice>(&scenario);

        assert!(invoice::get_invoice_creator(&invoice) == CREATOR, 0);
        assert!(invoice::get_invoice_recipient(&invoice) == RECIPIENT, 0);
        assert!(invoice::get_invoice_subtotal(&invoice) == 1000, 0);
        assert!(invoice::get_invoice_total(&invoice) == 1200, 0);
        assert!(invoice::get_invoice_currency(&invoice) == string::utf8(b"USD"), 0);
        assert!(
            invoice::get_invoice_due_date(&invoice) == ts::ctx(&mut scenario).epoch_timestamp_ms() + 24 * 60 * 60 * 1000,
            0,
        );

        ts::return_to_sender(&scenario, invoice);
    };

    ts::end(scenario);
}

#[test]
public fun check_payment_term_net() {
    let mut scenario = ts::begin(SENDER);

    ts::next_tx(&mut scenario, SENDER);
    {
        let subtotal = 1000;
        let total = 1200;
        let invoice_currency = string::utf8(b"USD");
        let mut payment_currencies = vector::empty<String>();
        payment_currencies.append(vector::singleton(string::utf8(b"USD")));
        let due_date = ts::ctx(&mut scenario).epoch_timestamp_ms() + 24 * 60 * 60 * 1000;
        let payment_terms: option::Option<PaymentTerm> = option::none();
        let metadata_walrus_id: option::Option<ID> = option::none();

        invoice::create_invoice(
            SENDER,
            RECIPIENT,
            subtotal,
            total,
            invoice_currency,
            payment_currencies,
            due_date,
            payment_terms,
            metadata_walrus_id,
            ts::ctx(&mut scenario),
        );
    };

    ts::next_tx(&mut scenario, SENDER);
    {
        let mut clock = clock::create_for_testing(scenario.ctx());

        let creation_date = clock.timestamp_ms();
        let subtotal = 1000;
        let due_date = clock.timestamp_ms() + utils::days_to_ms(1);
        let mut payment_term = payment_term::new(1);

        let net_days = 30;
        let term_type = 0;

        let details = payment_term::create_payment_term_details(
            option::some(net_days),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
            option::none(),
        );

        payment_term::set_payment_term(&mut payment_term, term_type, details);
        let payment_term_net = payment_term::get_payment_term_net_details(&payment_term);
        let (days) = payment_term_net;

        assert!(days == net_days, 0);

        // get invoice of creator
        let mut invoice = ts::take_from_sender<Invoice>(&scenario);

        invoice::set_invoice_payment_term(&mut invoice, option::some(payment_term));

        assert!(invoice::get_invoice_payment_term(&invoice) == option::some(payment_term), 0);

        let (is_valid, amount) = payment_term::check_payment_term(
            creation_date,
            due_date,
            subtotal,
            &payment_term,
            ts::ctx(&mut scenario),
        );
        let _due_date = invoice::get_invoice_due_date(&invoice);
        let _creation_date = invoice::get_invoice_creation_date(&invoice);
        let _term_type = payment_term::get_payment_term_type(&payment_term);

        assert!(is_valid == true, 0);
        assert!(amount == subtotal, 0);

        ts::ctx(&mut scenario).increment_epoch_timestamp(utils::days_to_ms(31));

        let current = ts::ctx(&mut scenario).epoch_timestamp_ms();

        let (is_valid, amount) = payment_term::check_payment_term(
            creation_date,
            due_date,
            subtotal,
            &payment_term,
            ts::ctx(&mut scenario),
        );
        assert!(is_valid == false, 0);
        assert!(amount == subtotal, 0);

        clock.share_for_testing();
        ts::return_to_sender(&scenario, invoice);
    };

    ts::end(scenario);
}

#[test, expected_failure(abort_code = ::dyinwal::dyinwal_tests::ENotImplemented)]
fun test_dyinwal_fail() {
    abort ENotImplemented
}
