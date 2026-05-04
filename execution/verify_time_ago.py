from datetime import datetime, timedelta, timezone

def format_time_ago(dt_str):
    if not dt_str:
        return "—"
    try:
        dt = datetime.fromisoformat(dt_str.replace("Z", "+00:00"))
        now = datetime.now(timezone.utc)
        diff = now - dt
        
        if diff.total_seconds() < 60:
            return "Just now"
        if diff.total_seconds() < 3600:
            minutes = int(diff.total_seconds() // 60)
            return f"{minutes} min{'s' if minutes != 1 else ''} ago"
        if diff.total_seconds() < 86400:
            hours = int(diff.total_seconds() // 3600)
            return f"{hours} hr{'s' if hours != 1 else ''} ago"
        if diff.total_seconds() < 604800:
            days = int(diff.total_seconds() // 86400)
            return f"{days} day{'s' if days != 1 else ''} ago"
        return dt.strftime("%b %d, %Y")
    except Exception as e:
        return "—"

def test_time_ago_logic():
    now = datetime.now(timezone.utc)
    
    test_cases = [
        (now - timedelta(seconds=30), "Just now"),
        (now - timedelta(minutes=5), "5 mins ago"),
        (now - timedelta(hours=3), "3 hrs ago"),
        (now - timedelta(days=2), "2 days ago"),
        (now - timedelta(days=10), (now - timedelta(days=10)).strftime("%b %d, %Y")),
    ]
    
    print("Verifying time_ago logic...")
    for dt, expected in test_cases:
        actual = format_time_ago(dt.isoformat())
        assert actual == expected, f"Expected {expected}, but got {actual}"
        print(f"PASS: {dt.isoformat()} -> {actual}")

if __name__ == "__main__":
    test_time_ago_logic()
