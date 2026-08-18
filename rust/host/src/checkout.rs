// LIFEADELICS' CHECKOUT/WEBHOOK BOUNDARY — the two mechanics
// adapters/http_server.rb (Ruby, lifeadelics repo) hand-rolls against
// the `stripe` gem: opening a real Stripe Checkout Session (the OUTBOUND
// half of lifeadelics.hecksagon's own "checkout" port,
// Registration.opened_by) and verifying a Stripe webhook's own
// HMAC-SHA256 signature scheme (the INBOUND half, driving Payment's
// PaymentGateway port). Both hand-written here, not IR-driven —
// `rust/project/ports.rb`'s own `emit_port_operation` covers only
// INBOUND port operations (PaymentGateway.Succeeded/Failed, dispatched
// from web.rs's own checkout_route through the already-proven
// port-operation + policy-reaction codegen path); no domain in this
// corpus has an OUTBOUND driving port or a webhook-shaped signature
// scheme to generalize this against yet, so it stays a real, scoped
// specialization (web.rs's own "LIFEADELICS-SPECIFIC GLUE" header has
// the fuller reasoning) rather than a new IR capability invented
// speculatively for a population of one.
//
// PRODUCTION-ONLY, DELIBERATELY — unlike the Ruby app (MockStripeAdapter
// in development, real Stripe in production, picked by which adapter
// lifeadelics.hecksagon binds), this crate only ever runs as a deployed
// AWS Lambda (main.rs's own `lambda_runtime::run`, no standalone-server
// mode the way Sinatra has one) — there is no "development" here to mock
// for, the same reason auth.rs's own Google sign-in has no mock path
// either. `STRIPE_API_KEY` is required, not optional.

use hmac::{Hmac, Mac};
use serde_json::Value;
use sha2::Sha256;

type HmacSha256 = Hmac<Sha256>;

// docs.stripe.com/webhooks#verify-events — 5 minutes, guards against a
// replayed old payload even against a leaked (not yet rotated) secret.
const TOLERANCE_SECONDS: i64 = 300;

pub struct SignatureError(pub String);

impl std::fmt::Display for SignatureError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

// Stripe's own documented scheme (docs.stripe.com/webhooks#verify-
// manually), ported from `Stripe::Webhook.construct_event` (the Ruby
// gem, called directly from adapters/http_server.rb) rather than
// reinvented: header shape "t=<unix ts>,v1=<hex hmac>[,v1=<hex
// hmac>...]" (more than one v1 during a secret-rotation window — ANY
// match is accepted, same as the gem), signed payload is exactly
// "<timestamp>.<raw body>", the RAW BYTES Stripe sent, never a
// re-serialized JSON string (re-encoding would silently disagree on
// whitespace/key order and every signature would fail to verify).
// `now` is a parameter, not read internally, so a test can hold time
// fixed rather than racing the tolerance window.
pub fn verify_signature(payload: &str, header: &str, secret: &str, now: i64) -> Result<(), SignatureError> {
    let mut timestamp: Option<i64> = None;
    let mut signatures: Vec<&str> = Vec::new();
    for part in header.split(',') {
        let Some((key, value)) = part.split_once('=') else { continue };
        match key {
            "t" => timestamp = value.parse().ok(),
            "v1" => signatures.push(value),
            _ => {}
        }
    }
    let Some(timestamp) = timestamp else {
        return Err(SignatureError("Stripe-Signature header has no t= timestamp".to_string()));
    };
    if signatures.is_empty() {
        return Err(SignatureError("Stripe-Signature header has no v1= signature".to_string()));
    }
    if (now - timestamp).abs() > TOLERANCE_SECONDS {
        return Err(SignatureError(format!(
            "timestamp {timestamp} is outside the {TOLERANCE_SECONDS}s tolerance (now: {now})"
        )));
    }

    let signed_payload = format!("{timestamp}.{payload}");
    let mut mac = HmacSha256::new_from_slice(secret.as_bytes())
        .map_err(|e| SignatureError(format!("webhook secret unusable as an HMAC key: {e}")))?;
    mac.update(signed_payload.as_bytes());
    let expected_hex = hex_encode(&mac.finalize().into_bytes());

    if signatures.iter().any(|sig| constant_time_eq(sig.as_bytes(), expected_hex.as_bytes())) {
        Ok(())
    } else {
        Err(SignatureError("signature does not match — wrong secret, or the payload was tampered with in transit".to_string()))
    }
}

fn hex_encode(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

// A timing side-channel on webhook signature comparison is a real,
// documented attack class — exactly why Stripe's own libraries compare
// this way rather than a bare `==`, which short-circuits at the first
// differing byte. Compared as the HEX text the header actually carries
// (hmac's own `finalize()` gives a constant-time-comparable `CtOutput`
// for the RAW bytes, but this needs the same hex round-trip either way
// to line up against `header`'s own v1= values, so it's done by hand).
fn constant_time_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() {
        return false;
    }
    a.iter().zip(b.iter()).fold(0u8, |acc, (x, y)| acc | (x ^ y)) == 0
}

