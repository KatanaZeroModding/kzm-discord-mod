//! When to call Discord. A running timer must not produce a new activity.

use std::time::Duration;

pub const MIN_UPDATE: Duration = Duration::from_secs(15);

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Plan {
    Skip,
    Wait,
    Send,
}

/// `changed` is false when the snapshot is identical to the last successful send.
/// The first snapshot sends immediately. Later ones wait out Discord's interval.
pub fn plan_send(changed: bool, ever_sent: bool, since_last: Option<Duration>) -> Plan {
    if !changed {
        return Plan::Skip;
    }
    if !ever_sent {
        return Plan::Send;
    }
    match since_last {
        Some(elapsed) if elapsed < MIN_UPDATE => Plan::Wait,
        _ => Plan::Send,
    }
}

pub fn image_rejected(message: &str) -> bool {
    let lower = message.to_ascii_lowercase();
    lower.contains("image") || lower.contains("asset")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ticking_timer_does_not_send() {
        let since = Some(Duration::from_secs(60));
        assert_eq!(plan_send(false, true, since), Plan::Skip);
    }

    #[test]
    fn first_snapshot_sends_immediately() {
        assert_eq!(plan_send(true, false, None), Plan::Send);
    }

    #[test]
    fn change_inside_window_waits() {
        assert_eq!(
            plan_send(true, true, Some(Duration::from_secs(3))),
            Plan::Wait
        );
    }

    #[test]
    fn change_after_window_sends() {
        assert_eq!(
            plan_send(true, true, Some(Duration::from_secs(15))),
            Plan::Send
        );
    }

    #[test]
    fn image_errors_are_recognized() {
        assert!(image_rejected("Unknown asset"));
        assert!(image_rejected("Invalid image key"));
        assert!(!image_rejected("pipe closed"));
    }
}
