from datetime import datetime, timezone
from typing import List
from feedgen.feed import FeedGenerator


def _format_duration(seconds: int) -> str:
    """Convert seconds to HH:MM:SS for iTunes duration tag."""
    h = seconds // 3600
    m = (seconds % 3600) // 60
    s = seconds % 60
    return f"{h:02d}:{m:02d}:{s:02d}"


def generate_rss_feed(
    videos: List[dict],
    feed_title: str,
    feed_description: str,
    feed_link: str,
    base_url: str,
    feed_language: str = "en",
) -> str:
    fg = FeedGenerator()
    fg.load_extension("podcast")
    fg.title(feed_title)
    fg.description(feed_description)
    fg.link(href=feed_link, rel="self")
    fg.language(feed_language)
    fg.lastBuildDate(datetime.now(timezone.utc))
    fg.podcast.itunes_category("Technology")

    for video in videos:
        object_name = video["name"]
        size = video.get("size", 0)
        last_modified = video.get("last_modified")
        content_type = video.get("content_type", "video/mp4")
        duration = video.get("duration", 0)

        video_url = f"{base_url.rstrip('/')}/video/{object_name}"
        display_title = object_name.rsplit(".", 1)[0].replace("_", " ")

        fe = fg.add_entry()
        fe.title(display_title)
        fe.link(href=video_url)
        fe.enclosure(url=video_url, length=str(size), type=content_type)

        if duration:
            fe.podcast.itunes_duration(_format_duration(duration))

        if last_modified:
            if isinstance(last_modified, datetime):
                if last_modified.tzinfo is None:
                    last_modified = last_modified.replace(tzinfo=timezone.utc)
                fe.pubDate(last_modified)
            else:
                try:
                    fe.pubDate(datetime.fromisoformat(str(last_modified).replace("Z", "+00:00")))
                except (ValueError, AttributeError):
                    fe.pubDate(datetime.now(timezone.utc))
        else:
            fe.pubDate(datetime.now(timezone.utc))

    return fg.rss_str(pretty=True).decode("utf-8")