// THE OUTBOUND SIDE — adapters/stripe/stripe.rb's own `create_session`,
// same four fields the Ruby version builds: currency hardcoded "usd"
// (same as Ruby — lifeadelics' own Event::Money value object carries no
// currency at all, see lifeadelics.bluebook's own comment on it), one
// line item, quantity 1, and the SAME metadata key ("registration_id")
// web.rs's own webhook route reads back to recover which Payment/
// Registration this session belongs to.
pub async fn create_checkout_session(
    api_key: &str,
    price_cents: i64,
    product_name: &str,
    registration_id: &str,
    success_url: &str,
    cancel_url: &str,
) -> anyhow::Result<String> {
    let unit_amount = price_cents.to_string();
    let params = [
        ("mode", "payment"),
        ("line_items[0][price_data][currency]", "usd"),
        ("line_items[0][price_data][unit_amount]", unit_amount.as_str()),
        ("line_items[0][price_data][product_data][name]", product_name),
        ("line_items[0][quantity]", "1"),
        ("metadata[registration_id]", registration_id),
        ("success_url", success_url),
        ("cancel_url", cancel_url),
    ];

    let response = reqwest::Client::new()
        .post("https://api.stripe.com/v1/checkout/sessions")
        .bearer_auth(api_key)
        .form(&params)
        .send()
        .await?;

    let status = response.status();
    let body: Value = response.json().await?;
    if !status.is_success() {
        let message = body
            .get("error")
            .and_then(|e| e.get("message"))
            .and_then(|v| v.as_str())
            .unwrap_or("unknown Stripe error");
        anyhow::bail!("Stripe checkout session creation failed ({status}): {message}");
    }

    body.get("url")
        .and_then(|v| v.as_str())
        .map(String::from)
        .ok_or_else(|| anyhow::anyhow!("Stripe's response carried no \"url\": {body}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sign(secret: &str, timestamp: i64, payload: &str) -> String {
        let signed_payload = format!("{timestamp}.{payload}");
        let mut mac = HmacSha256::new_from_slice(secret.as_bytes()).unwrap();
        mac.update(signed_payload.as_bytes());
        hex_encode(&mac.finalize().into_bytes())
    }

    #[test]
    fn a_correctly_signed_payload_verifies() {
        let payload = r#"{"type":"checkout.session.completed"}"#;
        let secret = "whsec_test";
        let now = 1_700_000_000;
        let header = format!("t={now},v1={}", sign(secret, now, payload));

        assert!(verify_signature(payload, &header, secret, now).is_ok());
    }

    #[test]
    fn a_payload_tampered_with_after_signing_is_rejected() {
        let secret = "whsec_test";
        let now = 1_700_000_000;
        let header = format!("t={now},v1={}", sign(secret, now, r#"{"type":"checkout.session.completed"}"#));

        // Same header, DIFFERENT body — exactly what an attacker
        // intercepting and rewriting the request in transit would send.
        let tampered = r#"{"type":"checkout.session.expired"}"#;
        assert!(verify_signature(tampered, &header, secret, now).is_err());
    }

    #[test]
    fn the_wrong_secret_is_rejected() {
        let payload = r#"{"type":"checkout.session.completed"}"#;
        let now = 1_700_000_000;
        let header = format!("t={now},v1={}", sign("whsec_real", now, payload));

        assert!(verify_signature(payload, &header, "whsec_wrong", now).is_err());
    }

    #[test]
    fn a_timestamp_outside_the_tolerance_window_is_rejected_even_with_a_correct_signature() {
        let payload = r#"{"type":"checkout.session.completed"}"#;
        let secret = "whsec_test";
        let signed_at = 1_700_000_000;
        let header = format!("t={signed_at},v1={}", sign(secret, signed_at, payload));

        // A REPLAYED webhook -- the signature is genuinely correct for
        // ITS OWN timestamp, which is exactly why the tolerance check has
        // to be a separate, independent gate rather than folded into
        // "does the signature verify at all."
        let much_later = signed_at + TOLERANCE_SECONDS + 1;
        assert!(verify_signature(payload, &header, secret, much_later).is_err());
    }

    #[test]
    fn a_second_v1_during_a_secret_rotation_window_verifies_against_either() {
        let payload = r#"{"type":"checkout.session.completed"}"#;
        let old_secret = "whsec_old";
        let new_secret = "whsec_new";
        let now = 1_700_000_000;
        let header = format!(
            "t={now},v1={},v1={}",
            sign(old_secret, now, payload),
            sign(new_secret, now, payload)
        );

        assert!(verify_signature(payload, &header, old_secret, now).is_ok());
        assert!(verify_signature(payload, &header, new_secret, now).is_ok());
    }

    #[test]
    fn a_header_with_no_v1_at_all_is_rejected() {
        let now = 1_700_000_000;
        let header = format!("t={now}");
        assert!(verify_signature("{}", &header, "whsec_test", now).is_err());
    }

    #[test]
    fn a_header_with_no_timestamp_at_all_is_rejected() {
        let header = "v1=deadbeef".to_string();
        assert!(verify_signature("{}", &header, "whsec_test", 1_700_000_000).is_err());
    }
}
